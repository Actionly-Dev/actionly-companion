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
            // Text Input Area
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if viewModel.userPrompt.isEmpty {
                        Text("What would you like to do?")
                            .font(.system(size: 18))
                            .foregroundColor(Color(NSColor.placeholderTextColor))
                            .padding(.top, 12)
                            .padding(.leading, 4)
                    }

                    TextEditor(text: $viewModel.userPrompt)
                        .focused($isTextFieldFocused)
                        .font(.system(size: 18))
                        .frame(minHeight: 100, maxHeight: 140)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 12)
            }

            Divider()
                .padding(.horizontal, 12)

            // Attached Files
            if !viewModel.attachedFiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.attachedFiles.enumerated()), id: \.offset) { index, url in
                            AttachmentChip(fileName: url.lastPathComponent) {
                                viewModel.removeFile(at: index)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Spacer()

            // Bottom Action Bar
            HStack(spacing: 12) {
                // Add File/Screenshot Buttons
                HStack(spacing: 8) {
                    Button(action: {
                        // TODO: Implement screenshot capture
                    }) {
                        Image(systemName: "camera")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .help("Add Screenshot")

                    Button(action: {
                        openFilePicker()
                    }) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .help("Add File")
                }

                Spacer()

                // Submit Button
                Button(action: {
                    viewModel.submitPrompt()
                }) {
                    HStack(spacing: 6) {
                        if viewModel.isProcessing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        }
                        Text(viewModel.isProcessing ? "Processing..." : "Continue")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.userPrompt.isEmpty || viewModel.isProcessing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.5))
            )
        }
        .background(Color.clear)
        .onAppear {
            isTextFieldFocused = true
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK {
            for url in panel.urls {
                viewModel.addFile(url)
            }
        }
    }
}

// MARK: - Attachment Chip Component
struct AttachmentChip: View {
    let fileName: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.fill")
                .font(.caption)
            Text(fileName)
                .font(.caption)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(12)
    }
}

#Preview {
    InputView(viewModel: AppViewModel())
        .frame(width: 600, height: 300)
}
