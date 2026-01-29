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
    @Binding var selectedRange: NSRange // Add binding for NSRange
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
        context.coordinator.lastAppliedText = text

        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        // Enforce styling
        nsView.drawsBackground = false
        nsView.backgroundColor = .clear
        nsView.focusRingType = .none
        
        // Check if update is needed using Coordinator's lastAppliedText
        // This avoids attribute conversion issues and loops
        if context.coordinator.lastAppliedText == text {
            return
        }

        print("MacEditorView Update: receiving new text length \(text.characters.count)")
        
        // Debug attributes at current selection
        let nsAttrDebug = NSAttributedString(text)
        if selectedRange.location < nsAttrDebug.length {
             let attrs = nsAttrDebug.attributes(at: selectedRange.location, effectiveRange: nil)
             print("MacEditorView Update: attributes at \(selectedRange.location): \(attrs)")
        }

        // Apply new text
        // Use binding selectedRange for restoration to prevent loss of focus or sync issues
        var targetRange = selectedRange
        // If binding is invalid (e.g. 0,0 at start but we are typing?), fallback to view.
        // But usually binding is source of truth from parent. 
        // Note: selectedRange might be updated by other views. 
        // We trust the binding.
        
        let newAttr = NSAttributedString(text)
        nsView.textStorage?.setAttributedString(newAttr)
        context.coordinator.lastAppliedText = text
        
        // Restore selection safely
        let newLength = nsView.textStorage?.length ?? 0
        if targetRange.location != NSNotFound && targetRange.location + targetRange.length <= newLength {
            nsView.setSelectedRange(targetRange)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacEditorView
        var lastAppliedText: AttributedString?

        init(_ parent: MacEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Convert back to AttributedString and normalize fonts
            if let storage = textView.textStorage {
                // Save selection
                let selectedRange = textView.selectedRange()
                
                // Do NOT normalize here. Normalization should happen on paste only.
                // let normalized = FontNormalizer.normalizeFonts(storage)
                
                // Convert to AttributedString directly from storage
                // We must use a copy or ensure we are tolerant of attributes
                let newAttributed = AttributedString(storage)
                
                // Update local tracking FIRST to prevent loop when binding updates
                self.lastAppliedText = newAttributed
                
                // Then update the parent binding
                parent.text = newAttributed
                parent.selectedRange = selectedRange
            }
            textView.invalidateIntrinsicContentSize() // Force layout update
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.selectedRange = textView.selectedRange()
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard let text = replacementString else { return true }

            // Check if pasted text is a URL
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URLValidator.extractURL(from: trimmed) {
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
