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
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = DynamicSizeTextView()
        textView.delegate = context.coordinator
        
        // Transparent background
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        
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
        // Compare contents to avoid loop
        let current = nsView.textStorage?.string ?? ""
        let newPlain = String(text.characters)
        
        // Quick check on plain text first
        if current != newPlain {
             nsView.textStorage?.setAttributedString(NSAttributedString(text))
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
            // Convert back to AttributedString
            if let storage = textView.textStorage {
                parent.text = AttributedString(storage)
            }
            textView.invalidateIntrinsicContentSize() // Force layout update
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
