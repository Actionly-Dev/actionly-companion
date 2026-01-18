//
//  ApplicationTracker.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import AppKit

class ApplicationTracker {
    static let shared = ApplicationTracker()
    private init() {}

    private(set) var previousApplication: NSRunningApplication?

    // Call this before showing Actionly's window
    func capturePreviousApplication() {
        // Get the currently active application
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        // Find the frontmost app that isn't Actionly
        if let frontmost = runningApps.first(where: {
            $0.isActive && $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }) {
            previousApplication = frontmost
            print("📱 Captured previous app: \(frontmost.localizedName ?? "Unknown")")
        }
    }

    // Activate the previously captured application
    func activatePreviousApplication(completion: @escaping (Bool) -> Void) {
        guard let app = previousApplication else {
            print("⚠️ No previous application to activate")
            completion(false)
            return
        }

        print("🔄 Activating \(app.localizedName ?? "Unknown")...")

        // Activate the app
        let success = app.activate(options: .activateIgnoringOtherApps)

        if success {
            // Wait a brief moment for the app to fully activate
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("✅ Successfully activated \(app.localizedName ?? "Unknown")")
                completion(true)
            }
        } else {
            print("❌ Failed to activate \(app.localizedName ?? "Unknown")")
            completion(false)
        }
    }

    // Clear the captured application
    func clearPreviousApplication() {
        previousApplication = nil
    }
}
