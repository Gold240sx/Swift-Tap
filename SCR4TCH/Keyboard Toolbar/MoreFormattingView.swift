import SwiftUI
import AppKit

struct MoreFormattingView: View {
    @Binding var text: AttributedString
    @Binding var selectedRange: NSRange
    @ObservedObject private var langManager = LanguageManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(langManager.translate("format")).bold()
            
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    // Font Sizes
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        fontSizeButton(label: "extra_large", size: 34, weight: .bold)
                        fontSizeButton(label: "large", size: 28, weight: .semibold)
                        fontSizeButton(label: "medium", size: 22, weight: .medium)
                        fontSizeButton(label: "body_font", size: NSFont.systemFontSize, weight: .regular)
                        fontSizeButton(label: "footnote_font", size: 13, weight: .regular)
                    }
                    
                    HStack(spacing: 4) {
                        FormatStyleButtons(text: $text, selectedRange: $selectedRange)
                        
                        Divider().frame(height: 20)
                        
                        // Alignment
                        alignmentButton(icon: "text.alignleft", align: .left)
                        alignmentButton(icon: "text.aligncenter", align: .center)
                        alignmentButton(icon: "text.alignright", align: .right)
                        
                        Divider().frame(height: 20)
                        
                        TextColorPicker(text: $text, selectedRange: $selectedRange)
                            .frame(width: 40, height: 40)
                    }
                }
            }
            .padding(.bottom, 8)
            
            Button(langManager.translate("remove_formatting")) {
                removeFormatting()
            }
            .buttonStyle(.bordered)
            
            // URL Conversion
            if let url = selectedTextAsURL() {
                Divider()
                Button(langManager.translate("convert_to_link")) {
                    convertToStandardURL(url)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(minWidth: 400)
    }
    
    // MARK: - Components
    
    private func fontSizeButton(label: String, size: CGFloat, weight: NSFont.Weight) -> some View {
        Button(langManager.translate(label)) {
            applyFontSize(size, weight: weight)
        }
        .buttonStyle(.plain)
        .font(.system(size: size > 20 ? 20 : size)) // Scale down for UI
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isFontSize(size) ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isFontSize(size) ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }
    
    private func alignmentButton(icon: String, align: NSTextAlignment) -> some View {
        Button {
            applyAlignment(align)
        } label: {
            Image(systemName: icon)
                .font(.system(size: langManager.scaledFontSize(16)))
        }
        .frame(width: 40, height: 40)
        .selectedBackground(state: isAlignment(align))
        .help(langManager.translate(icon))
    }
    
    // MARK: - Formatting Logic
    
    private func isFontSize(_ size: CGFloat) -> Bool {
        // Simple check: check first char's font size
        let nsAttr = NSAttributedString(text)
        guard selectedRange.location < nsAttr.length else { return false }
        if let font = nsAttr.attribute(.font, at: selectedRange.location, effectiveRange: nil) as? NSFont {
            return abs(font.pointSize - size) < 0.5
        }
        return false
    }
    
    private func applyFontSize(_ size: CGFloat, weight: NSFont.Weight) {
        let nsAttr = NSMutableAttributedString(text)
        guard selectedRange.location + selectedRange.length <= nsAttr.length, selectedRange.length > 0 else { return }
        
        let newFont = NSFont.systemFont(ofSize: size, weight: weight)
        nsAttr.addAttribute(.font, value: newFont, range: selectedRange)
        text = AttributedString(nsAttr)
    }
    
    private func isAlignment(_ align: NSTextAlignment) -> Bool {
        let nsAttr = NSAttributedString(text)
        guard selectedRange.location < nsAttr.length else { return false }
        if let para = nsAttr.attribute(.paragraphStyle, at: selectedRange.location, effectiveRange: nil) as? NSParagraphStyle {
            return para.alignment == align
        }
        // Default might be left/natural
        return align == .left // simplified
    }
    
    private func applyAlignment(_ align: NSTextAlignment) {
        let nsAttr = NSMutableAttributedString(text)
        guard selectedRange.location + selectedRange.length <= nsAttr.length, selectedRange.length > 0 else { return }
        
        // We probably shouldn't replace the ENTIRE paragraph style, but copy and modify
        nsAttr.enumerateAttribute(.paragraphStyle, in: selectedRange, options: [.longestEffectiveRangeNotRequired]) { value, range, _ in
            let para = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            para.alignment = align
            nsAttr.addAttribute(.paragraphStyle, value: para, range: range)
        }
        text = AttributedString(nsAttr)
    }
    
    private func removeFormatting() {
        let nsAttr = NSMutableAttributedString(text)
        guard selectedRange.location + selectedRange.length <= nsAttr.length, selectedRange.length > 0 else { return }
        
        // Keep purely content attributes? Or remove style attributes?
        // Remove font, color, underline, strikethrough, paragraphStyle
        let keysToRemove: [NSAttributedString.Key] = [.font, .foregroundColor, .underlineStyle, .strikethroughStyle, .paragraphStyle, .link, .backgroundColor, NSAttributedString.Key("intentColor")]
        for key in keysToRemove {
            nsAttr.removeAttribute(key, range: selectedRange)
        }
        // Restore default font?
        nsAttr.addAttribute(.font, value: NSFont.systemFont(ofSize: NSFont.systemFontSize), range: selectedRange)
        nsAttr.addAttribute(.foregroundColor, value: NSColor.labelColor, range: selectedRange)
        
        text = AttributedString(nsAttr)
    }
    
    // MARK: - URL Conversion
    
    private func selectedTextAsURL() -> URL? {
        let nsAttr = NSAttributedString(text)
        guard selectedRange.length > 0, selectedRange.location + selectedRange.length <= nsAttr.length else { return nil }
        
        let selectedString = nsAttr.attributedSubstring(from: selectedRange).string.trimmingCharacters(in: .whitespacesAndNewlines)
        return URLValidator.extractURL(from: selectedString)
    }
    
    private func convertToStandardURL(_ url: URL) {
        let nsAttr = NSMutableAttributedString(text)
        guard selectedRange.location + selectedRange.length <= nsAttr.length else { return }
        
        nsAttr.addAttribute(.link, value: url, range: selectedRange)
        nsAttr.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: selectedRange)
        nsAttr.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
        
        text = AttributedString(nsAttr)
    }
}

