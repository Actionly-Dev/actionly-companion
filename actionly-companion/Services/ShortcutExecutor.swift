//
//  ShortcutExecutor.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import AppKit
import Carbon
import Combine

// MARK: - Execution Session
/// Manages the state of an execution session, including cancellation
@MainActor
class ExecutionSession: ObservableObject {
    @Published private(set) var isCancelled = false
    @Published private(set) var currentStepIndex: Int = -1
    @Published private(set) var isComplete = false
    @Published private(set) var error: String?

    /// Request cancellation of the execution
    func cancel() {
        isCancelled = true
    }

    /// Check if execution should continue
    var shouldContinue: Bool {
        !isCancelled && !isComplete
    }

    /// Update the current step being executed
    func setCurrentStep(_ index: Int) {
        currentStepIndex = index
    }

    /// Mark execution as complete
    func markComplete() {
        isComplete = true
    }

    /// Mark execution as failed with an error
    func markFailed(error: String) {
        self.error = error
        isComplete = true
    }

    /// Reset the session for reuse
    func reset() {
        isCancelled = false
        currentStepIndex = -1
        isComplete = false
        error = nil
    }
}

// MARK: - Execution Settings
/// Configuration for execution timing
struct ExecutionSettings {
    /// Delay between actions in milliseconds
    var actionDelayMs: Int = 300

    /// Additional delay after switching applications in milliseconds
    var appSwitchDelayMs: Int = 500

    /// Delay between key down and key up events in microseconds
    var keyEventDelayUs: UInt32 = 10_000

    /// Delay between typed characters in microseconds
    var characterDelayUs: UInt32 = 20_000

    static let `default` = ExecutionSettings()

    /// Slower settings for more reliability
    static let slow = ExecutionSettings(
        actionDelayMs: 500,
        appSwitchDelayMs: 800,
        keyEventDelayUs: 15_000,
        characterDelayUs: 30_000
    )

    /// Faster settings for experienced users
    static let fast = ExecutionSettings(
        actionDelayMs: 150,
        appSwitchDelayMs: 300,
        keyEventDelayUs: 8_000,
        characterDelayUs: 15_000
    )
}

// MARK: - Execution Callbacks
/// Callbacks for monitoring execution progress
struct ExecutionCallbacks {
    /// Called when execution starts
    var onStart: (() -> Void)?

    /// Called before each step executes (step index, action)
    var onStepStart: ((Int, ShortcutAction) -> Void)?

    /// Called after each step completes successfully (step index)
    var onStepComplete: ((Int) -> Void)?

    /// Called when execution is cancelled
    var onCancelled: ((Int) -> Void)?

    /// Called when execution completes (success, message)
    var onComplete: ((Bool, String) -> Void)?

    static let empty = ExecutionCallbacks()
}

// MARK: - Shortcut Executor
class ShortcutExecutor {
    static let shared = ShortcutExecutor()
    private init() {}

    private let windowManager = WindowManager.shared

    // MARK: - Legacy API (backward compatible)

    /// Execute a list of shortcut actions (legacy completion-based API)
    func execute(_ actions: [ShortcutAction], completion: @escaping (Bool, String) -> Void) {
        Task { @MainActor in
            let session = ExecutionSession()
            let result = await executeAsync(
                actions,
                session: session,
                settings: .default,
                callbacks: .empty
            )
            completion(result.success, result.message)
        }
    }

    // MARK: - Modern Async API

    /// Execute actions with full control over session, settings, and callbacks
    @MainActor
    func executeAsync(
        _ actions: [ShortcutAction],
        session: ExecutionSession,
        settings: ExecutionSettings = .default,
        callbacks: ExecutionCallbacks = .empty
    ) async -> (success: Bool, message: String) {
        // Check accessibility permissions first
        guard checkAccessibilityPermissions() else {
            let message = "Accessibility permissions required. Please enable in System Settings > Privacy & Security > Accessibility"
            session.markFailed(error: message)
            return (false, message)
        }

        callbacks.onStart?()

        // Activate the previous application first (for backward compatibility)
        // This is only done if the first action isn't a switchApplication
        if case .switchApplication = actions.first {
            // First action is already a switch, don't activate previous app
        } else {
            let activated = await activatePreviousApplication()
            if !activated {
                let message = "Failed to activate target application"
                session.markFailed(error: message)
                callbacks.onComplete?(false, message)
                return (false, message)
            }
        }

        // Execute actions sequentially
        for (index, action) in actions.enumerated() {
            // Check for cancellation
            if !session.shouldContinue {
                let message = "Execution cancelled at step \(index + 1)"
                callbacks.onCancelled?(index)
                callbacks.onComplete?(false, message)
                return (false, message)
            }

            // Update session and notify
            session.setCurrentStep(index)
            callbacks.onStepStart?(index, action)

            // Execute the action
            let result = await executeAction(action, settings: settings)

            if !result.success {
                let message = result.message ?? "Failed at step \(index + 1)"
                session.markFailed(error: message)
                callbacks.onComplete?(false, message)
                return (false, message)
            }

            callbacks.onStepComplete?(index)

            // Add delay between actions (except for the last one)
            if index < actions.count - 1 {
                // Use longer delay after app switch
                let delayMs: Int
                if case .switchApplication = action {
                    delayMs = settings.appSwitchDelayMs
                } else {
                    delayMs = settings.actionDelayMs
                }

                do {
                    try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                } catch {
                    // Task was cancelled
                    let message = "Execution interrupted"
                    callbacks.onCancelled?(index)
                    return (false, message)
                }
            }
        }

        let message = "Successfully executed \(actions.count) actions"
        session.markComplete()
        callbacks.onComplete?(true, message)
        return (true, message)
    }

    // MARK: - Single Action Execution

    /// Execute a single action
    private func executeAction(_ action: ShortcutAction, settings: ExecutionSettings) async -> (success: Bool, message: String?) {
        switch action {
        case .keyPress(let key, let modifiers):
            sendKeyPress(key: key, modifiers: modifiers, settings: settings)
            return (true, nil)

        case .typeText(let text):
            typeText(text, settings: settings)
            return (true, nil)

        case .delay(let milliseconds):
            do {
                try await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
                return (true, nil)
            } catch {
                return (false, "Delay interrupted")
            }

        case .switchApplication(let target):
            do {
                try await windowManager.activateApplication(target: target)
                return (true, nil)
            } catch {
                return (false, error.localizedDescription)
            }
        }
    }

    // MARK: - Key Press Implementation

    /// Send a key press with modifiers
    private func sendKeyPress(key: String, modifiers: [ModifierKey], settings: ExecutionSettings) {
        guard let keyCode = keyCodeForCharacter(key) else {
            print("Warning: Could not find key code for: \(key)")
            return
        }

        // Build modifier flags
        var flags: CGEventFlags = []
        for modifier in modifiers {
            flags.insert(modifier.cgEventFlag)
        }

        // Create key down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            print("Error: Failed to create key down event")
            return
        }
        keyDownEvent.flags = flags

        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            print("Error: Failed to create key up event")
            return
        }
        keyUpEvent.flags = flags

        // Post events globally (to the currently active app)
        keyDownEvent.post(tap: .cghidEventTap)
        usleep(settings.keyEventDelayUs)
        keyUpEvent.post(tap: .cghidEventTap)

        print("Sent key press: \(key) with modifiers: \(modifiers.map { $0.rawValue }.joined())")
    }

    /// Type text character by character
    private func typeText(_ text: String, settings: ExecutionSettings) {
        for char in text {
            let charString = String(char)
            if let keyCode = keyCodeForCharacter(charString) {
                // Determine if shift is needed
                let needsShift = char.isUppercase || shiftRequiredCharacters.contains(char)

                // Create key down event
                if let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
                    if needsShift {
                        keyDownEvent.flags = .maskShift
                    }
                    keyDownEvent.post(tap: .cghidEventTap)
                }

                usleep(settings.keyEventDelayUs)

                // Create key up event
                if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
                    if needsShift {
                        keyUpEvent.flags = .maskShift
                    }
                    keyUpEvent.post(tap: .cghidEventTap)
                }

                usleep(settings.characterDelayUs)
            }
        }
        print("Typed text: \(text)")
    }

    // MARK: - Permissions

    /// Check if accessibility permissions are granted
    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Application Activation (Legacy Support)

    /// Activate the previously tracked application
    private func activatePreviousApplication() async -> Bool {
        return await withCheckedContinuation { continuation in
            ApplicationTracker.shared.activatePreviousApplication { success in
                continuation.resume(returning: success)
            }
        }
    }

    // MARK: - Key Code Mapping

    /// Characters that require shift key
    private let shiftRequiredCharacters: Set<Character> = [
        "!", "@", "#", "$", "%", "^", "&", "*", "(", ")",
        "_", "+", "{", "}", "|", ":", "\"", "<", ">", "?", "~"
    ]

    /// Map characters to virtual key codes
    private func keyCodeForCharacter(_ char: String) -> CGKeyCode? {
        let lowercased = char.lowercased()

        let keyMap: [String: CGKeyCode] = [
            // Letters
            "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E, "f": 0x03,
            "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26, "k": 0x28, "l": 0x25,
            "m": 0x2E, "n": 0x2D, "o": 0x1F, "p": 0x23, "q": 0x0C, "r": 0x0F,
            "s": 0x01, "t": 0x11, "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07,
            "y": 0x10, "z": 0x06,

            // Numbers
            "0": 0x1D, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
            "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19,

            // Special keys
            " ": 0x31, "\r": 0x24, "\n": 0x24, "\t": 0x30, "\u{1B}": 0x35,

            // Punctuation (unshifted)
            "-": 0x1B, "=": 0x18, "[": 0x21, "]": 0x1E, "\\": 0x2A,
            ";": 0x29, "'": 0x27, ",": 0x2B, ".": 0x2F, "/": 0x2C,
            "`": 0x32,

            // Shifted punctuation (map to base key)
            "!": 0x12, "@": 0x13, "#": 0x14, "$": 0x15, "%": 0x17,
            "^": 0x16, "&": 0x1A, "*": 0x1C, "(": 0x19, ")": 0x1D,
            "_": 0x1B, "+": 0x18, "{": 0x21, "}": 0x1E, "|": 0x2A,
            ":": 0x29, "\"": 0x27, "<": 0x2B, ">": 0x2F, "?": 0x2C,
            "~": 0x32
        ]

        return keyMap[lowercased]
    }
}
