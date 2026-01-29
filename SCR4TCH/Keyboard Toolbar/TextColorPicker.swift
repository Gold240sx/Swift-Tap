import SwiftUI
import AppKit
import ColorSelector

struct TextColorPicker: View {
    @Binding var text: AttributedString
    @Binding var selectedRange: NSRange
    
    @State private var color: Color? = .white
    @State private var showPicker = false
    @State private var isInternalUpdate = false
    @State private var buttonSize: ControlSize = .regular
    
    var body: some View {
        ColorSelectorButton(
            popover: $showPicker,
            selection: $color,
            controlSize: $buttonSize
        )
        .colorSelectorPopover(
            selection: $color,
            isPresented: $showPicker
        )
        .onChange(of: color) { _, newColor in
            guard !isInternalUpdate, let targetColor = newColor else { return }
            
            print("TextColorPicker: applying color \(targetColor)")
            print("TextColorPicker: selectedRange \(selectedRange)")

            // Use NSAttributedString for safe NSRange handling
            let nsAttr = NSMutableAttributedString(text)
            
            // Validate range against UTF-16 length
            guard selectedRange.location >= 0,
                  selectedRange.location + selectedRange.length <= nsAttr.length else {
                print("TextColorPicker: invalid range bounds (location: \(selectedRange.location), length: \(selectedRange.length), textLength: \(nsAttr.length))")
                return
            }
            
            var targetRange = selectedRange
            
            // Auto-expand to word if selection is empty (caret only)
            if targetRange.length == 0 && nsAttr.length > 0 {
                let string = nsAttr.string
                let location = targetRange.location
                
                string.enumerateSubstrings(in: string.startIndex..<string.endIndex, options: .byWords) { _, range, _, stop in
                    let nsRange = NSRange(range, in: string)
                    if location >= nsRange.location && location <= nsRange.location + nsRange.length {
                        targetRange = nsRange
                        print("TextColorPicker: Auto-expanded selection to word ' \(string[range])' at \(targetRange)")
                        stop = true
                    }
                }
            }

            // Apply color
            let nsColor = NSColor(targetColor)
            if targetRange.length > 0 {
                nsAttr.addAttribute(.foregroundColor, value: nsColor, range: targetRange)
                
                // Apply custom intentColor if extension exists
                if let hex = targetColor.toHex() {
                    nsAttr.addAttribute(NSAttributedString.Key("intentColor"), value: hex, range: targetRange)
                }
            } else {
                print("TextColorPicker: Range remains empty, cannot apply color to storage.")
            }
            
            // Convert back to AttributedString
            text = AttributedString(nsAttr)
        }
        .onChange(of: selectedRange) { _, _ in
            syncColorFromSelection()
        }
        .onAppear {
            syncColorFromSelection()
        }
    }
    
    private func syncColorFromSelection() {
        let nsAttr = NSAttributedString(text)
        
        // Check bounds
        guard selectedRange.location < nsAttr.length, selectedRange.location >= 0 else { return }
        
        // Get attributes at the start of selection (or just insertion point)
        // effectiveRange is not strictly needed here
        let attributes = nsAttr.attributes(at: selectedRange.location, effectiveRange: nil)
        
        if let nsColor = attributes[.foregroundColor] as? NSColor {
            let swiftColor = Color(nsColor)
            
            // Avoid infinite loop by checking similarity
            if let currentColor = color, currentColor.isSimilar(to: swiftColor) {
               return
            }
            
            isInternalUpdate = true
            color = swiftColor
            
            DispatchQueue.main.async {
                isInternalUpdate = false
            }
        }
    }
}

