//
//  AppSettings.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import Foundation

// MARK: - AI Model Configuration

enum AIModel: String, CaseIterable, Identifiable {
    case gemini15Pro = "gemini-1.5-pro-latest"
    case gemini15Flash = "gemini-1.5-flash-latest"
    case gemini25Flash = "gemini-2.5-flash"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini15Pro:
            return "Gemini 1.5 Pro"
        case .gemini15Flash:
            return "Gemini 1.5 Flash"
        case .gemini25Flash:
            return "Gemini 2.5 Flash"
        }
    }

    var provider: AIProvider {
        switch self {
        case .gemini15Pro, .gemini15Flash, .gemini25Flash:
            return .google
        }
    }
}

enum AIProvider: String {
    case google = "Google"
}

// MARK: - Execution Speed Preset

enum ExecutionSpeed: String, CaseIterable, Identifiable {
    case slow = "slow"
    case normal = "normal"
    case fast = "fast"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .slow:
            return "Slow (More Reliable)"
        case .normal:
            return "Normal"
        case .fast:
            return "Fast (Advanced)"
        }
    }

    var description: String {
        switch self {
        case .slow:
            return "500ms between actions, best for complex multi-app workflows"
        case .normal:
            return "300ms between actions, balanced speed and reliability"
        case .fast:
            return "150ms between actions, for experienced users"
        }
    }

    /// Convert to ExecutionSettings
    var executionSettings: ExecutionSettings {
        switch self {
        case .slow:
            return .slow
        case .normal:
            return .default
        case .fast:
            return .fast
        }
    }
}

// MARK: - App Settings

struct AppSettings {
    var selectedModel: AIModel
    var apiToken: String
    var executionSpeed: ExecutionSpeed

    static let defaultModel: AIModel = .gemini15Flash
    static let defaultExecutionSpeed: ExecutionSpeed = .normal
}


