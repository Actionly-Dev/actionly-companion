//
//  CompletionView.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import SwiftUI

struct CompletionView: View {
    var viewModel: AppViewModel
    let success: Bool
    let message: String
    var onAutoDismiss: (() -> Void)?

    /// Countdown for auto-dismiss (only on success)
    @State private var countdown: Int = 2

    /// Timer for countdown
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Status Icon
            ZStack {
                Circle()
                    .fill(success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(success ? .green : .red)
            }

            // Title
            Text(success ? "Success!" : "Failed")
                .font(.title2)
                .fontWeight(.bold)

            // Message
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Auto-dismiss countdown (only on success)
            if success {
                Text("Closing in \(countdown)...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // Retry button on failure
                Button(action: {
                    viewModel.reset()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Try Again")
                    }
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            }

            Spacer()
        }
        .background(Color.clear)
        .onAppear {
            if success {
                startCountdown()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func startCountdown() {
        countdown = 2
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdown > 1 {
                countdown -= 1
            } else {
                timer?.invalidate()
                timer = nil
                onAutoDismiss?()
            }
        }
    }
}

#Preview {
    CompletionView(
        viewModel: AppViewModel(),
        success: true,
        message: "Successfully executed 5 keyboard shortcuts"
    )
    .frame(width: 600, height: 300)
}
