//
//----------------------------------------------
// Original project: RichNotes
// by  Stewart Lynch on 2025-08-16
//
// Follow me on Mastodon: https://iosdev.space/@StewartLynch
// Follow me on Threads: https://www.threads.net/@stewartlynch
// Follow me on Bluesky: https://bsky.app/profile/stewartlynch.bsky.social
// Follow me on X: https://x.com/StewartLynch
// Follow me on LinkedIn: https://linkedin.com/in/StewartLynch
// Email: slynch@createchsol.com
// Subscribe on YouTube: https://youTube.com/@StewartLynch
// Buy me a ko-fi:  https://ko-fi.com/StewartLynch
//----------------------------------------------
// Copyright © 2025 CreaTECH Solutions. All rights reserved.

import SwiftUI
#if os(macOS)
import AppKit
#endif

enum SelectionState {
    enum ToggleState {
        case on, off
    }
    /// Collects the attribute containers for all runs intersecting the current selection.
    static func selectedAttributeContainers(
        text: AttributedString,
        selection: inout AttributedTextSelection
    ) -> [AttributeContainer] {
        var containers: [AttributeContainer] = []
        var probe = text
        probe.transformAttributes(in: &selection) { container in
            containers.append(container)
        }
        return containers
    }

    /// Computes toggle states for the specified text attributes across the current selection,
    /// using a caller-provided resolver for all specified traits.
    static func selectionStyleState(
        text: AttributedString,
        selection: inout AttributedTextSelection,
        resolveTraits: (Font) -> (isBold: Bool, isItalic: Bool)
    ) -> (
        bold: ToggleState,
        italic: ToggleState,
        underline: ToggleState,
        strikethrough: ToggleState,
        leftAlignment: ToggleState,
        centerAlignment: ToggleState,
        rightAlignment: ToggleState,
        extraLargeFont: ToggleState,
        largeFont: ToggleState,
        mediumFont: ToggleState,
        bodyFont: ToggleState,
        footnoteFont: ToggleState
    ) {
        let containers = selectedAttributeContainers(text: text, selection: &selection)

        func collapsed(_ values: [Bool]) -> ToggleState {
            return !values.isEmpty && values.allSatisfy { $0 } ? .on : .off
        }

        let boldValues: [Bool] = containers.map { resolveTraits($0.font ?? .default).isBold }
        let italicValues: [Bool] = containers.map { resolveTraits($0.font ?? .default).isItalic }
        let underlineValues: [Bool] = containers.map { $0.underlineStyle == .single }
        let strikeValues: [Bool] = containers.map { $0.strikethroughStyle == .single }
        
        // Alignment (Checking ParagraphStyle)
        // Accessing AppKit attributes for NSParagraphStyle
        let leftAlignmentValues: [Bool] = containers.map {
            #if os(macOS)
            if let style = $0[AttributeScopes.AppKitAttributes.ParagraphStyleAttribute.self] {
                return style.alignment == .left
            }
            #endif
            return false 
        }
        let centerAlignmentValues: [Bool] = containers.map {
            #if os(macOS)
             if let style = $0[AttributeScopes.AppKitAttributes.ParagraphStyleAttribute.self] {
                return style.alignment == .center
            }
            #endif
            return false
        }
        let rightAlignmentValues: [Bool] = containers.map {
            #if os(macOS)
             if let style = $0[AttributeScopes.AppKitAttributes.ParagraphStyleAttribute.self] {
                return style.alignment == .right
            }
            #endif
            return false
        }
        
        // Font Size Checks
        // We check for both SwiftUI Font (semantic) AND NSFont (point size)
        
        let extraLargeFontValues: [Bool] = containers.map {
            #if os(macOS)
            if let nsFont = $0[AttributeScopes.AppKitAttributes.FontAttribute.self] {
                return abs(nsFont.pointSize - 34) < 0.5
            }
            #endif
            return $0.font == .title
        }
        
        let largeFontValues: [Bool] = containers.map {
            #if os(macOS)
            if let nsFont = $0[AttributeScopes.AppKitAttributes.FontAttribute.self] {
                 return abs(nsFont.pointSize - 28) < 0.5
            }
            #endif
            return $0.font == .title2
        }
        
        let mediumFontValues: [Bool] = containers.map {
            #if os(macOS)
            if let nsFont = $0[AttributeScopes.AppKitAttributes.FontAttribute.self] {
                 return abs(nsFont.pointSize - 22) < 0.5
            }
            #endif
            return $0.font == .title3
        }
        
        let bodyFontValues: [Bool] = containers.map {
            #if os(macOS)
            if let nsFont = $0[AttributeScopes.AppKitAttributes.FontAttribute.self] {
                 return abs(nsFont.pointSize - NSFont.systemFontSize) < 0.5
            }
            #endif
            return $0.font == .body
        }
        
        let footnoteFontValues: [Bool] = containers.map {
            #if os(macOS)
            if let nsFont = $0[AttributeScopes.AppKitAttributes.FontAttribute.self] {
                return abs(nsFont.pointSize - 13) < 0.5
            }
            #endif
            return $0.font == .footnote
        }
       
        return (
            bold: collapsed(boldValues),
            italic: collapsed(italicValues),
            underline: collapsed(underlineValues),
            strikethrough: collapsed(strikeValues),
            leftAlignment: collapsed(leftAlignmentValues),
            centerAlignment: collapsed(centerAlignmentValues),
            rightAlignment: collapsed(rightAlignmentValues),
            extraLargeFont: collapsed(extraLargeFontValues),
            largeFont: collapsed(largeFontValues),
            mediumFont: collapsed(mediumFontValues),
            bodyFont: collapsed(bodyFontValues),
            footnoteFont: collapsed(footnoteFontValues)
        )
    }

    static func isSelected(for state: ToggleState) -> Bool {
        return state == .on
    }
}
