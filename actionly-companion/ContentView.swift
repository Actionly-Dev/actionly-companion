//
//  ContentView.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import SwiftUI
import ScreenCaptureKit

struct ContentView: View {
    let viewModel: AppViewModel
    var onClose: () -> Void
    @State private var showPermissions = false
    @State private var permissionsChecked = false

    var body: some View {
        Group {
            if !permissionsChecked || showPermissions {
                // Show permissions screen
                PermissionsView(onPermissionsGranted: {
                    showPermissions = false
                })
                .transition(.opacity)
            } else {
                // Show main content
                mainContent
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showPermissions)
        .frame(width: 600, height: dynamicHeight)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 15)
        .animation(.easeInOut(duration: 0.3), value: dynamicHeight)
        .task {
            await checkPermissionsOnLaunch()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        // Content based on current state
        Group {
            switch viewModel.currentState {
            case .input:
                InputView(viewModel: viewModel)
                    .transition(.opacity)

            case .review:
                ReviewView(viewModel: viewModel)
                    .transition(.opacity)

            case .executing:
                if let session = viewModel.executionSession {
                    ExecutionView(
                        session: session,
                        actions: viewModel.parsedActions,
                        onStop: {
                            viewModel.stopExecution()
                        },
                        onDismiss: {
                            viewModel.finishExecution()
                        }
                    )
                    .transition(.opacity)
                }

            case .completion(let success, let message):
                CompletionView(
                    viewModel: viewModel,
                    success: success,
                    message: message,
                    onAutoDismiss: {
                        // Hide window and reset for next time
                        viewModel.reset()
                        onClose()
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentState)
        .onExitCommand {
            // Handle ESC key
            switch viewModel.currentState {
            case .input:
                if !viewModel.isProcessing {
                    onClose()
                }
            case .executing:
                // Stop execution on ESC
                viewModel.stopExecution()
            case .review, .completion:
                viewModel.cancelExecution()
            }
        }
    }

    // Dynamic height based on current view
    private var dynamicHeight: CGFloat {
        if !permissionsChecked || showPermissions {
            return 550 // Height for permissions view
        }

        switch viewModel.currentState {
        case .input:
            return 300
        case .review:
            return 450
        case .executing:
            return 500
        case .completion:
            return 300
        }
    }

    private func checkPermissionsOnLaunch() async {
        // Check accessibility
        let hasAccessibility = ShortcutExecutor.shared.checkAccessibilityPermissions()

        // Check screen recording
        let hasScreenRecording = await checkScreenRecordingPermission()

        // Update state
        await MainActor.run {
            permissionsChecked = true
            showPermissions = !hasAccessibility || !hasScreenRecording
        }
    }

    private func checkScreenRecordingPermission() async -> Bool {
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
}

// MARK: - AppState Equatable (for animation)
extension AppState: Equatable {
    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.input, .input):
            return true
        case (.review, .review):
            return true
        case (.executing, .executing):
            return true
        case (.completion(let lSuccess, let lMessage), .completion(let rSuccess, let rMessage)):
            return lSuccess == rSuccess && lMessage == rMessage
        default:
            return false
        }
    }
}

#Preview {
    ContentView(viewModel: AppViewModel(), onClose: {})
}
