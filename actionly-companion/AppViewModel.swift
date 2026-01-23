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

        // Capture screenshot asynchronously, then call API
        Task {
            var screenshotData: Data? = nil

            // Try to capture screenshot (may fail if Screen Recording permission not granted)
            do {
                let screenshotHelper = ScreenshotHelper()
                let screenshotURL = try await screenshotHelper.captureAndSaveToCaches()
                screenshotData = try Data(contentsOf: screenshotURL)
                print("📸 Screenshot captured: \(screenshotURL.path)")
            } catch {
                print("⚠️ Could not capture screenshot: \(error.localizedDescription)")
                // Continue without screenshot - not critical
            }

            // Call Gemini API to generate shortcuts
            GeminiService.shared.generateShortcuts(
                prompt: userPrompt,
                model: settings.selectedModel,
                apiKey: settings.apiToken,
                targetApp: targetApp,
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
        isProcessing = true

        // Convert KeyboardShortcuts to ShortcutActions
        let actions = generatedShortcuts.compactMap { $0.toAction() }

        guard !actions.isEmpty else {
            currentState = .completion(success: false, message: "No valid actions to execute")
            isProcessing = false
            return
        }

        // Execute the shortcuts using ShortcutExecutor
        ShortcutExecutor.shared.execute(actions) { [weak self] success, message in
            DispatchQueue.main.async {
                self?.currentState = .completion(success: success, message: message)
                self?.isProcessing = false
            }
        }
    }

    func cancelExecution() {
        currentState = .input
        generatedShortcuts = []
    }

    func reset() {
        userPrompt = ""
        attachedFiles = []
        generatedShortcuts = []
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

    // MARK: - Mock Data (Remove later)
    private func generateMockShortcuts() -> [KeyboardShortcut] {
        return [
            KeyboardShortcut(name: "Open Finder", keys: "⌘ Space", description: "Opens Spotlight to search for Finder"),
            KeyboardShortcut(name: "Type 'Finder'", keys: "Text Input", description: "Types 'Finder' into search"),
            KeyboardShortcut(name: "Press Enter", keys: "↵", description: "Confirms selection and opens Finder"),
            KeyboardShortcut(name: "New Folder", keys: "⌘⇧ N", description: "Creates a new folder"),
            KeyboardShortcut(name: "Type Folder Name", keys: "Text Input", description: "Types the folder name")
        ]
    }
}
