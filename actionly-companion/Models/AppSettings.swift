//
//  AppSettings.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import Foundation

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
    
struct AppSettings {
    var selectedModel: AIModel
    var apiToken: String

    static let defaultModel: AIModel = .gemini15Flash
}


