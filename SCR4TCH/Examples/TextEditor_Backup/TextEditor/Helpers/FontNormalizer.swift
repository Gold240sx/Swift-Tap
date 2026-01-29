//
//  FontNormalizer.swift
//  TextEditor
//
//  Helper to normalize fonts in pasted text - removes font family/styles
//  but preserves bold and italic formatting.
//

import SwiftUI
import AppKit

struct FontNormalizer {
    /// Normalizes fonts in an NSAttributedString by removing font family/styles
    /// while preserving bold and italic traits. Uses system font.
    static func normalizeFonts(_ nsAttributedString: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: nsAttributedString)
        let fullRange = NSRange(location: 0, length: mutable.length)
        
        // Enumerate through all font attributes
        mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let nsFont = value as? NSFont else { return }
            
            // Extract font traits (bold, italic)
            let fontDescriptor = nsFont.fontDescriptor
            let traits = fontDescriptor.symbolicTraits
            let isBold = traits.contains(.bold)
            let isItalic = traits.contains(.italic)
            
            // Get the point size
            let pointSize = nsFont.pointSize
            
            // Create a new system font with preserved traits
            let baseFont = NSFont.systemFont(ofSize: pointSize)
            let baseDescriptor = baseFont.fontDescriptor
            
            var newFont: NSFont
            if isBold && isItalic {
                // Combine bold and italic traits
                var traits = baseDescriptor.symbolicTraits
                traits.insert(.bold)
                traits.insert(.italic)
                let combinedDescriptor = baseDescriptor.withSymbolicTraits(traits)
                newFont = NSFont(descriptor: combinedDescriptor, size: pointSize) ?? NSFont.boldSystemFont(ofSize: pointSize)
            } else if isBold {
                newFont = NSFont.boldSystemFont(ofSize: pointSize)
            } else if isItalic {
                var traits = baseDescriptor.symbolicTraits
                traits.insert(.italic)
                let italicDescriptor = baseDescriptor.withSymbolicTraits(traits)
                newFont = NSFont(descriptor: italicDescriptor, size: pointSize) ?? baseFont
            } else {
                newFont = baseFont
            }
            
            // Replace the font
            mutable.addAttribute(.font, value: newFont, range: range)
        }
        
        return mutable
    }
    
    /// Normalizes fonts in an AttributedString by removing font family/styles
    /// while preserving bold and italic traits. Uses system font.
    static func normalizeFonts(_ text: AttributedString) -> AttributedString {
        // Convert to NSAttributedString, normalize, then convert back
        let nsAttributedString = NSAttributedString(text)
        let normalized = normalizeFonts(nsAttributedString)
        return AttributedString(normalized)
    }
}
