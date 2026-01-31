//
//  WindowManager.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/28.
//
//  Service for managing application switching and window targeting

import AppKit
import Foundation

// MARK: - App Info
/// Information about a running application
struct AppInfo: Identifiable {
    let id: pid_t
    let bundleIdentifier: String?
    let localizedName: String
    let isActive: Bool

    init(from app: NSRunningApplication) {
        self.id = app.processIdentifier
        self.bundleIdentifier = app.bundleIdentifier
        self.localizedName = app.localizedName ?? "Unknown"
        self.isActive = app.isActive
    }
}

// MARK: - Window Manager Errors
enum WindowManagerError: Error, LocalizedError {
    case applicationNotFound(String)
    case activationFailed(String)
    case activationTimeout(String)

    var errorDescription: String? {
        switch self {
        case .applicationNotFound(let name):
            return "Application '\(name)' not found. Make sure it's running."
        case .activationFailed(let name):
            return "Failed to activate '\(name)'. The app may not accept focus."
        case .activationTimeout(let name):
            return "Timeout waiting for '\(name)' to become active."
        }
    }
}

// MARK: - Window Manager
/// Service for switching between applications and managing window focus
class WindowManager {
    static let shared = WindowManager()
    private init() {}

    /// Default timeout for waiting for app activation
    private let defaultActivationTimeout: TimeInterval = 2.0

    /// Polling interval when waiting for activation
    private let activationPollInterval: UInt64 = 50_000_000 // 50ms in nanoseconds

    // MARK: - Public API

    /// Get all running applications (excluding background-only apps)
    func getRunningApplications() -> [AppInfo] {
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map { AppInfo(from: $0) }
    }

    /// Find a running application by name (case-insensitive partial match)
    func findApplication(named name: String) -> NSRunningApplication? {
        let lowercasedName = name.lowercased()

        // First try exact match
        if let exactMatch = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.lowercased() == lowercasedName
        }) {
            return exactMatch
        }

        // Then try partial match (app name contains search term)
        if let partialMatch = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.lowercased().contains(lowercasedName) == true
        }) {
            return partialMatch
        }

        // Try matching by bundle identifier
        if let bundleMatch = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier?.lowercased().contains(lowercasedName) == true
        }) {
            return bundleMatch
        }

        return nil
    }

    /// Find a running application by bundle identifier
    func findApplication(bundleId: String) -> NSRunningApplication? {
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleId
        }
    }

    /// Activate an application by target (async with waiting)
    func activateApplication(target: ApplicationTarget, timeout: TimeInterval? = nil) async throws {
        let app: NSRunningApplication?

        // Find the app by bundle ID first, then by name
        if let bundleId = target.bundleIdentifier {
            app = findApplication(bundleId: bundleId)
        } else {
            app = findApplication(named: target.name)
        }

        guard let runningApp = app else {
            throw WindowManagerError.applicationNotFound(target.name)
        }

        try await activateApplication(runningApp, timeout: timeout ?? defaultActivationTimeout)
    }

    /// Activate an application and wait for it to become frontmost
    func activateApplication(_ app: NSRunningApplication, timeout: TimeInterval) async throws {
        let appName = app.localizedName ?? "Unknown"
        let startTime = Date()
        print("⏱️ Switching to application: \(appName)")

        // If app is hidden, unhide it first
        if app.isHidden {
            print("⏱️ App is hidden, unhiding...")
            app.unhide()
            // Small delay to let unhide complete
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        let preUnminimizeTime = Date()
        // Check if any windows are minimized and un-minimize them if needed
        // This handles the case where windows are minimized to the Dock
        let hadMinimizedWindows = unminimizeWindows(for: appName)
        let unminimizeTime = Date().timeIntervalSince(preUnminimizeTime)
        print("⏱️ Unminimize check took: \(Int(unminimizeTime * 1000))ms (had minimized: \(hadMinimizedWindows))")

        // Only wait if we actually un-minimized windows
        if hadMinimizedWindows {
            print("⏱️ Waiting 200ms after un-minimizing...")
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }

        // Attempt to activate with all options to handle minimized/background apps
        // .activateIgnoringOtherApps - brings app to front even if another app is active
        let activated = app.activate(options: [.activateIgnoringOtherApps])

        guard activated else {
            throw WindowManagerError.activationFailed(appName)
        }

        let preWaitTime = Date()
        // Wait for the app to become active
        let success = await waitForActivation(app: app, timeout: timeout)
        let waitTime = Date().timeIntervalSince(preWaitTime)
        print("⏱️ Wait for activation took: \(Int(waitTime * 1000))ms")

        if !success {
            throw WindowManagerError.activationTimeout(appName)
        }

        let totalTime = Date().timeIntervalSince(startTime)
        print("✅ Successfully switched to: \(appName) in \(Int(totalTime * 1000))ms")
    }

    /// Un-minimize all windows for an application using AppleScript
    /// This is necessary because NSRunningApplication.activate() doesn't un-minimize windows
    /// Returns true if any windows were un-minimized, false otherwise
    private func unminimizeWindows(for appName: String) -> Bool {
        let script = """
        tell application "System Events"
            try
                tell process "\(appName)"
                    set visible to true
                    set foundMinimized to false
                    repeat with w in windows
                        if value of attribute "AXMinimized" of w is true then
                            set value of attribute "AXMinimized" of w to false
                            set foundMinimized to true
                        end if
                    end repeat
                    return foundMinimized
                end tell
            on error
                return false
            end try
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("⚠️ Failed to un-minimize windows for \(appName): \(error)")
                return false
            } else {
                let hadMinimized = result.booleanValue
                if hadMinimized {
                    print("✅ Un-minimized windows for \(appName)")
                }
                return hadMinimized
            }
        }
        return false
    }

    /// Get the currently frontmost application
    func getFrontmostApplication() -> NSRunningApplication? {
        return NSWorkspace.shared.frontmostApplication
    }

    /// Check if an application is currently frontmost
    func isApplicationFrontmost(_ app: NSRunningApplication) -> Bool {
        return NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
    }

    /// Check if an application with the given name is running
    func isApplicationRunning(named name: String) -> Bool {
        return findApplication(named: name) != nil
    }

    // MARK: - Private Helpers

    /// Wait for an application to become the frontmost app
    private func waitForActivation(app: NSRunningApplication, timeout: TimeInterval) async -> Bool {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if isApplicationFrontmost(app) {
                return true
            }

            // Sleep briefly before checking again
            do {
                try await Task.sleep(nanoseconds: activationPollInterval)
            } catch {
                return false
            }
        }

        return false
    }
}

// MARK: - Convenience Extensions
extension WindowManager {
    /// Quick switch to an app by name
    func switchTo(_ appName: String) async throws {
        try await activateApplication(target: .named(appName))
    }

    /// Get list of common application names for suggestions
    var commonAppNames: [String] {
        return [
            "Microsoft Word",
            "Microsoft Excel",
            "Microsoft PowerPoint",
            "Pages",
            "Numbers",
            "Keynote",
            "Safari",
            "Google Chrome",
            "Firefox",
            "Finder",
            "Notes",
            "TextEdit",
            "Terminal",
            "Xcode",
            "Visual Studio Code",
            "Slack",
            "Discord",
            "Zoom"
        ]
    }
}
