//
//  ShortcutExecutor.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import AppKit
import Carbon

class ShortcutExecutor {
    static let shared = ShortcutExecutor()
    private init() {}

    // Execute a list of shortcut actions
    func execute(_ actions: [ShortcutAction], completion: @escaping (Bool, String) -> Void) {
        // Check accessibility permissions first
        guard checkAccessibilityPermissions() else {
            completion(false, "Accessibility permissions required. Please enable in System Settings > Privacy & Security > Accessibility")
            return
        }

        // Activate the previous application first
        ApplicationTracker.shared.activatePreviousApplication { success in
            guard success else {
                completion(false, "Failed to activate target application")
                return
            }

            // Execute actions sequentially
            self.executeActionsSequentially(actions, index: 0) { success, message in
                completion(success, message)
            }
        }
    }

    // Execute actions one by one with proper timing
    private func executeActionsSequentially(_ actions: [ShortcutAction], index: Int, completion: @escaping (Bool, String) -> Void) {
        guard index < actions.count else {
            completion(true, "Successfully executed \(actions.count) actions")
            return
        }

        let action = actions[index]
        executeAction(action) { success in
            if !success {
                completion(false, "Failed to execute action at step \(index + 1)")
                return
            }

            // Add a small delay between actions for reliability
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.executeActionsSequentially(actions, index: index + 1, completion: completion)
            }
        }
    }

    // Execute a single action
    private func executeAction(_ action: ShortcutAction, completion: @escaping (Bool) -> Void) {
        switch action {
        case .keyPress(let key, let modifiers):
            sendKeyPress(key: key, modifiers: modifiers)
            completion(true)

        case .typeText(let text):
            typeText(text)
            completion(true)

        case .delay(let milliseconds):
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(milliseconds)) {
                completion(true)
            }
        }
    }

    // Send a key press with modifiers
    private func sendKeyPress(key: String, modifiers: [ModifierKey]) {
        guard let keyCode = keyCodeForCharacter(key) else {
            print("⚠️ Could not find key code for: \(key)")
            return
        }

        // Build modifier flags
        var flags: CGEventFlags = []
        for modifier in modifiers {
            flags.insert(modifier.cgEventFlag)
        }

        // Create key down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            print("❌ Failed to create key down event")
            return
        }
        keyDownEvent.flags = flags

        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            print("❌ Failed to create key up event")
            return
        }
        keyUpEvent.flags = flags

        // Post events globally (to the currently active app)
        keyDownEvent.post(tap: .cghidEventTap)
        usleep(10000) // 10ms delay between down and up
        keyUpEvent.post(tap: .cghidEventTap)

        print("⌨️ Sent key press: \(key) with modifiers: \(modifiers.map { $0.rawValue }.joined())")
    }

    // Type text character by character
    private func typeText(_ text: String) {
        for char in text {
            let charString = String(char)
            if let keyCode = keyCodeForCharacter(charString) {
                // Create key down event
                if let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
                    keyDownEvent.post(tap: .cghidEventTap)
                }

                usleep(10000) // 10ms delay

                // Create key up event
                if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
                    keyUpEvent.post(tap: .cghidEventTap)
                }

                usleep(20000) // 20ms between characters
            }
        }
        print("📝 Typed text: \(text)")
    }

    // Check if accessibility permissions are granted
    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // Map characters to virtual key codes
    private func keyCodeForCharacter(_ char: String) -> CGKeyCode? {
        let lowercased = char.lowercased()

        let keyMap: [String: CGKeyCode] = [
            "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E, "f": 0x03,
            "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26, "k": 0x28, "l": 0x25,
            "m": 0x2E, "n": 0x2D, "o": 0x1F, "p": 0x23, "q": 0x0C, "r": 0x0F,
            "s": 0x01, "t": 0x11, "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07,
            "y": 0x10, "z": 0x06,

            "0": 0x1D, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
            "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19,

            " ": 0x31, "\r": 0x24, "\n": 0x24, "\t": 0x30, "\u{1B}": 0x35,
            "-": 0x1B, "=": 0x18, "[": 0x21, "]": 0x1E, "\\": 0x2A,
            ";": 0x29, "'": 0x27, ",": 0x2B, ".": 0x2F, "/": 0x2C,
            "`": 0x32
        ]

        return keyMap[lowercased]
    }
}
