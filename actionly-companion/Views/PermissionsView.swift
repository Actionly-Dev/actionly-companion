//
//  PermissionsView.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import SwiftUI
import ScreenCaptureKit

struct PermissionsView: View {
    @State private var hasAccessibility = ShortcutExecutor.shared.checkAccessibilityPermissions()
    @State private var hasScreenRecording = false
    @State private var isChecking = false

    var onPermissionsGranted: () -> Void

    var allPermissionsGranted: Bool {
        hasAccessibility && hasScreenRecording
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: allPermissionsGranted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 56))
                    .foregroundColor(allPermissionsGranted ? .green : .orange)

                Text(allPermissionsGranted ? "All Set!" : "Permissions Required")
                    .font(.title)
                    .fontWeight(.bold)

                Text(allPermissionsGranted
                     ? "Actionly has all the permissions it needs."
                     : "Actionly needs these permissions to work properly.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 350)
            }

            Divider()
                .padding(.horizontal, 20)

            // Permission Items
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "keyboard",
                    title: "Accessibility",
                    description: "Control keyboard and mouse to execute shortcuts",
                    granted: hasAccessibility,
                    action: openAccessibilitySettings
                )

                PermissionRow(
                    icon: "camera.viewfinder",
                    title: "Screen Recording",
                    description: "Capture screenshots to provide context to AI",
                    granted: hasScreenRecording,
                    action: openScreenRecordingSettings
                )
            }
            .padding(.horizontal, 20)

            Divider()
                .padding(.horizontal, 20)

            // Actions
            VStack(spacing: 12) {
                Button(action: checkPermissions) {
                    HStack {
                        if isChecking {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Check Again")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isChecking)

                if allPermissionsGranted {
                    Button("Continue") {
                        onPermissionsGranted()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 20)

            if !allPermissionsGranted {
                Text("Grant permissions in System Settings, then check again")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 30)
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        isChecking = true

        // Check accessibility
        hasAccessibility = ShortcutExecutor.shared.checkAccessibilityPermissions()

        // Check screen recording
        Task {
            hasScreenRecording = await checkScreenRecordingPermission()
            isChecking = false
        }
    }

    private func checkScreenRecordingPermission() async -> Bool {
        // Try to get available content - if this succeeds, we have permission
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            return !content.displays.isEmpty
        } catch {
            return false
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40)

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Status / Action
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(granted ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    PermissionsView(onPermissionsGranted: {})
}
