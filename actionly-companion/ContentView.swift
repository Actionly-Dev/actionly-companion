//
//  ContentView.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import SwiftUI

struct ContentView: View {
    var onClose: () -> Void
    @State private var viewModel = AppViewModel()

    var body: some View {
        // Content based on current state
        Group {
            switch viewModel.currentState {
            case .input:
                InputView(viewModel: viewModel)
                    .transition(.opacity)

            case .review:
                ReviewView(viewModel: viewModel)
                    .transition(.opacity)

            case .completion(let success, let message):
                CompletionView(
                    viewModel: viewModel,
                    success: success,
                    message: message
                )
                .transition(.opacity)
            }
        }
        .onAppear{
            let screenshotHelper = ScreenshotHelper()

            Task {
                do {
                    let fileURL = try await screenshotHelper.captureAndSaveToCaches()
                    print("Screenshot saved at:", fileURL.path)
                } catch {
                    print("Failed to capture screenshot:", error)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentState)
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
        .onExitCommand {
            // Handle ESC key
            if viewModel.currentState == .input && !viewModel.isProcessing {
                onClose()
            } else {
                viewModel.cancelExecution()
            }
        }
    }

    // Dynamic height based on current view
    private var dynamicHeight: CGFloat {
        switch viewModel.currentState {
        case .input:
            return 300
        case .review:
            return 450
        case .completion:
            return 300
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
        case (.completion(let lSuccess, let lMessage), .completion(let rSuccess, let rMessage)):
            return lSuccess == rSuccess && lMessage == rMessage
        default:
            return false
        }
    }
}

#Preview {
    ContentView(onClose: {})
}
