//
//  ShortcutAction.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import Foundation
import Carbon

// MARK: - Application Target
/// Represents a target application for an action
struct ApplicationTarget: Equatable {
    let bundleIdentifier: String?
    let name: String

    /// Create from app name (bundle ID will be resolved at runtime)
    static func named(_ name: String) -> ApplicationTarget {
        ApplicationTarget(bundleIdentifier: nil, name: name)
    }

    /// Create from bundle identifier
    static func bundleId(_ id: String, name: String) -> ApplicationTarget {
        ApplicationTarget(bundleIdentifier: id, name: name)
    }
}

// MARK: - Shortcut Action
/// Represents an executable shortcut action
enum ShortcutAction: Equatable {
    case keyPress(key: String, modifiers: [ModifierKey])
    case typeText(String)
    case delay(milliseconds: Int)
    case switchApplication(target: ApplicationTarget)

    /// Human-readable description of the action
    var displayDescription: String {
        switch self {
        case .keyPress(let key, let modifiers):
            let modifierStr = modifiers.map { $0.rawValue }.joined()
            return "\(modifierStr)\(key.uppercased())"
        case .typeText(let text):
            let preview = text.count > 20 ? String(text.prefix(20)) + "..." : text
            return "Type: \"\(preview)\""
        case .delay(let ms):
            return "Wait \(ms)ms"
        case .switchApplication(let target):
            return "Switch to \(target.name)"
        }
    }
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

// MARK: - Parsing
/// Helper to parse keyboard shortcuts from strings
extension ShortcutAction {
    static func parse(from keyString: String, description: String = "") -> ShortcutAction? {
        let trimmed = keyString.trimmingCharacters(in: .whitespaces)

        // Check if it's an app switch command
        if trimmed.uppercased().hasPrefix("SWITCH_APP:") {
            let appName = String(trimmed.dropFirst("SWITCH_APP:".count))
                .trimmingCharacters(in: .whitespaces)
            guard !appName.isEmpty else { return nil }
            return .switchApplication(target: .named(appName))
        }

        // Check if it's a delay command
        if trimmed.uppercased().hasPrefix("DELAY:") {
            let msString = String(trimmed.dropFirst("DELAY:".count))
                .trimmingCharacters(in: .whitespaces)
            if let ms = Int(msString) {
                return .delay(milliseconds: ms)
            }
            return nil
        }

        // Check if it's a text input with TEXT: prefix
        if trimmed.uppercased().hasPrefix("TEXT:") {
            let text = String(trimmed.dropFirst(5)) // Remove "TEXT:" prefix
            guard !text.isEmpty else { return nil }
            return .typeText(text)
        }

        // Legacy support for "Text Input" format (uses description)
        if trimmed.lowercased() == "text input" {
            let textToType = description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !textToType.isEmpty else { return nil }
            return .typeText(textToType)
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
