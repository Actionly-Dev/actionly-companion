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

    var selectedModel: AIModel {
        didSet {
            UserDefaults.standard.set(selectedModel.rawValue, forKey: selectedModelKey)
        }
    }

    var apiToken: String {
        get {
            KeychainHelper.shared.getToken(for: apiTokenKey) ?? ""
        }
        set {
            if newValue.isEmpty {
                try? KeychainHelper.shared.deleteToken(for: apiTokenKey)
            } else {
                try? KeychainHelper.shared.saveToken(newValue, for: apiTokenKey)
            }
        }
    }

    private init() {
        // Load selected model from UserDefaults
        if let savedModel = UserDefaults.standard.string(forKey: selectedModelKey),
           let model = AIModel(rawValue: savedModel) {
            self.selectedModel = model
        } else {
            self.selectedModel = AppSettings.defaultModel
        }
    }

    var hasValidSettings: Bool {
        return !apiToken.isEmpty
    }

    func clearSettings() {
        selectedModel = AppSettings.defaultModel
        apiToken = ""
    }
}
