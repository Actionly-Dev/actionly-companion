//
//  InputView.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import SwiftUI

struct InputView: View {
    @State var viewModel: AppViewModel
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Content Area
            VStack(spacing: 24) {
                // Title
                Text("What would you like to do?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.top, 32)

                // Text Input
                TextField("Describe your action...", text: $viewModel.userPrompt, axis: .vertical)
                    .focused($isTextFieldFocused)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .lineLimit(3...6)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isTextFieldFocused ? Color.accentColor : Color.gray.opacity(0.2),
                                lineWidth: isTextFieldFocused ? 2 : 1
                            )
                    )
                    .padding(.horizontal, 24)
            }

            Spacer()

            // Bottom Action Bar
            HStack {
                Spacer()

                Button {
                    viewModel.submitPrompt()
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isProcessing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        }
                        Text(viewModel.isProcessing ? "Processing..." : "Continue")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.userPrompt.isEmpty || viewModel.isProcessing)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

#Preview {
    InputView(viewModel: AppViewModel())
        .frame(width: 600, height: 300)
}
