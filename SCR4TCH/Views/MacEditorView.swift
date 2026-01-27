//
//  MacEditorView.swift
//  TextEditor
//
//  Created by Antigravity on 2026-01-22.
//

import SwiftUI
import AppKit

struct MacEditorView: NSViewRepresentable {
    @Binding var text: AttributedString
    @Binding var selection: AttributedTextSelection
    var font: NSFont = .systemFont(ofSize: 13)

    /// Callback for URL paste detection. Returns true to allow the paste, false to cancel it.
    var onURLPaste: ((String, NSRange) -> Bool)?

    /// Callback for link clicks
    var onLinkClick: ((URL) -> Bool)?

    func makeNSView(context: Context) -> NSTextView {
        let textView = DynamicSizeTextView()
        textView.delegate = context.coordinator

        // Transparent background and no focus ring
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.focusRingType = .none

        // Configure for auto-resize
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // Remove default padding
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.textContainer?.lineFragmentPadding = 0

        // Set font
        textView.font = font

        // Initial text set
        textView.textStorage?.setAttributedString(NSAttributedString(text))

        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        // Enforce styling
        nsView.drawsBackground = false
        nsView.backgroundColor = .clear
        nsView.focusRingType = .none
        
        // Compare contents to avoid loop
        let current = nsView.textStorage?.string ?? ""
        let newPlain = String(text.characters)

        // Only update if the content has changed externally
        if current != newPlain {
            let selectedRange = nsView.selectedRange()
            nsView.textStorage?.setAttributedString(NSAttributedString(text))
            
            // Restore selection safely
            let newLength = nsView.textStorage?.length ?? 0
            if selectedRange.location + selectedRange.length <= newLength {
                nsView.setSelectedRange(selectedRange)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacEditorView

        init(_ parent: MacEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Convert back to AttributedString and normalize fonts
            if let storage = textView.textStorage {
                // Save selection
                let selectedRange = textView.selectedRange()
                
                // Normalize fonts to remove font family/styles while preserving bold/italic
                let normalized = FontNormalizer.normalizeFonts(storage)
                
                // Update the text view with normalized text first
                textView.textStorage?.setAttributedString(normalized)
                
                // Restore selection
                textView.setSelectedRange(selectedRange)
                
                // Then update the parent binding (which will also normalize, but that's idempotent)
                parent.text = AttributedString(normalized)
            }
            textView.invalidateIntrinsicContentSize() // Force layout update
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard let text = replacementString else { return true }

            // Check if pasted text is a URL
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if URLValidator.extractURL(from: trimmed) != nil {
                // Call parent callback for URL paste
                if let onURLPaste = parent.onURLPaste {
                    return onURLPaste(trimmed, affectedCharRange)
                }
            }
            return true
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let url = link as? URL {
                if let onLinkClick = parent.onLinkClick {
                    return onLinkClick(url)
                }
                // Default behavior: open in browser
                NSWorkspace.shared.open(url)
                return true
            } else if let urlString = link as? String, let url = URL(string: urlString) {
                if let onLinkClick = parent.onLinkClick {
                    return onLinkClick(url)
                }
                NSWorkspace.shared.open(url)
                return true
            }
            return false
        }
    }
}

// Custom subclass to support SwiftUI auto-sizing
class DynamicSizeTextView: NSTextView {
    override var intrinsicContentSize: NSSize {
        guard let layoutManager = layoutManager, let textContainer = textContainer else {
            return super.intrinsicContentSize
        }

        layoutManager.ensureLayout(for: textContainer)
        var size = layoutManager.usedRect(for: textContainer).size

        // Add inset height to the calculation
        let verticalInset = self.textContainerInset.height * 2
        size.height += verticalInset

        // Ensure some minimum height
        size.height = max(size.height, (font?.pointSize ?? 13) + verticalInset)

        // CRITICAL: Return no intrinsic width to allow SwiftUI to constrain it
        size.width = NSView.noIntrinsicMetric

        return size
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }
}
