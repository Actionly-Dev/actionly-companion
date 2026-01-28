//
//  AppViewModel.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import SwiftUI

// MARK: - Models
struct KeyboardShortcut: Identifiable {
    let id = UUID()
    let name: String
    let keys: String
    let description: String
}

enum AppState {
    case input
    case review
    case executing
    case completion(success: Bool, message: String)
}

// MARK: - ViewModel
@Observable
class AppViewModel {
    var currentState: AppState = .input
    var userPrompt: String = ""
    var attachedFiles: [URL] = []
    var generatedShortcuts: [KeyboardShortcut] = []
    var isProcessing: Bool = false

    /// The parsed actions ready for execution
    var parsedActions: [ShortcutAction] = []

    /// The execution session for the current execution
    var executionSession: ExecutionSession?

    private let settings = SettingsManager.shared

    // MARK: - Navigation Actions
    func submitPrompt() {
        guard !userPrompt.isEmpty else { return }

        // Check if API is configured
        guard settings.hasValidSettings else {
            currentState = .completion(success: false, message: "Please configure your API token in Settings (Cmd+,)")
            return
        }

        isProcessing = true

        // Get the target application name for context
        let targetApp = ApplicationTracker.shared.previousApplication?.localizedName

        // Get list of currently running applications
        let runningApps = WindowManager.shared.getRunningApplications()
            .map { $0.localizedName }

        // Capture screenshot asynchronously, then call API
        Task {
            var screenshotData: Data? = nil

            // Try to capture screenshot (may fail if Screen Recording permission not granted)
            do {
                let screenshotHelper = ScreenshotHelper()
                let screenshotURL = try await screenshotHelper.captureAndSaveToCaches()
                screenshotData = try Data(contentsOf: screenshotURL)
                print("Screenshot captured: \(screenshotURL.path)")
            } catch {
                print("Could not capture screenshot: \(error.localizedDescription)")
                // Continue without screenshot - not critical
            }

            // Call Gemini API to generate shortcuts
            GeminiService.shared.generateShortcuts(
                prompt: userPrompt,
                model: settings.selectedModel,
                apiKey: settings.apiToken,
                targetApp: targetApp,
                runningApps: runningApps,
                screenshotData: screenshotData
            ) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    self.isProcessing = false

                    switch result {
                    case .success(let shortcuts):
                        if shortcuts.isEmpty {
                            self.currentState = .completion(success: false, message: "No shortcuts were generated. Try rephrasing your request.")
                        } else {
                            self.generatedShortcuts = shortcuts
                            // Pre-parse actions for the execution view
                            self.parsedActions = shortcuts.compactMap { $0.toAction() }
                            self.currentState = .review
                        }

                    case .failure(let error):
                        self.currentState = .completion(success: false, message: error.localizedDescription)
                    }
                }
            }
        }
    }

    func executeShortcuts() {
        guard !parsedActions.isEmpty else {
            currentState = .completion(success: false, message: "No valid actions to execute")
            return
        }

        // Create a new execution session
        let session = ExecutionSession()
        self.executionSession = session

        // Transition to executing state
        currentState = .executing
        isProcessing = true

        // Execute the shortcuts using the modern async API
        Task { @MainActor in
            let result = await ShortcutExecutor.shared.executeAsync(
                parsedActions,
                session: session,
                settings: settings.executionSettings,
                callbacks: ExecutionCallbacks(
                    onStart: {
                        print("Execution started")
                    },
                    onStepStart: { index, action in
                        print("Starting step \(index + 1): \(action.displayDescription)")
                    },
                    onStepComplete: { index in
                        print("Completed step \(index + 1)")
                    },
                    onCancelled: { index in
                        print("Execution cancelled at step \(index + 1)")
                    },
                    onComplete: { success, message in
                        print("Execution complete: \(success) - \(message)")
                    }
                )
            )

            // Note: We don't automatically transition to completion anymore
            // The ExecutionView handles the "Done" button which calls finishExecution
            self.isProcessing = false
        }
    }

    /// Stop the current execution
    func stopExecution() {
        executionSession?.cancel()
    }

    /// Finish and transition to completion (called from ExecutionView)
    func finishExecution() {
        let success = executionSession?.error == nil
        let message = executionSession?.error ?? "Successfully executed \(parsedActions.count) actions"

        currentState = .completion(success: success, message: message)
        executionSession = nil
    }

    func cancelExecution() {
        executionSession?.cancel()
        executionSession = nil
        currentState = .input
        generatedShortcuts = []
        parsedActions = []
    }

    func reset() {
        userPrompt = ""
        attachedFiles = []
        generatedShortcuts = []
        parsedActions = []
        executionSession = nil
        currentState = .input
        isProcessing = false
    }

    // MARK: - File Management
    func addFile(_ url: URL) {
        attachedFiles.append(url)
    }

    func removeFile(at index: Int) {
        guard index < attachedFiles.count else { return }
        attachedFiles.remove(at: index)
    }
}
