//
//  GeminiService-REST.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//
//  Direct REST API implementation - no SDK needed

import Foundation

enum GeminiError: Error, LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case noShortcutsGenerated
    case decodingError(Error)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your settings."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from Gemini API"
        case .noShortcutsGenerated:
            return "No shortcuts were generated. Try rephrasing your request."
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

class GeminiService {
    static let shared = GeminiService()
    private init() {}

    func generateShortcuts(
        prompt: String,
        model: AIModel,
        apiKey: String,
        targetApp: String?,
        completion: @escaping (Result<[KeyboardShortcut], GeminiError>) -> Void
    ) {
        print("🌐 Calling Gemini REST API: \(model.rawValue)")
        print("🔑 API Key length: \(apiKey.count) characters")

        // Clean the API key (remove any whitespace or newlines)
        let cleanedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        print("🔑 Cleaned API Key length: \(cleanedApiKey.count) characters")
        print("🔑 First 10 chars: \(String(cleanedApiKey.prefix(10)))...")

        guard !cleanedApiKey.isEmpty else {
            completion(.failure(.invalidAPIKey))
            return
        }

        let systemPrompt = createSystemPrompt(targetApp: targetApp)
        let fullPrompt = "\(systemPrompt)\n\nUser request: \(prompt)"

        // Build the request URL - using v1 API for better model support
        let urlString = "https://generativelanguage.googleapis.com/v1/models/\(model.rawValue):generateContent?key=\(cleanedApiKey)"

        print("🔗 URL length: \(urlString.count)")
        print("🔗 First 80 chars: \(String(urlString.prefix(80)))...")

        guard let url = URL(string: urlString) else {
            print("❌ Failed to create URL from string!")
            completion(.failure(.invalidResponse))
            return
        }

        print("✅ URL created: \(url.absoluteString.prefix(80))...")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": fullPrompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 2048
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(.decodingError(error)))
            return
        }

        print("📝 Sending request to Gemini...")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error)")
                completion(.failure(.networkError(error)))
                return
            }

            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            // Debug print
            if let responseString = String(data: data, encoding: .utf8) {
                print("📡 Raw response:\n\(responseString)")
            }

            // Check for API error response first
            if let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data),
               let error = errorResponse.error {
                print("❌ API Error: \(error.message)")

                // Provide helpful message for quota errors
                if error.code == 429 {
                    completion(.failure(.apiError("Rate limit exceeded. Try using Gemini 1.5 Flash or wait a few seconds and try again.")))
                } else {
                    completion(.failure(.apiError(error.message)))
                }
                return
            }

            do {
                let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

                guard let text = geminiResponse.candidates?.first?.content?.parts?.first?.text else {
                    completion(.failure(.invalidResponse))
                    return
                }

                print("📡 Gemini response text:\n\(text)")

                let shortcuts = self.parseShortcutsFromText(text)

                if shortcuts.isEmpty {
                    completion(.failure(.noShortcutsGenerated))
                } else {
                    print("✅ Generated \(shortcuts.count) shortcuts")
                    completion(.success(shortcuts))
                }

            } catch {
                print("❌ Decoding error: \(error)")
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }

    private func parseShortcutsFromText(_ text: String) -> [KeyboardShortcut] {
        print("📝 Parsing text of length: \(text.count)")

        // Clean the text - remove markdown code blocks and extra whitespace
        var cleanedText = text
            .replacingOccurrences(of: "```json", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Find JSON object boundaries if there's extra text
        if let jsonStart = cleanedText.firstIndex(of: "{"),
           let jsonEnd = cleanedText.lastIndex(of: "}") {
            cleanedText = String(cleanedText[jsonStart...jsonEnd])
        }

        print("📝 Cleaned text:\n\(cleanedText)")

        guard let jsonData = cleanedText.data(using: .utf8) else {
            print("❌ Failed to convert text to data")
            return []
        }

        do {
            let shortcutsResponse = try JSONDecoder().decode(ShortcutsResponse.self, from: jsonData)
            print("✅ Successfully parsed \(shortcutsResponse.shortcuts.count) shortcuts")
            return shortcutsResponse.shortcuts.map { item in
                KeyboardShortcut(
                    name: item.name,
                    keys: item.keys,
                    description: item.description
                )
            }
        } catch {
            print("❌ Failed to decode shortcuts JSON: \(error)")
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("❌ Failed JSON:\n\(jsonString)")
            }
            return []
        }
    }

    private func createSystemPrompt(targetApp: String?) -> String {
        let appContext = targetApp.map { "The user is currently in the \($0) application." } ?? ""

        return """
        You are a macOS automation assistant. Convert user requests into keyboard shortcuts.

        \(appContext)

        CRITICAL RULES:
        1. Output ONLY valid JSON - no extra text before or after
        2. Do NOT use markdown code blocks (no ```)
        3. Start your response with { and end with }

        Required JSON format:
        {
          "shortcuts": [
            {
              "name": "Brief action name",
              "keys": "⌘ C",
              "description": "What this does"
            }
          ]
        }

        Keyboard symbols:
        - Command: ⌘
        - Shift: ⇧
        - Option: ⌥
        - Control: ⌃
        - Return/Enter: ↵
        - For typing text: prefix keys with "TEXT:" followed by the text to type

        Examples:
        - Copy: {"name": "Copy", "keys": "⌘ C", "description": "Copy selected text"}
        - New tab: {"name": "New Tab", "keys": "⌘ T", "description": "Open new browser tab"}
        - Type hello: {"name": "Type Text", "keys": "TEXT:hello", "description": "Types the word hello"}

        Rules:
        - Use standard macOS shortcuts when possible
        - Break complex tasks into simple steps
        - Keep descriptions brief and clear
        - Output pure JSON only
        """
    }
}
