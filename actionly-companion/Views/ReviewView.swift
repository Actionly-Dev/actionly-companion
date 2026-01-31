//
//  ReviewView.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import SwiftUI

struct ReviewView: View {
    var viewModel: AppViewModel

    /// Parse shortcuts into actions to detect multi-app workflows
    private var parsedActions: [ShortcutAction] {
        viewModel.generatedShortcuts.compactMap { $0.toAction() }
    }

    /// Check if this is a multi-app workflow
    private var isMultiAppWorkflow: Bool {
        parsedActions.contains { action in
            if case .switchApplication = action { return true }
            return false
        }
    }

    /// Get unique apps involved in the workflow
    private var involvedApps: [String] {
        var apps: [String] = []
        for action in parsedActions {
            if case .switchApplication(let target) = action {
                if !apps.contains(target.name) {
                    apps.append(target.name)
                }
            }
        }
        return apps
    }

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
                Text("\(viewModel.generatedShortcuts.count) steps")
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

            // Multi-app indicator
            if isMultiAppWorkflow {
                MultiAppBadge(apps: involvedApps)
                    .padding(.horizontal)
            }

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
                Text(isMultiAppWorkflow
                     ? "This workflow will switch between applications"
                     : "These actions will be executed on your system")
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

// MARK: - Multi-App Badge
struct MultiAppBadge: View {
    let apps: [String]

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.blue)

            Text("Multi-App Workflow:")
                .font(.caption)
                .fontWeight(.medium)

            ForEach(apps, id: \.self) { app in
                Text(app)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Shortcut Row Component
struct ShortcutRow: View {
    let number: Int
    let shortcut: KeyboardShortcut

    /// Parse the action to determine its type
    private var parsedAction: ShortcutAction? {
        shortcut.toAction()
    }

    /// Determine the action type for visual styling
    private var actionType: ActionType {
        guard let action = parsedAction else { return .keyPress }

        switch action {
        case .switchApplication:
            return .appSwitch
        case .typeText:
            return .typeText
        case .delay:
            return .delay
        case .keyPress:
            return .keyPress
        }
    }

    enum ActionType {
        case keyPress
        case typeText
        case appSwitch
        case delay

        var color: Color {
            switch self {
            case .keyPress: return .blue
            case .typeText: return .green
            case .appSwitch: return .purple
            case .delay: return .orange
            }
        }

        var icon: String {
            switch self {
            case .keyPress: return "keyboard"
            case .typeText: return "text.cursor"
            case .appSwitch: return "arrow.triangle.2.circlepath"
            case .delay: return "clock"
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Step Number with type-specific color
            ZStack {
                Circle()
                    .fill(actionType.color)
                    .frame(width: 28, height: 28)

                if actionType == .appSwitch {
                    Image(systemName: actionType.icon)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }

            // Shortcut Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(shortcut.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(displayKeys)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(actionType.color.opacity(0.15))
                        .foregroundColor(actionType.color)
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
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(actionType == .appSwitch ? actionType.color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    /// Format the keys for display
    private var displayKeys: String {
        let keys = shortcut.keys

        // Clean up display for different action types
        if keys.uppercased().hasPrefix("SWITCH_APP:") {
            return "Switch App"
        } else if keys.uppercased().hasPrefix("TEXT:") {
            let text = String(keys.dropFirst(5))
            let preview = text.count > 12 ? String(text.prefix(12)) + "..." : text
            return "Type: \(preview)"
        } else if keys.uppercased().hasPrefix("DELAY:") {
            return keys
        } else {
            return keys
        }
    }
}

#Preview {
    let viewModel = AppViewModel()
    viewModel.userPrompt = "Copy text from Word and paste into Excel"
    viewModel.generatedShortcuts = [
        KeyboardShortcut(name: "Switch to Word", keys: "SWITCH_APP:Microsoft Word", description: "Activate Microsoft Word"),
        KeyboardShortcut(name: "Select All", keys: "⌘ A", description: "Select all text"),
        KeyboardShortcut(name: "Copy", keys: "⌘ C", description: "Copy selected text"),
        KeyboardShortcut(name: "Switch to Excel", keys: "SWITCH_APP:Microsoft Excel", description: "Activate Microsoft Excel"),
        KeyboardShortcut(name: "Paste", keys: "⌘ V", description: "Paste clipboard content")
    ]
    viewModel.currentState = .review

    return ReviewView(viewModel: viewModel)
        .frame(width: 600, height: 500)
}
