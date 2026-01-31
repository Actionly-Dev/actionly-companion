//
//  SettingsManager.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import Foundation
import SwiftUI

@Observable
class SettingsManager {
    static let shared = SettingsManager()

    private let selectedModelKey = "selectedAIModel"
    private let apiTokenKey = "apiToken"
    private let executionSpeedKey = "executionSpeed"

    var selectedModel: AIModel {
        didSet {
            UserDefaults.standard.set(selectedModel.rawValue, forKey: selectedModelKey)
        }
    }

    var executionSpeed: ExecutionSpeed {
        didSet {
            UserDefaults.standard.set(executionSpeed.rawValue, forKey: executionSpeedKey)
        }
    }

    var apiToken: String {
        get {
            let token = KeychainHelper.shared.getToken(for: apiTokenKey) ?? ""
            print("Retrieved API token from keychain (length: \(token.count))")
            return token
        }
        set {
            print("Saving API token to keychain (length: \(newValue.count))")
            if newValue.isEmpty {
                try? KeychainHelper.shared.deleteToken(for: apiTokenKey)
            } else {
                try? KeychainHelper.shared.saveToken(newValue, for: apiTokenKey)
            }
        }
    }

    /// Get the current execution settings based on speed preset
    var executionSettings: ExecutionSettings {
        return executionSpeed.executionSettings
    }

    private init() {
        // Load selected model from UserDefaults
        if let savedModel = UserDefaults.standard.string(forKey: selectedModelKey),
           let model = AIModel(rawValue: savedModel) {
            self.selectedModel = model
        } else {
            self.selectedModel = AppSettings.defaultModel
        }

        // Load execution speed from UserDefaults
        if let savedSpeed = UserDefaults.standard.string(forKey: executionSpeedKey),
           let speed = ExecutionSpeed(rawValue: savedSpeed) {
            self.executionSpeed = speed
        } else {
            self.executionSpeed = AppSettings.defaultExecutionSpeed
        }
    }

    var hasValidSettings: Bool {
        return !apiToken.isEmpty
    }

    func clearSettings() {
        selectedModel = AppSettings.defaultModel
        executionSpeed = AppSettings.defaultExecutionSpeed
        apiToken = ""
    }
}
