//
//  ShortcutAction.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import Foundation
import Carbon

// Represents an executable shortcut action
enum ShortcutAction {
    case keyPress(key: String, modifiers: [ModifierKey])
    case typeText(String)
    case delay(milliseconds: Int)
}

// Modifier keys for keyboard shortcuts
enum ModifierKey: String {
    case command = "⌘"
    case shift = "⇧"
    case option = "⌥"
    case control = "⌃"

    var cgEventFlag: CGEventFlags {
        switch self {
        case .command:
            return .maskCommand
        case .shift:
            return .maskShift
        case .option:
            return .maskAlternate
        case .control:
            return .maskControl
        }
    }
}

// Helper to parse keyboard shortcuts from strings
extension ShortcutAction {
    static func parse(from keyString: String, description: String = "") -> ShortcutAction? {
        let trimmed = keyString.trimmingCharacters(in: .whitespaces)

        // Check if it's a text input
        if trimmed.lowercased() == "text input" || description.lowercased().contains("type") {
            // Extract text from description if possible
            if let range = description.range(of: "'([^']+)'", options: .regularExpression) {
                let text = String(description[range]).replacingOccurrences(of: "'", with: "")
                return .typeText(text)
            }
            return nil // Will need actual text to type
        }

        // Parse keyboard shortcut
        var modifiers: [ModifierKey] = []
        var keyChar = ""

        // Split by space to separate modifiers from key
        let parts = trimmed.components(separatedBy: " ")

        for part in parts {
            if part.contains("⌘") {
                modifiers.append(.command)
            }
            if part.contains("⇧") {
                modifiers.append(.shift)
            }
            if part.contains("⌥") {
                modifiers.append(.option)
            }
            if part.contains("⌃") {
                modifiers.append(.control)
            }

            // Extract the actual key (remove modifier symbols)
            let cleaned = part.replacingOccurrences(of: "⌘", with: "")
                .replacingOccurrences(of: "⇧", with: "")
                .replacingOccurrences(of: "⌥", with: "")
                .replacingOccurrences(of: "⌃", with: "")

            if !cleaned.isEmpty {
                keyChar = cleaned
            }
        }

        // Handle special keys
        if trimmed == "↵" || trimmed.lowercased() == "return" || trimmed.lowercased() == "enter" {
            keyChar = "\r"
        } else if trimmed.lowercased() == "space" {
            keyChar = " "
        } else if trimmed.lowercased() == "tab" {
            keyChar = "\t"
        } else if trimmed.lowercased() == "escape" || trimmed.lowercased() == "esc" {
            keyChar = "\u{1B}"
        }

        guard !keyChar.isEmpty else { return nil }

        return .keyPress(key: keyChar, modifiers: modifiers)
    }
}

// Convert KeyboardShortcut to ShortcutAction
extension KeyboardShortcut {
    func toAction() -> ShortcutAction? {
        return ShortcutAction.parse(from: self.keys, description: self.description)
    }
}
