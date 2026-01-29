import Foundation
import SwiftData
import SwiftUI

/// Stores global editor settings and preferences
@Model
final class EditorSettings {
    /// Singleton identifier (always "default")
    @Attribute(.unique) var id: String

    /// Default font size
    var fontSize: Int

    /// Font family name
    var fontFamily: String

    /// Line height multiplier (1.0 = normal)
    var lineHeight: Double

    /// Default editor mode
    var defaultEditorMode: EditorMode

    /// Show line numbers in source mode
    var showLineNumbers: Bool

    /// Enable syntax highlighting
    var syntaxHighlighting: Bool

    /// Enable spell checking
    var spellCheck: Bool

    /// Enable auto-save
    var autoSave: Bool

    /// Auto-save interval in seconds
    var autoSaveInterval: Int

    /// Theme name (light, dark, system, or custom)
    var theme: String

    /// Editor width constraint (for readability)
    var maxEditorWidth: Int

    /// Show word count in editor
    var showWordCount: Bool

    /// Show character count in editor
    var showCharacterCount: Bool

    /// Enable markdown shortcuts (e.g., *bold* auto-formats)
    var markdownShortcuts: Bool

    /// Default paragraph spacing
    var paragraphSpacing: Double

    init(
        id: String = "default",
        fontSize: Int = 16,
        fontFamily: String = "System",
        lineHeight: Double = 1.5,
        defaultEditorMode: EditorMode = .split,
        showLineNumbers: Bool = true,
        syntaxHighlighting: Bool = true,
        spellCheck: Bool = true,
        autoSave: Bool = true,
        autoSaveInterval: Int = 30,
        theme: String = "system",
        maxEditorWidth: Int = 800,
        showWordCount: Bool = true,
        showCharacterCount: Bool = false,
        markdownShortcuts: Bool = true,
        paragraphSpacing: Double = 12
    ) {
        self.id = id
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.lineHeight = lineHeight
        self.defaultEditorMode = defaultEditorMode
        self.showLineNumbers = showLineNumbers
        self.syntaxHighlighting = syntaxHighlighting
        self.spellCheck = spellCheck
        self.autoSave = autoSave
        self.autoSaveInterval = autoSaveInterval
        self.theme = theme
        self.maxEditorWidth = maxEditorWidth
        self.showWordCount = showWordCount
        self.showCharacterCount = showCharacterCount
        self.markdownShortcuts = markdownShortcuts
        self.paragraphSpacing = paragraphSpacing
    }

    /// Returns the font with current settings
    var editorFont: Font {
        if fontFamily == "System" {
            return .system(size: CGFloat(fontSize), design: .monospaced)
        } else {
            return .custom(fontFamily, size: CGFloat(fontSize))
        }
    }

    /// Available font families
    static let fontFamilies: [String] = [
        "System",
        "SF Mono",
        "Menlo",
        "Monaco",
        "Courier New",
        "Source Code Pro",
        "Fira Code",
        "JetBrains Mono"
    ]

    /// Available themes
    static let themes: [String] = [
        "system",
        "light",
        "dark",
        "sepia",
        "solarized-light",
        "solarized-dark"
    ]
}

// MARK: - Theme Colors

struct EditorTheme {
    let name: String
    let background: Color
    let text: Color
    let heading: Color
    let link: Color
    let code: Color
    let codeBackground: Color
    let blockquote: Color
    let selection: Color

    static let light = EditorTheme(
        name: "light",
        background: Color(white: 1.0),
        text: Color(white: 0.1),
        heading: Color(red: 0.0, green: 0.0, blue: 0.0),
        link: Color(red: 0.0, green: 0.478, blue: 1.0),
        code: Color(red: 0.85, green: 0.26, blue: 0.08),
        codeBackground: Color(white: 0.95),
        blockquote: Color(white: 0.4),
        selection: Color(red: 0.0, green: 0.478, blue: 1.0).opacity(0.2)
    )

    static let dark = EditorTheme(
        name: "dark",
        background: Color(white: 0.11),
        text: Color(white: 0.9),
        heading: Color(white: 1.0),
        link: Color(red: 0.35, green: 0.68, blue: 1.0),
        code: Color(red: 1.0, green: 0.58, blue: 0.42),
        codeBackground: Color(white: 0.18),
        blockquote: Color(white: 0.6),
        selection: Color(red: 0.35, green: 0.68, blue: 1.0).opacity(0.3)
    )

    static let sepia = EditorTheme(
        name: "sepia",
        background: Color(red: 0.98, green: 0.96, blue: 0.89),
        text: Color(red: 0.24, green: 0.2, blue: 0.15),
        heading: Color(red: 0.18, green: 0.15, blue: 0.1),
        link: Color(red: 0.55, green: 0.35, blue: 0.15),
        code: Color(red: 0.65, green: 0.25, blue: 0.15),
        codeBackground: Color(red: 0.94, green: 0.91, blue: 0.82),
        blockquote: Color(red: 0.45, green: 0.4, blue: 0.32),
        selection: Color(red: 0.55, green: 0.35, blue: 0.15).opacity(0.2)
    )

    static func theme(for name: String, colorScheme: ColorScheme) -> EditorTheme {
        switch name {
        case "light":
            return .light
        case "dark":
            return .dark
        case "sepia":
            return .sepia
        case "system":
            return colorScheme == .dark ? .dark : .light
        default:
            return colorScheme == .dark ? .dark : .light
        }
    }
}
