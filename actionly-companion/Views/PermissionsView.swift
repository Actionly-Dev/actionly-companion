//
//  PermissionsView.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import SwiftUI

struct PermissionsView: View {
    @State private var hasPermission = ShortcutExecutor.shared.checkAccessibilityPermissions()

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: hasPermission ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(hasPermission ? .green : .orange)

            Text(hasPermission ? "Accessibility Enabled" : "Accessibility Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text(hasPermission
                 ? "Actionly has the necessary permissions to execute shortcuts."
                 : "Actionly needs Accessibility permissions to control other applications.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 300)

            if !hasPermission {
                Button("Open System Settings") {
                    openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)

                Text("After granting permission, restart Actionly")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button("Check Again") {
                hasPermission = ShortcutExecutor.shared.checkAccessibilityPermissions()
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

#Preview {
    PermissionsView()
}
