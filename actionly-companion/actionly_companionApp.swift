//
//  actionly_companionApp.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import SwiftUI
import AppKit

@main
struct actionly_companionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// Custom panel that can accept keyboard input
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: KeyablePanel?
    var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the floating panel without title bar
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Configure panel behavior
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true

        // Set the SwiftUI content
        let contentView = ContentView(onClose: { [weak self] in
            self?.hideWindow()
        })
        panel.contentView = NSHostingView(rootView: contentView)

        // Center the window
        panel.center()

        self.window = panel

        // Register global hotkey (Cmd+Shift+Space)
        setupGlobalHotkey()

        // Monitor clicks outside the window
        setupClickOutsideMonitor()

        // Show the window initially
        showWindow()
    }

    func setupGlobalHotkey() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Cmd+Shift+Space
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 49 {
                self?.toggleWindow()
            }
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Cmd+Shift+Space
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 49 {
                self?.toggleWindow()
                return nil
            }
            return event
        }
    }

    func setupClickOutsideMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let window = self?.window, window.isVisible else { return }

            let clickLocation = event.locationInWindow
            let windowFrame = window.frame

            if !NSPointInRect(NSEvent.mouseLocation, windowFrame) {
                self?.hideWindow()
            }
        }
    }

    func toggleWindow() {
        if window?.isVisible == true {
            hideWindow()
        } else {
            showWindow()
        }
    }

    func showWindow() {
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)

        // Give SwiftUI time to setup, then focus the text field
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.window?.makeFirstResponder(self.window?.contentView)
        }
    }

    func hideWindow() {
        window?.orderOut(nil)
    }
}
