//
//  GeminiResponse.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import Foundation

// MARK: - Gemini API Response Models

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]?
    let promptFeedback: PromptFeedback?
}

struct GeminiErrorResponse: Codable {
    let error: GeminiAPIError?
}

struct GeminiAPIError: Codable {
    let code: Int
    let message: String
    let status: String?
}

struct GeminiCandidate: Codable {
    let content: GeminiContent?
    let finishReason: String?
    let safetyRatings: [SafetyRating]?
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]?
    let role: String?
}

struct GeminiPart: Codable {
    let text: String?
}

struct PromptFeedback: Codable {
    let safetyRatings: [SafetyRating]?
}

struct SafetyRating: Codable {
    let category: String?
    let probability: String?
}

// MARK: - Shortcuts Response (What we expect from Gemini)

struct ShortcutsResponse: Codable {
    let shortcuts: [ShortcutItem]
}

struct ShortcutItem: Codable {
    let name: String
    let keys: String
    let description: String
}

// MARK: - Helper Extensions

extension GeminiResponse {
    func extractShortcuts() -> [KeyboardShortcut]? {
        guard let firstCandidate = candidates?.first,
              let content = firstCandidate.content,
              let parts = content.parts,
              let firstPart = parts.first,
              let text = firstPart.text else {
            return nil
        }

        // Try to extract JSON from the text (it might be wrapped in markdown code blocks)
        let cleanedText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanedText.data(using: .utf8) else {
            return nil
        }

        do {
            let shortcutsResponse = try JSONDecoder().decode(ShortcutsResponse.self, from: jsonData)
            return shortcutsResponse.shortcuts.map { item in
                KeyboardShortcut(
                    name: item.name,
                    keys: item.keys,
                    description: item.description
                )
            }
        } catch {
            print("❌ Failed to decode shortcuts JSON: \(error)")
            return nil
        }
    }
}
