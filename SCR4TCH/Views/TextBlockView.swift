//
//  TextBlockView.swift
//  TextEditor
//
//  A wrapper view for NoteBlock text content.
//

import SwiftUI
import AppKit

struct TextBlockView: View {
    @Bindable var block: NoteBlock
    @Binding var selection: AttributedTextSelection
    var focusState: FocusState<UUID?>.Binding
    var onDelete: () -> Void = {}
    var onMerge: () -> Void = {}
    var onExtractSelection: () -> Void = {}

    /// Callback for inserting a bookmark block (called when user selects bookmark from URL paste popover)
    var onInsertBookmark: ((URL) -> Void)?

    var isNested: Bool = false

    @State private var eventMonitor: Any?
    @State private var showURLPastePopover = false
    @State private var pendingURLPaste: (url: URL, range: NSRange)?

    var body: some View {
        ZStack(alignment: .topLeading) {
            MacEditorView(
                text: Binding(
                    get: { block.text ?? AttributedString("") },
                    set: { block.text = $0 }
                ),
                selection: $selection,
                font: isNested ? .systemFont(ofSize: 13) : .systemFont(ofSize: NSFont.systemFontSize),
                onURLPaste: handleURLPaste
            )
            
            // Placeholder text
            if (block.text?.characters.isEmpty ?? true) && focusState.wrappedValue != block.id {
                Text("Type Content here")
                    .font(isNested ? .system(size: 13) : .system(size: NSFont.systemFontSize))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
        }
        .popover(isPresented: $showURLPastePopover) {
            if let pending = pendingURLPaste {
                URLPastePopover(
                    url: pending.url,
                    onSelect: { type in
                        handleURLTypeSelection(type, url: pending.url, range: pending.range)
                        showURLPastePopover = false
                        pendingURLPaste = nil
                    },
                    onCancel: {
                        // Insert the URL as plain text
                        insertPlainURL(pending.url.absoluteString, at: pending.range)
                        showURLPastePopover = false
                        pendingURLPaste = nil
                    }
                )
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            setupEventMonitor()
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
        .contextMenu {
            if !isSelectionEmpty && !isFullSelection {
                Button {
                    onExtractSelection()
                } label: {
                    Label("Make Text Block", systemImage: "rectangle.badge.plus")
                }
            }

            Button {
                selectAll()
            } label: {
                Label("Select All in Block", systemImage: "checkmark.circle")
            }
        }
    }

    private var isSelectionEmpty: Bool {
        guard let text = block.text else { return true }
        switch selection.indices(in: text) {
        case .ranges(let ranges):
            return ranges.ranges.isEmpty
        default:
            return true
        }
    }

    private var isFullSelection: Bool {
        guard let text = block.text else { return false }
        switch selection.indices(in: text) {
        case .ranges(let ranges):
            guard let first = ranges.ranges.first else { return false }
            return first.lowerBound == text.startIndex && first.upperBound == text.endIndex
        default:
            return false
        }
    }

    private func selectAll() {
        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
    }

    private func setupEventMonitor() {
        if eventMonitor != nil { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard focusState.wrappedValue == block.id else { return event }

            if event.keyCode == 51 { // Delete (Backspace)
                if let text = block.text {
                    if !isSelectionEmpty {
                        return event
                    }

                    if text.characters.isEmpty {
                        DispatchQueue.main.async {
                            onDelete()
                        }
                        return nil
                    } else {
                        let indices = selection.indices(in: text)
                        var isAtStart = false

                        switch indices {
                        case .insertionPoint(let index):
                            if index == text.startIndex { isAtStart = true }
                        case .ranges(let ranges):
                            if let first = ranges.ranges.first, first.lowerBound == text.startIndex {
                                isAtStart = true
                            }
                        @unknown default:
                            break
                        }

                        if isAtStart {
                            DispatchQueue.main.async {
                                onMerge()
                            }
                            return nil
                        }
                    }
                }
            }

            return event
        }
    }

    // MARK: - URL Paste Handling

    /// Handles URL paste detection from MacEditorView
    private func handleURLPaste(_ urlString: String, _ range: NSRange) -> Bool {
        guard let url = URLValidator.extractURL(from: urlString) else {
            return true // Not a valid URL, allow normal paste
        }

        // Store the pending URL and show popover
        pendingURLPaste = (url: url, range: range)
        showURLPastePopover = true

        return false // Cancel the paste, we'll handle it ourselves
    }

    /// Handles the user's selection from the URL paste popover
    private func handleURLTypeSelection(_ type: URLDisplayType, url: URL, range: NSRange) {
        switch type {
        case .standard:
            insertStandardLink(url, at: range)
        case .bookmark:
            onInsertBookmark?(url)
        }
    }

    /// Inserts a standard link (blue underlined text)
    private func insertStandardLink(_ url: URL, at range: NSRange) {
        var text = block.text ?? AttributedString("")
        var linkText = AttributedString(url.absoluteString)
        linkText.link = url
        linkText.foregroundColor = .blue
        linkText.underlineStyle = .single

        // Insert at the range
        if let swiftRange = Range(range, in: String(text.characters)) {
            let startIndex = text.index(text.startIndex, offsetByCharacters: swiftRange.lowerBound.utf16Offset(in: String(text.characters)))
            let endIndex = text.index(text.startIndex, offsetByCharacters: swiftRange.upperBound.utf16Offset(in: String(text.characters)))
            text.replaceSubrange(startIndex..<endIndex, with: linkText)
        } else {
            text.append(linkText)
        }

        block.text = text
    }

    /// Inserts plain URL text
    private func insertPlainURL(_ urlString: String, at range: NSRange) {
        var text = block.text ?? AttributedString("")
        let plainText = AttributedString(urlString)

        if let swiftRange = Range(range, in: String(text.characters)) {
            let startIndex = text.index(text.startIndex, offsetByCharacters: swiftRange.lowerBound.utf16Offset(in: String(text.characters)))
            let endIndex = text.index(text.startIndex, offsetByCharacters: swiftRange.upperBound.utf16Offset(in: String(text.characters)))
            text.replaceSubrange(startIndex..<endIndex, with: plainText)
        } else {
            text.append(plainText)
        }

        block.text = text
    }
}
