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

extension Color {
    // Used so I can store hex color values as Strings in my SwiftData models
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0
        
        let length = hexSanitized.count
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
            
        } else {
            return nil
        }
        
        self.init(red: r, green: g, blue: b, opacity: a)
    }
    
    func toHex() -> String? {
        #if canImport(UIKit)
        let color = UIColor(self)
        #elseif canImport(AppKit)
        let color = NSColor(self)
        #endif
        
        guard let components = color.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        if a != Float(1.0) {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
    
    /// Returns a version of the color that automatically adjusts for Dark Mode.
    /// Especially useful for text colors picked by the user (like Black/Gray).
    func adaptive() -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traitCollection in
            let lightColor = UIColor(self)
            if traitCollection.userInterfaceStyle == .dark {
                return lightColor.invertedBrightness()
            }
            return lightColor
        })
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let lightColor = NSColor(self)
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return lightColor.invertedBrightness()
            }
            return lightColor
        })
        #else
        return self
        #endif
    }
    
    /// Resolves the color to its base 'Light Mode' version (the original intent).
    func raw() -> Color {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        return Color(uiColor: uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)))
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
        var resolved: NSColor = nsColor
        NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance {
            resolved = nsColor.usingColorSpace(.sRGB) ?? nsColor
        }
        return Color(nsColor: resolved)
        #else
        return self
        #endif
    }
    
    /// Checks if two colors are visually similar in HSB space to avoid jitter
    func isSimilar(to other: Color, tolerance: CGFloat = 0.01) -> Bool {
        var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        #if canImport(UIKit)
        guard UIColor(self).getHue(&h1, saturation: &s1, brightness: &b1, alpha: &a1),
              UIColor(other).getHue(&h2, saturation: &s2, brightness: &b2, alpha: &a2) else { return false }
        #elseif canImport(AppKit)
        guard let c1 = NSColor(self).usingColorSpace(.genericRGB),
              let c2 = NSColor(other).usingColorSpace(.genericRGB) else { return false }
        c1.getHue(&h1, saturation: &s1, brightness: &b1, alpha: &a1)
        c2.getHue(&h2, saturation: &s2, brightness: &b2, alpha: &a2)
        #endif

        return abs(h1 - h2) < tolerance &&
               abs(s1 - s2) < tolerance &&
               abs(b1 - b2) < tolerance &&
               abs(a1 - a2) < tolerance
    }

    /// Returns a color with inverted brightness (for dark mode adaptation).
    /// Keeps hue and saturation intact, only flips brightness.
    func invertedBrightness() -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor(self).invertedBrightness())
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor(self).invertedBrightness())
        #else
        return self
        #endif
    }
}

// MARK: - Custom AttributedString Attributes
public struct IntentColorAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
    public typealias Value = String // Store hex for Codable support
    public static let name = "intentColor"
}

extension AttributeScopes {
    public struct AppAttributes: AttributeScope {
        public let intentColor: IntentColorAttribute
    }
    
    public var app: AppAttributes { AppAttributes(intentColor: IntentColorAttribute()) }
}

extension AttributeDynamicLookup {
    public subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.AppAttributes, T>) -> T {
        return self[T.self]
    }
}

extension AttributedString {
    /// Returns a copy adapted for display based on current theme.
    /// In light mode, returns self unchanged.
    /// In dark mode, inverts brightness of colored text for readability.
    func adaptedForDisplay(isDarkMode: Bool) -> AttributedString {
        guard isDarkMode else { return self }

        var result = self
        for run in result.runs {
            // Use intentColor (stored hex) as the source of truth for the user's chosen color
            if let hex = run.intentColor, let intent = Color(hex: hex) {
                result[run.range].foregroundColor = intent.invertedBrightness()
            } else if let current = run.foregroundColor {
                // No intentColor stored - this is legacy text or default color
                // Invert for display in dark mode
                result[run.range].foregroundColor = current.invertedBrightness()
            }
            // Text with no foreground color uses system default - leave unchanged
        }
        return result
    }

    /// Ensures raw/intent colors are stored, stripping any display adaptations.
    /// This is the inverse of adaptedForDisplay - restores colors to their light-mode intent.
    func strippingAdaptiveColors() -> AttributedString {
        var result = self
        for run in result.runs {
            // If we have an intentColor, that's the source of truth - restore it
            if let hex = run.intentColor, let intent = Color(hex: hex) {
                result[run.range].foregroundColor = intent
            }
            // If we have a foregroundColor but no intentColor, establish the intent
            else if let current = run.foregroundColor {
                let raw = current.raw()
                if let hex = raw.toHex() {
                    result[run.range].intentColor = hex
                }
                result[run.range].foregroundColor = raw
            }
            // No color attributes - leave unchanged
        }
        return result
    }
}

#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
#endif

extension PlatformColor {
    func invertedBrightness() -> PlatformColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        
        #if canImport(UIKit)
        guard self.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        #elseif canImport(AppKit)
        guard let hsbColor = self.usingColorSpace(.genericRGB) ?? self.usingColorSpace(.deviceRGB) else { return self }
        hsbColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #endif
        
        // Flip the brightness
        // A true brightness flip (1.0 - b) ensures that dark intent becomes light display 
        // and vice versa, while maintaining the intended color identity (hue/saturation).
        let newB = 1.0 - b
        
        return PlatformColor(hue: h, saturation: s, brightness: newB, alpha: a)
    }
}
