//
//  ExecutionView.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/28.
//
//  Live execution monitoring view with stop functionality

import SwiftUI

struct ExecutionView: View {
    @ObservedObject var session: ExecutionSession
    let actions: [ShortcutAction]
    let onStop: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerView

            // Progress
            progressView

            // Actions List
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                            ExecutionActionRow(
                                number: index + 1,
                                action: action,
                                state: rowState(for: index)
                            )
                            .id(index)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: session.currentStepIndex) { _, newIndex in
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }

            Spacer()

            // Bottom controls
            bottomControls
        }
        .background(Color.clear)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: headerIcon)
                .font(.title2)
                .foregroundColor(headerColor)

            Text(headerTitle)
                .font(.headline)

            Spacer()

            if !session.isComplete {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var headerIcon: String {
        if session.isComplete {
            return session.error == nil ? "checkmark.circle.fill" : "xmark.circle.fill"
        } else if session.isCancelled {
            return "stop.circle.fill"
        } else {
            return "play.circle.fill"
        }
    }

    private var headerColor: Color {
        if session.isComplete {
            return session.error == nil ? .green : .red
        } else if session.isCancelled {
            return .orange
        } else {
            return .blue
        }
    }

    private var headerTitle: String {
        if session.isComplete {
            return session.error == nil ? "Completed" : "Failed"
        } else if session.isCancelled {
            return "Stopping..."
        } else {
            return "Executing..."
        }
    }

    // MARK: - Progress

    private var progressView: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: progressWidth(in: geometry.size.width))
                        .animation(.easeInOut(duration: 0.3), value: session.currentStepIndex)
                }
            }
            .frame(height: 8)
            .padding(.horizontal)

            // Step counter
            HStack {
                Text("Step \(max(1, session.currentStepIndex + 1)) of \(actions.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let currentAction = currentAction {
                    Text(currentAction.displayDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal)
        }
    }

    private var progressColor: Color {
        if session.error != nil {
            return .red
        } else if session.isCancelled {
            return .orange
        } else {
            return .blue
        }
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard actions.count > 0 else { return 0 }

        let completedSteps = session.isComplete
            ? actions.count
            : max(0, session.currentStepIndex + 1)

        return totalWidth * CGFloat(completedSteps) / CGFloat(actions.count)
    }

    private var currentAction: ShortcutAction? {
        guard session.currentStepIndex >= 0, session.currentStepIndex < actions.count else {
            return nil
        }
        return actions[session.currentStepIndex]
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Error message if any
            if let error = session.error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
                .padding(.horizontal)
            }

            // Keyboard shortcut hint
            if !session.isComplete && !session.isCancelled {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .foregroundColor(.secondary)
                    Text("Press ESC to stop")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Buttons
            HStack(spacing: 12) {
                if session.isComplete {
                    Button(action: onDismiss) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Done")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                } else {
                    Button(action: onStop) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .keyboardShortcut(.escape, modifiers: [])
                    .disabled(session.isCancelled)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Helpers

    private func rowState(for index: Int) -> ExecutionActionRow.State {
        if index < session.currentStepIndex {
            return .completed
        } else if index == session.currentStepIndex {
            if session.isCancelled {
                return .cancelled
            } else if session.error != nil {
                return .failed
            } else {
                return .executing
            }
        } else {
            return .pending
        }
    }
}

// MARK: - Execution Action Row

struct ExecutionActionRow: View {
    enum State {
        case pending
        case executing
        case completed
        case failed
        case cancelled
    }

    let number: Int
    let action: ShortcutAction
    let state: State

    var body: some View {
        HStack(spacing: 12) {
            // State indicator
            stateIndicator

            // Action details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(actionName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(textColor)

                    Spacer()

                    Text(actionKeys)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(6)
                }

                Text(action.displayDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: state == .executing ? 2 : 0)
        )
        .animation(.easeInOut(duration: 0.2), value: state)
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch state {
        case .pending:
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.gray))

        case .executing:
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 24, height: 24)

        case .completed:
            Image(systemName: "checkmark")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.green))

        case .failed:
            Image(systemName: "xmark")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.red))

        case .cancelled:
            Image(systemName: "stop.fill")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.orange))
        }
    }

    private var actionName: String {
        switch action {
        case .keyPress(_, _):
            return "Key Press"
        case .typeText(_):
            return "Type Text"
        case .delay(let ms):
            return "Wait \(ms)ms"
        case .switchApplication(let target):
            return "Switch to \(target.name)"
        }
    }

    private var actionKeys: String {
        switch action {
        case .keyPress(let key, let modifiers):
            let modStr = modifiers.map { $0.rawValue }.joined()
            return "\(modStr)\(key.uppercased())"
        case .typeText(let text):
            let preview = text.count > 15 ? String(text.prefix(15)) + "..." : text
            return "TEXT:\(preview)"
        case .delay(let ms):
            return "DELAY:\(ms)"
        case .switchApplication(let target):
            return "SWITCH APP"
        }
    }

    private var textColor: Color {
        switch state {
        case .pending:
            return .primary.opacity(0.6)
        case .executing, .completed:
            return .primary
        case .failed, .cancelled:
            return .red
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .pending:
            return Color(NSColor.controlBackgroundColor).opacity(0.5)
        case .executing:
            return Color.blue.opacity(0.1)
        case .completed:
            return Color.green.opacity(0.1)
        case .failed:
            return Color.red.opacity(0.1)
        case .cancelled:
            return Color.orange.opacity(0.1)
        }
    }

    private var borderColor: Color {
        switch state {
        case .executing:
            return .blue
        default:
            return .clear
        }
    }
}

// MARK: - Preview

#Preview {
    let session = ExecutionSession()
    session.setCurrentStep(1)

    let actions: [ShortcutAction] = [
        .switchApplication(target: .named("Microsoft Word")),
        .keyPress(key: "c", modifiers: [.command]),
        .switchApplication(target: .named("Microsoft Excel")),
        .keyPress(key: "v", modifiers: [.command]),
        .typeText("Hello World")
    ]

    return ExecutionView(
        session: session,
        actions: actions,
        onStop: {},
        onDismiss: {}
    )
    .frame(width: 400, height: 500)
}
