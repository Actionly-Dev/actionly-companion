//
//  AppSettings.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import Foundation

enum AIModel: String, CaseIterable, Identifiable {
    case gpt4 = "gpt-4"
    case gpt4Turbo = "gpt-4-turbo"
    case gpt35Turbo = "gpt-3.5-turbo"
    case claude3Opus = "claude-3-opus"
    case claude3Sonnet = "claude-3-sonnet"
    case claude3Haiku = "claude-3-haiku"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gpt4:
            return "GPT-4"
        case .gpt4Turbo:
            return "GPT-4 Turbo"
        case .gpt35Turbo:
            return "GPT-3.5 Turbo"
        case .claude3Opus:
            return "Claude 3 Opus"
        case .claude3Sonnet:
            return "Claude 3 Sonnet"
        case .claude3Haiku:
            return "Claude 3 Haiku"
        }
    }

    var provider: AIProvider {
        switch self {
        case .gpt4, .gpt4Turbo, .gpt35Turbo:
            return .openai
        case .claude3Opus, .claude3Sonnet, .claude3Haiku:
            return .anthropic
        }
    }
}

enum AIProvider: String {
    case openai = "OpenAI"
    case anthropic = "Anthropic"
}

struct AppSettings {
    var selectedModel: AIModel
    var apiToken: String

    static let defaultModel: AIModel = .gpt4Turbo
}
