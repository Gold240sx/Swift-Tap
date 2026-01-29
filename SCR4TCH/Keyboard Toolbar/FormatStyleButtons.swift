import SwiftUI
import AppKit

struct FormatStyleButtons: View {
    @Binding var text: AttributedString
    @Binding var selectedRange: NSRange
    @ObservedObject private var langManager = LanguageManager.shared

    // MARK: - Computed States
    
    private var isBold: Bool {
        hasTrait(.bold)
    }
    
    private var isItalic: Bool {
        hasTrait(.italic)
    }
    
    private var isUnderline: Bool {
        hasAttribute(.underlineStyle)
    }
    
    private var isStrikethrough: Bool {
        hasAttribute(.strikethroughStyle)
    }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                toggleTrait(.boldFontMask)
            } label: {
                Image(systemName: "bold")
                    .font(.system(size: langManager.scaledFontSize(16)))
            }
            .frame(width: 40, height: 40)
            .selectedBackground(state: isBold)
            .help(langManager.translate("bold"))

            Button {
                toggleTrait(.italicFontMask)
            } label: {
                Image(systemName: "italic")
                    .font(.system(size: langManager.scaledFontSize(16)))
            }
            .frame(width: 40, height: 40)
            .selectedBackground(state: isItalic)
            .help(langManager.translate("italic"))

            Button {
                toggleAttribute(.underlineStyle)
            } label: {
                Image(systemName: "underline")
                    .font(.system(size: langManager.scaledFontSize(16)))
            }
            .frame(width: 40, height: 40)
            .selectedBackground(state: isUnderline)
            .help(langManager.translate("underline"))

            Button {
                toggleAttribute(.strikethroughStyle)
            } label: {
                Image(systemName: "strikethrough")
                    .font(.system(size: langManager.scaledFontSize(16)))
            }
            .frame(width: 40, height: 40)
            .selectedBackground(state: isStrikethrough)
            .help(langManager.translate("strikethrough"))
        }
    }

    // MARK: - State Helpers

    private func hasTrait(_ trait: NSFontDescriptor.SymbolicTraits) -> Bool {
        let nsAttr = NSAttributedString(text)
        guard selectedRange.location < nsAttr.length else { return false }
        
        let attributes = nsAttr.attributes(at: selectedRange.location, effectiveRange: nil)
        if let font = attributes[.font] as? NSFont {
            return font.fontDescriptor.symbolicTraits.contains(trait)
        }
        return false
    }
    
    private func hasAttribute(_ key: NSAttributedString.Key) -> Bool {
        let nsAttr = NSAttributedString(text)
        guard selectedRange.location < nsAttr.length else { return false }
        
        let attributes = nsAttr.attributes(at: selectedRange.location, effectiveRange: nil)
        if let value = attributes[key] as? Int, value != 0 {
            return true
        }
        return false
    }

    // MARK: - Actions

    private func toggleTrait(_ mask: NSFontTraitMask) {
        var symbolicTrait: NSFontDescriptor.SymbolicTraits = []
        if mask.contains(.boldFontMask) { symbolicTrait = .bold }
        if mask.contains(.italicFontMask) { symbolicTrait = .italic }
        
        let shouldAdd = !hasTrait(symbolicTrait)
        
        let nsAttr = NSMutableAttributedString(text)
        
        guard selectedRange.location + selectedRange.length <= nsAttr.length else { return }
        
        // We must check if length is 0. If 0, we might want to apply to typing attributes?
        // But for now, let's assume valid selection or word under cursor.
        // If selection is length 0, macOS usually handles typing attributes in the TextView.
        // However, here we are editing the STORAGE directly.
        // Editing storage with 0 length selection doesn't do anything visible unless we insert.
        // So this button primarily works on SELECTION.
        
        if selectedRange.length > 0 {
            print("Applying trait: \(mask.contains(.boldFontMask) ? "Bold" : "Italic")")
            print("Selected Range: \(selectedRange)")
            let selectedText = nsAttr.attributedSubstring(from: selectedRange).string
            print("Selected Content: \(selectedText)")

            nsAttr.enumerateAttribute(.font, in: selectedRange, options: [.longestEffectiveRangeNotRequired]) { value, range, _ in
                let currentFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                
                let newFont: NSFont
                if shouldAdd {
                    newFont = NSFontManager.shared.convert(currentFont, toHaveTrait: mask)
                } else {
                    newFont = NSFontManager.shared.convert(currentFont, toNotHaveTrait: mask)
                }
                nsAttr.addAttribute(.font, value: newFont, range: range)
            }
            text = AttributedString(nsAttr)
        }
    }

    private func toggleAttribute(_ key: NSAttributedString.Key) {
        let shouldAdd = !hasAttribute(key)
        let nsAttr = NSMutableAttributedString(text)
        
        guard selectedRange.location + selectedRange.length <= nsAttr.length else { return }
        
        if selectedRange.length > 0 {
            print("Applying attribute: \(key.rawValue)")
            print("Selected Range: \(selectedRange)")
            let selectedText = nsAttr.attributedSubstring(from: selectedRange).string
            print("Selected Content: \(selectedText)")

            if shouldAdd {
                nsAttr.addAttribute(key, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
            } else {
                nsAttr.removeAttribute(key, range: selectedRange)
            }
            text = AttributedString(nsAttr)
        }
    }
}

