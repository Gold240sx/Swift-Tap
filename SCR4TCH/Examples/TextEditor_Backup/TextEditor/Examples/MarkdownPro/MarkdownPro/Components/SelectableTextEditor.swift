import SwiftUI

#if os(macOS)
import AppKit

/// A text editor that exposes selection range for formatting operations
struct SelectableTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange

    let font: NSFont
    let textColor: NSColor
    let backgroundColor: NSColor
    let onTextChange: ((String) -> Void)?

    init(
        text: Binding<String>,
        selectedRange: Binding<NSRange>,
        font: NSFont = .monospacedSystemFont(ofSize: 14, weight: .regular),
        textColor: NSColor = .textColor,
        backgroundColor: NSColor = .textBackgroundColor,
        onTextChange: ((String) -> Void)? = nil
    ) {
        self._text = text
        self._selectedRange = selectedRange
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.onTextChange = onTextChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isEditable = true
        textView.isSelectable = true

        // Set up text container
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true

        // Add extra bottom padding so users can click below content to position cursor
        textView.textContainerInset = NSSize(width: 8, height: 8)

        // Initial content
        textView.string = text

        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Only update text if it changed externally
        if textView.string != text && !context.coordinator.isUpdating {
            let currentSelection = textView.selectedRange()
            textView.string = text

            // Restore selection if valid
            let maxLocation = (text as NSString).length
            if currentSelection.location <= maxLocation {
                let adjustedLength = min(currentSelection.length, maxLocation - currentSelection.location)
                textView.setSelectedRange(NSRange(location: currentSelection.location, length: adjustedLength))
            }
        }

        // Update styling
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SelectableTextEditor
        var textView: NSTextView?
        var isUpdating = false

        init(_ parent: SelectableTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUpdating = true
            parent.text = textView.string
            parent.onTextChange?(textView.string)
            isUpdating = false
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newRange = textView.selectedRange()
            if self.parent.selectedRange != newRange {
                self.parent.selectedRange = newRange
            }
        }

        // Intercept commands like Enter key
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                return handleNewline(in: textView)
            }
            return false
        }

        private func handleNewline(in textView: NSTextView) -> Bool {
            let text = textView.string
            let nsString = text as NSString
            let cursorPosition = textView.selectedRange().location

            // Find the current line
            let lineRange = nsString.lineRange(for: NSRange(location: cursorPosition, length: 0))
            let currentLine = nsString.substring(with: lineRange)

            // Check for list patterns and handle continuation
            if let continuation = ListContinuation.getContinuation(for: currentLine) {
                // Check if the line is empty (just the marker)
                let lineContent = currentLine.trimmingCharacters(in: .newlines)
                if lineContent == continuation.currentMarker.trimmingCharacters(in: .whitespaces) ||
                   lineContent.trimmingCharacters(in: .whitespaces) == continuation.currentMarker.trimmingCharacters(in: .whitespaces) {
                    // Empty list item - remove the marker and end the list
                    isUpdating = true

                    let newText = nsString.replacingCharacters(in: lineRange, with: "\n")
                    textView.string = newText
                    textView.setSelectedRange(NSRange(location: lineRange.location + 1, length: 0))

                    parent.text = newText
                    parent.selectedRange = NSRange(location: lineRange.location + 1, length: 0)
                    parent.onTextChange?(newText)

                    isUpdating = false
                    return true
                }

                // Insert newline with the next list marker
                isUpdating = true

                let insertion = "\n" + continuation.nextMarker
                let before = nsString.substring(to: cursorPosition)
                let after = nsString.substring(from: cursorPosition)
                let newText = before + insertion + after
                let newCursorPosition = cursorPosition + insertion.count

                textView.string = newText
                textView.setSelectedRange(NSRange(location: newCursorPosition, length: 0))

                parent.text = newText
                parent.selectedRange = NSRange(location: newCursorPosition, length: 0)
                parent.onTextChange?(newText)

                isUpdating = false
                return true
            }

            return false // Let default behavior handle it
        }
    }
}

#else
import UIKit

/// A text editor that exposes selection range for formatting operations
struct SelectableTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange

    let font: UIFont
    let textColor: UIColor
    let backgroundColor: UIColor
    let onTextChange: ((String) -> Void)?

    init(
        text: Binding<String>,
        selectedRange: Binding<NSRange>,
        font: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular),
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground,
        onTextChange: ((String) -> Void)? = nil
    ) {
        self._text = text
        self._selectedRange = selectedRange
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.onTextChange = onTextChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
        textView.isEditable = true
        textView.isSelectable = true
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .sentences
        textView.text = text

        context.coordinator.textView = textView

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text && !context.coordinator.isUpdating {
            textView.text = text
        }

        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = backgroundColor
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableTextEditor
        var textView: UITextView?
        var isUpdating = false

        init(_ parent: SelectableTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            isUpdating = true
            parent.text = textView.text
            parent.onTextChange?(textView.text)
            isUpdating = false
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if let range = textView.selectedTextRange {
                let location = textView.offset(from: textView.beginningOfDocument, to: range.start)
                let length = textView.offset(from: range.start, to: range.end)
                DispatchQueue.main.async {
                    self.parent.selectedRange = NSRange(location: location, length: length)
                }
            }
        }

        // Handle text changes to detect Enter key for list continuation
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Check if user pressed Enter
            if text == "\n" {
                let currentText = textView.text ?? ""
                let nsString = currentText as NSString
                let cursorPosition = range.location

                // Find the current line
                let lineRange = nsString.lineRange(for: NSRange(location: cursorPosition, length: 0))
                let currentLine = nsString.substring(with: lineRange)

                // Check for list patterns and handle continuation
                if let continuation = ListContinuation.getContinuation(for: currentLine) {
                    let lineContent = currentLine.trimmingCharacters(in: .newlines)
                    if lineContent == continuation.currentMarker.trimmingCharacters(in: .whitespaces) ||
                       lineContent.trimmingCharacters(in: .whitespaces) == continuation.currentMarker.trimmingCharacters(in: .whitespaces) {
                        // Empty list item - remove the marker and end the list
                        isUpdating = true

                        let newText = nsString.replacingCharacters(in: lineRange, with: "\n")
                        textView.text = newText

                        let newPosition = textView.position(from: textView.beginningOfDocument, offset: lineRange.location + 1)
                        if let newPosition = newPosition {
                            textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
                        }

                        parent.text = newText
                        parent.selectedRange = NSRange(location: lineRange.location + 1, length: 0)
                        parent.onTextChange?(newText)

                        isUpdating = false
                        return false
                    }

                    // Insert newline with the next list marker
                    isUpdating = true

                    let insertion = "\n" + continuation.nextMarker
                    let before = nsString.substring(to: cursorPosition)
                    let after = nsString.substring(from: cursorPosition)
                    let newText = before + insertion + after
                    let newCursorPosition = cursorPosition + insertion.count

                    textView.text = newText

                    let newPosition = textView.position(from: textView.beginningOfDocument, offset: newCursorPosition)
                    if let newPosition = newPosition {
                        textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
                    }

                    parent.text = newText
                    parent.selectedRange = NSRange(location: newCursorPosition, length: 0)
                    parent.onTextChange?(newText)

                    isUpdating = false
                    return false
                }
            }

            return true // Allow default behavior
        }
    }
}
#endif

// MARK: - Text Formatting Helper

struct TextFormatter {
    /// Wraps selected text with prefix/suffix, or inserts at cursor if no selection
    static func wrapSelection(
        in text: inout String,
        selectedRange: NSRange,
        prefix: String,
        suffix: String
    ) -> NSRange {
        let nsString = text as NSString

        // Validate range
        guard selectedRange.location != NSNotFound,
              selectedRange.location + selectedRange.length <= nsString.length else {
            // Invalid range - append at end
            text += prefix + suffix
            return NSRange(location: text.count - suffix.count, length: 0)
        }

        if selectedRange.length == 0 {
            // No selection - insert prefix+suffix at cursor position
            let insertPosition = selectedRange.location
            let before = nsString.substring(to: insertPosition)
            let after = nsString.substring(from: insertPosition)
            text = before + prefix + suffix + after
            // Place cursor between prefix and suffix
            return NSRange(location: insertPosition + prefix.count, length: 0)
        } else {
            // Has selection - wrap the selected text
            let selectedText = nsString.substring(with: selectedRange)
            let before = nsString.substring(to: selectedRange.location)
            let after = nsString.substring(from: selectedRange.location + selectedRange.length)
            text = before + prefix + selectedText + suffix + after
            // Select the wrapped text (including markers)
            return NSRange(location: selectedRange.location, length: prefix.count + selectedRange.length + suffix.count)
        }
    }

    /// Inserts text at the start of the current line
    static func insertAtLineStart(
        in text: inout String,
        selectedRange: NSRange,
        insertion: String
    ) -> NSRange {
        let nsString = text as NSString

        guard selectedRange.location != NSNotFound,
              selectedRange.location <= nsString.length else {
            text += "\n" + insertion
            return NSRange(location: text.count, length: 0)
        }

        // Find the start of the current line
        var lineStart = selectedRange.location
        while lineStart > 0 {
            let char = nsString.substring(with: NSRange(location: lineStart - 1, length: 1))
            if char == "\n" {
                break
            }
            lineStart -= 1
        }

        // Insert at line start
        let before = nsString.substring(to: lineStart)
        let after = nsString.substring(from: lineStart)
        text = before + insertion + after

        // Move cursor after insertion
        return NSRange(location: selectedRange.location + insertion.count, length: selectedRange.length)
    }

    /// Toggles a wrap format (removes if already present, adds if not)
    static func toggleWrap(
        in text: inout String,
        selectedRange: NSRange,
        prefix: String,
        suffix: String
    ) -> NSRange {
        let nsString = text as NSString

        guard selectedRange.location != NSNotFound,
              selectedRange.length > 0,
              selectedRange.location + selectedRange.length <= nsString.length else {
            return wrapSelection(in: &text, selectedRange: selectedRange, prefix: prefix, suffix: suffix)
        }

        let selectedText = nsString.substring(with: selectedRange)

        // Check if already wrapped
        if selectedText.hasPrefix(prefix) && selectedText.hasSuffix(suffix) &&
           selectedText.count >= prefix.count + suffix.count {
            // Remove the wrapping
            let unwrapped = String(selectedText.dropFirst(prefix.count).dropLast(suffix.count))
            let before = nsString.substring(to: selectedRange.location)
            let after = nsString.substring(from: selectedRange.location + selectedRange.length)
            text = before + unwrapped + after
            return NSRange(location: selectedRange.location, length: unwrapped.count)
        }

        // Check if the surrounding text has the markers (selection is inside formatted text)
        let expandedStart = max(0, selectedRange.location - prefix.count)
        let expandedEnd = min(nsString.length, selectedRange.location + selectedRange.length + suffix.count)

        if expandedStart + prefix.count <= selectedRange.location &&
           selectedRange.location + selectedRange.length + suffix.count <= expandedEnd {
            let beforeCheck = nsString.substring(with: NSRange(location: expandedStart, length: prefix.count))
            let afterCheck = nsString.substring(with: NSRange(location: selectedRange.location + selectedRange.length, length: suffix.count))

            if beforeCheck == prefix && afterCheck == suffix {
                // Remove the outer markers
                let before = nsString.substring(to: expandedStart)
                let middle = nsString.substring(with: selectedRange)
                let after = nsString.substring(from: expandedEnd)
                text = before + middle + after
                return NSRange(location: expandedStart, length: selectedRange.length)
            }
        }

        // Not wrapped - add wrapping
        return wrapSelection(in: &text, selectedRange: selectedRange, prefix: prefix, suffix: suffix)
    }
}

// MARK: - List Continuation Helper

struct ListContinuation {
    let currentMarker: String
    let nextMarker: String

    /// Detects list patterns and returns continuation info
    static func getContinuation(for line: String) -> ListContinuation? {
        let trimmedLine = line.trimmingCharacters(in: .newlines)

        // Detect leading whitespace for indentation
        let leadingWhitespace = String(trimmedLine.prefix(while: { $0 == " " || $0 == "\t" }))
        let contentAfterIndent = String(trimmedLine.dropFirst(leadingWhitespace.count))

        // Checkbox list: - [ ] or - [x] or - [X] or * [ ] etc.
        let checkboxPattern = #"^([-*+])\s+\[([ xX])\]\s+"#
        if let regex = try? NSRegularExpression(pattern: checkboxPattern),
           let match = regex.firstMatch(in: contentAfterIndent, range: NSRange(contentAfterIndent.startIndex..., in: contentAfterIndent)),
           let bulletRange = Range(match.range(at: 1), in: contentAfterIndent) {
            let bullet = String(contentAfterIndent[bulletRange])
            let marker = leadingWhitespace + bullet + " [ ] "
            return ListContinuation(currentMarker: marker, nextMarker: marker)
        }

        // Numbered list: 1. or 2. etc.
        let numberedPattern = #"^(\d+)\.\s+"#
        if let regex = try? NSRegularExpression(pattern: numberedPattern),
           let match = regex.firstMatch(in: contentAfterIndent, range: NSRange(contentAfterIndent.startIndex..., in: contentAfterIndent)),
           let numberRange = Range(match.range(at: 1), in: contentAfterIndent) {
            let number = Int(String(contentAfterIndent[numberRange])) ?? 1
            let currentMarker = leadingWhitespace + "\(number). "
            let nextMarker = leadingWhitespace + "\(number + 1). "
            return ListContinuation(currentMarker: currentMarker, nextMarker: nextMarker)
        }

        // Bullet list: - or * or +
        let bulletPattern = #"^([-*+])\s+"#
        if let regex = try? NSRegularExpression(pattern: bulletPattern),
           let match = regex.firstMatch(in: contentAfterIndent, range: NSRange(contentAfterIndent.startIndex..., in: contentAfterIndent)),
           let bulletRange = Range(match.range(at: 1), in: contentAfterIndent) {
            let bullet = String(contentAfterIndent[bulletRange])
            let marker = leadingWhitespace + bullet + " "
            return ListContinuation(currentMarker: marker, nextMarker: marker)
        }

        // Blockquote: >
        let blockquotePattern = #"^>\s*"#
        if let regex = try? NSRegularExpression(pattern: blockquotePattern),
           regex.firstMatch(in: contentAfterIndent, range: NSRange(contentAfterIndent.startIndex..., in: contentAfterIndent)) != nil {
            let marker = leadingWhitespace + "> "
            return ListContinuation(currentMarker: marker, nextMarker: marker)
        }

        return nil
    }
}

