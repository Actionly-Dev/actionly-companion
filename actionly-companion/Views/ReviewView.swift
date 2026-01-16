//
//  ReviewView.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import SwiftUI

struct ReviewView: View {
    var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Review Actions")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.generatedShortcuts.count) shortcuts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // User Prompt Summary
            VStack(alignment: .leading, spacing: 4) {
                Text("Your request:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(viewModel.userPrompt)
                    .font(.subheadline)
                    .lineLimit(2)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
            }
            .padding(.horizontal)

            // Shortcuts List
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.generatedShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                        ShortcutRow(
                            number: index + 1,
                            shortcut: shortcut
                        )
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            // Warning Message
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("These actions will be executed on your system")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            // Action Buttons
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.cancelExecution()
                }) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Cancel")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isProcessing)

                Button(action: {
                    viewModel.executeShortcuts()
                }) {
                    HStack {
                        if viewModel.isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.circle.fill")
                        }
                        Text(viewModel.isProcessing ? "Executing..." : "Execute")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isProcessing)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color.clear)
    }
}

// MARK: - Shortcut Row Component
struct ShortcutRow: View {
    let number: Int
    let shortcut: KeyboardShortcut

    var body: some View {
        HStack(spacing: 12) {
            // Step Number
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))

            // Shortcut Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(shortcut.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(shortcut.keys)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(6)
                }
                Text(shortcut.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    let viewModel = AppViewModel()
    viewModel.userPrompt = "Open Finder and create a new folder"
    viewModel.generatedShortcuts = [
        KeyboardShortcut(name: "Open Finder", keys: "⌘ Space", description: "Opens Spotlight"),
        KeyboardShortcut(name: "Type 'Finder'", keys: "Text", description: "Types into search"),
        KeyboardShortcut(name: "Press Enter", keys: "↵", description: "Confirms selection")
    ]
    viewModel.currentState = .review

    return ReviewView(viewModel: viewModel)
        .frame(width: 600, height: 400)
}
