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
        runningApps: [String] = [],
        screenshotData: Data? = nil,
        completion: @escaping (Result<[KeyboardShortcut], GeminiError>) -> Void
    ) {
        print("Calling Gemini REST API: \(model.rawValue)")
        print("API Key length: \(apiKey.count) characters")

        // Clean the API key (remove any whitespace or newlines)
        let cleanedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedApiKey.isEmpty else {
            completion(.failure(.invalidAPIKey))
            return
        }

        let systemPrompt = createSystemPrompt(targetApp: targetApp, runningApps: runningApps)
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

        // Build request body parts (text + optional image)
        var parts: [[String: Any]] = [["text": fullPrompt]]

        // Add screenshot if provided
        if let imageData = screenshotData {
            let base64Image = imageData.base64EncodedString()
            print("📸 Including screenshot (\(imageData.count) bytes)")
            parts.append([
                "inline_data": [
                    "mime_type": "image/png",
                    "data": base64Image
                ]
            ])
        }

        // Build request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": parts
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

    private func createSystemPrompt(targetApp: String?, runningApps: [String]) -> String {
        let appContext = targetApp.map { "The user is currently in the \($0) application." } ?? ""

        // Build running apps context
        let runningAppsContext: String
        if runningApps.isEmpty {
            runningAppsContext = ""
        } else {
            let appsList = runningApps.joined(separator: ", ")
            runningAppsContext = """

            CURRENTLY RUNNING APPLICATIONS (use exact names for SWITCH_APP):
            \(appsList)

            IMPORTANT: Only use SWITCH_APP with applications from this list. If a required app is not running, inform the user in the description that the app needs to be opened first.
            """
        }

        return """
        You are a macOS automation assistant. Convert user requests into keyboard shortcuts and application actions.

        \(appContext)\(runningAppsContext)

        A screenshot of the current screen may be provided to give you visual context.

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

        AVAILABLE ACTION TYPES:

        1. Keyboard Shortcuts (modifier + key):
           - Command: ⌘
           - Shift: ⇧
           - Option: ⌥
           - Control: ⌃
           - Return/Enter: ↵
           Examples: "⌘ C" (copy), "⌘⇧ N" (new folder), "⌃ Tab" (switch tab)

        2. Type Text (for typing strings):
           - Format: "TEXT:your text here"
           - Example: {"name": "Type filename", "keys": "TEXT:report.docx", "description": "Types the filename"}

        3. Switch Application (IMPORTANT for multi-app workflows):
           - Format: "SWITCH_APP:Application Name"
           - Use the EXACT application name from the running apps list
           - Example: {"name": "Switch to Excel", "keys": "SWITCH_APP:Microsoft Excel", "description": "Activate Excel"}

        4. Delay (for waiting):
           - Format: "DELAY:milliseconds"
           - Example: {"name": "Wait", "keys": "DELAY:500", "description": "Wait 500ms for app to respond"}

        MULTI-APPLICATION WORKFLOW RULES:
        - When a task involves multiple applications, ALWAYS include SWITCH_APP actions
        - Add SWITCH_APP before performing actions in a different application
        - The workflow should explicitly switch to each app before sending keystrokes to it
        - Only switch to apps that are in the running apps list

        EXAMPLE MULTI-APP WORKFLOW (Copy from Word to Excel):
        {
          "shortcuts": [
            {"name": "Switch to Word", "keys": "SWITCH_APP:Microsoft Word", "description": "Activate Word"},
            {"name": "Select All", "keys": "⌘ A", "description": "Select all text in Word"},
            {"name": "Copy", "keys": "⌘ C", "description": "Copy selected text"},
            {"name": "Switch to Excel", "keys": "SWITCH_APP:Microsoft Excel", "description": "Activate Excel"},
            {"name": "Paste", "keys": "⌘ V", "description": "Paste into Excel"}
          ]
        }

        GENERAL RULES:
        - Use standard macOS shortcuts when possible
        - Break complex tasks into simple, sequential steps
        - Keep descriptions brief and clear
        - For multi-app tasks, always include explicit app switches
        - Output pure JSON only
        """
    }
}
