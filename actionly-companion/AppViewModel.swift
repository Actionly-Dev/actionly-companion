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

        // TODO: This is where you'll call your model to translate prompt into shortcuts
        // Use: settings.apiToken and settings.selectedModel
        // For now, we'll simulate with dummy data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.generatedShortcuts = self.generateMockShortcuts()
            self.currentState = .review
            self.isProcessing = false
        }
    }

    func executeShortcuts() {
        isProcessing = true

        // TODO: This is where you'll execute the shortcuts
        // For now, we'll simulate execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.currentState = .completion(success: true, message: "Successfully executed \(self.generatedShortcuts.count) shortcuts")
            self.isProcessing = false
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
