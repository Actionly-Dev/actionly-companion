//
//  AppSettings.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import Foundation

enum AIModel: String, CaseIterable, Identifiable {
    case gemini25flash = "gemini-2.5-flash"
    
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .gemini25flash:
            return "Gemini 2.5 Flash"
        }
    }
    
    var provider: AIProvider {
        switch self {
        case .gemini25flash:
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
    
    static let defaultModel: AIModel = .gemini25flash
}


