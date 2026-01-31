//
//  InputView.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import SwiftUI
import AppKit

// MARK: - Chip Attachment Cell

/// Custom NSTextAttachmentCell that renders an inline "chip" for @mentioned apps.
/// Each chip is a single character (U+FFFC) in the text, so arrow keys skip it
/// and backspace deletes the whole chip in one keystroke.
class ChipAttachmentCell: NSTextAttachmentCell {
    let appName: String
    // Pre-compute size at init time so it's available in nonisolated contexts
    private let cachedSize: NSSize
    private static let chipFont = NSFont.systemFont(ofSize: 13, weight: .medium)
    private static let horizontalPadding: CGFloat = 8
    private static let chipHeight: CGFloat = 18
    // Match the surrounding text font for baseline calculation
    private static let surroundingFont = NSFont.systemFont(ofSize: 15)

    init(appName: String) {
        self.appName = appName
        let textWidth = ("@" + appName as NSString).size(withAttributes: [.font: ChipAttachmentCell.chipFont]).width
        self.cachedSize = NSSize(
            width: textWidth + ChipAttachmentCell.horizontalPadding * 2,
            height: ChipAttachmentCell.chipHeight
        )
        super.init()
    }

    required init(coder: NSCoder) {
        self.appName = ""
        self.cachedSize = NSSize(width: 60, height: 18)
        super.init(coder: coder)
    }

    override var cellSize: NSSize {
        return cachedSize
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        drawChip(in: cellFrame)
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?, characterIndex charIndex: Int, layoutManager: NSLayoutManager) {
        drawChip(in: cellFrame)
    }

    private func drawChip(in cellFrame: NSRect) {
        let chipFont = ChipAttachmentCell.chipFont
        let horizontalPadding = ChipAttachmentCell.horizontalPadding

        // Draw rounded background - use full cell frame
        let chipRect = NSRect(
            x: cellFrame.origin.x + 1,
            y: cellFrame.origin.y + 1,
            width: cellFrame.width - 2,
            height: cellFrame.height - 2
        )
        let path = NSBezierPath(roundedRect: chipRect, xRadius: 5, yRadius: 5)

        // Background
        NSColor.systemBlue.withAlphaComponent(0.15).setFill()
        path.fill()

        // Border
        NSColor.systemBlue.withAlphaComponent(0.3).setStroke()
        path.lineWidth = 0.5
        path.stroke()

        // Draw text
        let displayText = "@" + appName
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: chipFont,
            .foregroundColor: NSColor.systemBlue
        ]
        let textSize = (displayText as NSString).size(withAttributes: textAttributes)
        let textRect = NSRect(
            x: chipRect.origin.x + horizontalPadding,
            y: chipRect.origin.y + (chipRect.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        (displayText as NSString).draw(in: textRect, withAttributes: textAttributes)
    }

    nonisolated override func cellFrame(for textContainer: NSTextContainer, proposedLineFragment lineFrag: NSRect, glyphPosition position: NSPoint, characterIndex charIndex: Int) -> NSRect {
        // Center the chip vertically within the line fragment
        let yOffset = (lineFrag.height - cachedSize.height) / 2
        return NSRect(x: 0, y: yOffset, width: cachedSize.width, height: cachedSize.height)
    }
}

// MARK: - Custom attribute key for storing app name in attachments
extension NSAttributedString.Key {
    static let chipAppName = NSAttributedString.Key("chipAppName")
}

// MARK: - InputView

struct InputView: View {
    @Bindable var viewModel: AppViewModel
    @FocusState private var isTextFieldFocused: Bool

    // @mention state
    @State private var showAppSuggestions = false
    @State private var mentionSearchText = ""
    @State private var selectedSuggestionIndex = 0
    @State private var mentionXOffset: CGFloat = 0

    // Running apps for suggestions
    private var runningApps: [AppInfo] {
        WindowManager.shared.getRunningApplications()
    }

    // Filtered apps based on search
    private var filteredApps: [AppInfo] {
        let apps = runningApps
        if mentionSearchText.isEmpty {
            return Array(apps.prefix(4))
        }
        return Array(apps.filter {
            $0.localizedName.lowercased().contains(mentionSearchText.lowercased())
        }.prefix(4))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content Area
            VStack(spacing: 20) {
                // Title
                Text("What would you like to do?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.top, 32)

                // Input area
                VStack(alignment: .leading, spacing: 6) {
                    ZStack(alignment: .topLeading) {
                        ChipTextEditor(
                            text: $viewModel.userPrompt,
                            isFocused: $isTextFieldFocused,
                            runningApps: runningApps,
                            showSuggestions: showAppSuggestions,
                            onMentionChange: { isTyping, searchText, xOffset in
                                mentionSearchText = searchText
                                showAppSuggestions = isTyping
                                if isTyping {
                                    selectedSuggestionIndex = 0
                                    mentionXOffset = xOffset
                                }
                            },
                            onSelectSuggestion: {
                                if !filteredApps.isEmpty && selectedSuggestionIndex < filteredApps.count {
                                    insertAppMention(filteredApps[selectedSuggestionIndex])
                                }
                            },
                            onNavigateSuggestion: { direction in
                                if showAppSuggestions {
                                    if direction > 0 {
                                        selectedSuggestionIndex = min(selectedSuggestionIndex + 1, filteredApps.count - 1)
                                    } else {
                                        selectedSuggestionIndex = max(selectedSuggestionIndex - 1, 0)
                                    }
                                }
                            }
                        )
                        .frame(minHeight: 80, maxHeight: 120)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(NSColor.textBackgroundColor).opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isTextFieldFocused ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        // Dropdown appears above the input, aligned to the @ position
                        if showAppSuggestions && !filteredApps.isEmpty {
                            AppDropdownMenu(
                                apps: filteredApps,
                                searchText: mentionSearchText,
                                selectedIndex: selectedSuggestionIndex,
                                onSelect: { app in
                                    insertAppMention(app)
                                },
                                onHover: { index in
                                    selectedSuggestionIndex = index
                                }
                            )
                            .offset(x: mentionXOffset)
                            .alignmentGuide(.top) { d in d[.bottom] + 4 }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .zIndex(100)
                        }
                    }

                    // Hint text
                    HStack(spacing: 4) {
                        Text("Type @ to mention apps")
                            .font(.caption)
                        Spacer()
                    }
                    .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.horizontal, 24)
                .animation(.easeOut(duration: 0.15), value: showAppSuggestions)
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

    /// Called when user selects an app from the dropdown.
    /// Notifies the ChipTextEditor coordinator to insert an attachment.
    private func insertAppMention(_ app: AppInfo) {
        // Post notification so the coordinator can handle the insertion
        // (it has access to the NSTextView)
        NotificationCenter.default.post(
            name: .insertChipMention,
            object: nil,
            userInfo: ["appName": app.localizedName]
        )

        showAppSuggestions = false
        mentionSearchText = ""
    }
}

// MARK: - Notification for chip insertion
extension Notification.Name {
    static let insertChipMention = Notification.Name("insertChipMention")
}

// MARK: - Chip Text Editor (NSTextView with NSTextAttachment chips)

struct ChipTextEditor: NSViewRepresentable {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let runningApps: [AppInfo]
    let showSuggestions: Bool
    let onMentionChange: (Bool, String, CGFloat) -> Void
    let onSelectSuggestion: () -> Void
    let onNavigateSuggestion: (Int) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            fatalError("NSTextView.scrollableTextView() did not return a valid NSTextView")
        }

        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 15)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        context.coordinator.textView = textView

        // Apply initial text with chips if needed
        context.coordinator.setTextWithChips(text)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Keep coordinator's parent in sync so showSuggestions etc. are current
        context.coordinator.parent = self

        // Only update if the plain text representation has changed externally
        let currentPlain = context.coordinator.extractPlainText(from: textView)
        if currentPlain != text && !context.coordinator.isUpdating {
            context.coordinator.setTextWithChips(text)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChipTextEditor
        weak var textView: NSTextView?
        var isUpdating = false
        private var mentionObserver: NSObjectProtocol?

        init(_ parent: ChipTextEditor) {
            self.parent = parent
            super.init()

            // Listen for chip insertion requests
            mentionObserver = NotificationCenter.default.addObserver(
                forName: .insertChipMention,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self,
                      let appName = notification.userInfo?["appName"] as? String else { return }
                self.insertChipAtMentionPosition(appName: appName)
            }
        }

        deinit {
            if let observer = mentionObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        /// Convert plain text (with @AppName) into attributed string with chip attachments
        func setTextWithChips(_ plainText: String) {
            guard let textView = textView else { return }

            isUpdating = true
            defer { isUpdating = false }

            let attributed = buildAttributedString(from: plainText)
            textView.textStorage?.beginEditing()
            textView.textStorage?.setAttributedString(attributed)
            textView.textStorage?.endEditing()

            // Move cursor to end
            let len = textView.textStorage?.length ?? 0
            textView.setSelectedRange(NSRange(location: len, length: 0))
        }

        /// Build attributed string, replacing confirmed @AppName with chip attachments
        private func buildAttributedString(from plainText: String) -> NSAttributedString {
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: NSColor.labelColor
            ]

            let result = NSMutableAttributedString()

            // Parse text and replace @mentions with chip attachments
            let pattern = "@([A-Za-z][A-Za-z0-9 ]*?)(?=\\s|$|@)"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                return NSAttributedString(string: plainText, attributes: baseAttributes)
            }

            let nsText = plainText as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            let matches = regex.matches(in: plainText, options: [], range: fullRange)

            var lastEnd = 0
            for match in matches {
                let matchRange = match.range
                guard let captureRange = Range(match.range(at: 1), in: plainText) else { continue }
                let appName = String(plainText[captureRange]).trimmingCharacters(in: .whitespaces)

                // Check if it's a valid running app
                let isValidApp = parent.runningApps.contains {
                    $0.localizedName.lowercased() == appName.lowercased()
                }

                if isValidApp {
                    // Add text before this match
                    if matchRange.location > lastEnd {
                        let beforeRange = NSRange(location: lastEnd, length: matchRange.location - lastEnd)
                        let beforeText = nsText.substring(with: beforeRange)
                        result.append(NSAttributedString(string: beforeText, attributes: baseAttributes))
                    }

                    // Create chip attachment
                    let attachment = NSTextAttachment()
                    let cell = ChipAttachmentCell(appName: appName)
                    attachment.attachmentCell = cell
                    let chipString = NSMutableAttributedString(attachment: attachment)
                    // Store the app name so we can reconstruct plain text
                    chipString.addAttribute(.chipAppName, value: appName, range: NSRange(location: 0, length: 1))
                    result.append(chipString)

                    lastEnd = matchRange.location + matchRange.length
                }
            }

            // Add remaining text
            if lastEnd < nsText.length {
                let remaining = nsText.substring(from: lastEnd)
                result.append(NSAttributedString(string: remaining, attributes: baseAttributes))
            } else if matches.isEmpty {
                return NSAttributedString(string: plainText, attributes: baseAttributes)
            }

            return result
        }

        /// Extract plain text representation from the text view,
        /// converting chip attachments back to @AppName
        func extractPlainText(from textView: NSTextView) -> String {
            guard let storage = textView.textStorage else { return textView.string }

            var result = ""
            storage.enumerateAttributes(in: NSRange(location: 0, length: storage.length), options: []) { attrs, range, _ in
                if let appName = attrs[.chipAppName] as? String {
                    result += "@\(appName)"
                } else {
                    result += (storage.string as NSString).substring(with: range)
                }
            }
            return result
        }

        /// Insert a chip at the current @mention position
        func insertChipAtMentionPosition(appName: String) {
            guard let textView = textView, let storage = textView.textStorage else { return }

            isUpdating = true
            defer { isUpdating = false }

            let cursorPos = textView.selectedRange().location
            let text = storage.string

            // Find the last @ before cursor
            let textUpToCursor = String(text.prefix(cursorPos))
            guard let lastAtIndex = textUpToCursor.lastIndex(of: "@") else { return }
            let atPosition = textUpToCursor.distance(from: textUpToCursor.startIndex, to: lastAtIndex)

            // Range to replace: from @ to cursor
            let replaceRange = NSRange(location: atPosition, length: cursorPos - atPosition)

            // Create chip attachment
            let attachment = NSTextAttachment()
            let cell = ChipAttachmentCell(appName: appName)
            attachment.attachmentCell = cell
            let chipString = NSMutableAttributedString(attachment: attachment)
            chipString.addAttribute(.chipAppName, value: appName, range: NSRange(location: 0, length: 1))

            // Add a space after the chip
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: NSColor.labelColor
            ]
            let spaceString = NSAttributedString(string: " ", attributes: baseAttributes)

            let combined = NSMutableAttributedString()
            combined.append(chipString)
            combined.append(spaceString)

            // Replace the @search text with the chip
            storage.beginEditing()
            storage.replaceCharacters(in: replaceRange, with: combined)
            storage.endEditing()

            // Move cursor after the chip + space
            let newCursorPos = atPosition + 2 // 1 for attachment char + 1 for space
            textView.setSelectedRange(NSRange(location: newCursorPos, length: 0))

            // Update the binding
            parent.text = extractPlainText(from: textView)

            // Close suggestions
            parent.onMentionChange(false, "", 0)
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? NSTextView else { return }

            isUpdating = true
            defer { isUpdating = false }

            // Update the plain text binding
            let plainText = extractPlainText(from: textView)
            parent.text = plainText

            // Check for active @mention
            checkForMention(in: textView)
        }

        private func checkForMention(in textView: NSTextView) {
            guard let storage = textView.textStorage else {
                parent.onMentionChange(false, "", 0)
                return
            }

            let cursorPos = textView.selectedRange().location

            guard cursorPos <= storage.length else {
                parent.onMentionChange(false, "", 0)
                return
            }

            // Get the raw string from text storage
            let fullText = storage.string
            let textUpToCursor = String(fullText.prefix(cursorPos))

            // Find last @ in the raw text before cursor
            guard let lastAtIndex = textUpToCursor.lastIndex(of: "@") else {
                parent.onMentionChange(false, "", 0)
                return
            }

            let atPosition = textUpToCursor.distance(from: textUpToCursor.startIndex, to: lastAtIndex)

            // Check if the @ is inside a chip attachment (skip it)
            if atPosition > 0 {
                let attrs = storage.attributes(at: atPosition, effectiveRange: nil)
                if attrs[.attachment] != nil {
                    parent.onMentionChange(false, "", 0)
                    return
                }
            }
            // Also check if @ is inside an attachment character
            let charAtPosition = (fullText as NSString).substring(with: NSRange(location: atPosition, length: 1))
            if charAtPosition == "\u{FFFC}" {
                parent.onMentionChange(false, "", 0)
                return
            }

            let afterAt = String(textUpToCursor[textUpToCursor.index(after: lastAtIndex)...])

            // If there's a space, the mention is done
            if afterAt.contains(" ") {
                parent.onMentionChange(false, "", 0)
                return
            }

            // Calculate X position of the @ character using layout manager
            var xOffset: CGFloat = 0
            if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
                let glyphIndex = layoutManager.glyphIndexForCharacter(at: atPosition)
                let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
                xOffset = glyphRect.origin.x + textView.textContainerInset.width
            }

            // We're actively typing a mention
            parent.onMentionChange(true, afterAt, xOffset)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if parent.showSuggestions {
                    parent.onSelectSuggestion()
                    return true
                }
                return false
            } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                if parent.showSuggestions {
                    parent.onNavigateSuggestion(1)
                    return true
                }
                return false
            } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
                if parent.showSuggestions {
                    parent.onNavigateSuggestion(-1)
                    return true
                }
                return false
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if parent.showSuggestions {
                    parent.onMentionChange(false, "", 0)
                    return true
                }
                return false
            }
            return false
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.isFocused.wrappedValue = true
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.isFocused.wrappedValue = false
        }
    }
}

// MARK: - App Dropdown Menu

struct AppDropdownMenu: View {
    let apps: [AppInfo]
    let searchText: String
    let selectedIndex: Int
    let onSelect: (AppInfo) -> Void
    let onHover: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                AppDropdownRow(
                    app: app,
                    isSelected: index == selectedIndex,
                    onSelect: { onSelect(app) },
                    onHover: { onHover(index) }
                )
            }
        }
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct AppDropdownRow: View {
    let app: AppInfo
    let isSelected: Bool
    let onSelect: () -> Void
    let onHover: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // App icon placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(String(app.localizedName.prefix(1)))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                    )

                // App name
                Text(app.localizedName)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                // Active indicator
                if app.isActive {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                onHover()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    InputView(viewModel: AppViewModel())
        .frame(width: 600, height: 400)
}
