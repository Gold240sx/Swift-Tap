import SwiftUI
#if canImport(Highlightr)
import Highlightr
#endif

/// Native Swift syntax highlighter using Highlightr
struct SyntaxHighlighter {
    let theme: SyntaxTheme
    let fontSize: CGFloat
    
    #if canImport(Highlightr)
    private let highlightr = Highlightr()
    #endif

    init(theme: SyntaxTheme = .default, fontSize: CGFloat = 14) {
        self.theme = theme
        self.fontSize = fontSize

        #if canImport(Highlightr)
        if let highlightr = highlightr {
            // Map SyntaxTheme name to Highlightr theme name
            let themeName = theme.name.lowercased()
            let style: String

            if themeName.contains("monokai") {
                style = "monokai-sublime"
            } else if themeName.contains("github") {
                style = "github"
            } else if themeName.contains("dark") {
                style = "dracula"
            } else {
                style = "xcode"
            }

            highlightr.setTheme(to: style)

            #if os(macOS)
            let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            highlightr.theme.setCodeFont(font)
            #else
            let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            highlightr.theme.setCodeFont(font)
            #endif
        }
        #endif
    }

    /// Highlights code and returns an AttributedString
    func highlight(_ code: String, language: String) -> AttributedString {
        #if canImport(Highlightr)
        guard let highlightr = highlightr,
              let highlighted = highlightr.highlight(code, as: language) else {
            // Fallback to plain text
            var result = AttributedString(code)
            result.font = .system(size: fontSize, design: .monospaced)
            result.foregroundColor = theme.text
            return result
        }

        return AttributedString(highlighted)
        #else
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text
        return result
        #endif
    }
}

// MARK: - Supported Languages

enum Language: String, CaseIterable {
    case swift
    case python
    case javascript
    case typescript
    case html
    case css
    case json
    case rust
    case go
    case java
    case kotlin
    case c
    case cpp
    case objectivec
    case ruby
    case php
    case sql
    case bash
    case shell
    case zsh
    case yaml
    case markdown
    case plainText = "text"

    var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .html: return "HTML"
        case .css: return "CSS"
        case .json: return "JSON"
        case .rust: return "Rust"
        case .go: return "Go"
        case .java: return "Java"
        case .kotlin: return "Kotlin"
        case .c: return "C"
        case .cpp: return "C++"
        case .objectivec: return "Objective-C"
        case .ruby: return "Ruby"
        case .php: return "PHP"
        case .sql: return "SQL"
        case .bash: return "Bash"
        case .shell: return "Shell"
        case .zsh: return "Zsh"
        case .yaml: return "YAML"
        case .markdown: return "Markdown"
        case .plainText: return "Plain Text"
        }
    }

    var aliases: [String] {
        switch self {
        case .swift: return ["swift"]
        case .python: return ["python", "py"]
        case .javascript: return ["javascript", "js"]
        case .typescript: return ["typescript", "ts"]
        case .html: return ["html", "htm"]
        case .css: return ["css"]
        case .json: return ["json"]
        case .rust: return ["rust", "rs"]
        case .go: return ["go", "golang"]
        case .java: return ["java"]
        case .kotlin: return ["kotlin", "kt"]
        case .c: return ["c", "h"]
        case .cpp: return ["cpp", "c++", "cc", "cxx", "hpp"]
        case .objectivec: return ["objc", "objective-c", "objectivec", "m", "mm"]
        case .ruby: return ["ruby", "rb"]
        case .php: return ["php"]
        case .sql: return ["sql", "mysql", "postgresql", "sqlite"]
        case .bash: return ["bash", "sh"]
        case .shell: return ["shell"]
        case .zsh: return ["zsh"]
        case .yaml: return ["yaml", "yml"]
        case .markdown: return ["markdown", "md"]
        case .plainText: return ["text", "txt", "plain"]
        }
    }

    init?(alias: String) {
        let lowercased = alias.lowercased()
        for lang in Language.allCases {
            if lang.aliases.contains(lowercased) {
                self = lang
                return
            }
        }
        return nil
    }
}

// MARK: - Syntax Themes

struct SyntaxTheme {
    let name: String
    let background: Color
    let text: Color
    let keyword: Color
    let type: Color
    let string: Color
    let number: Color
    let comment: Color
    let function: Color
    let attribute: Color
    let tag: Color
    let operator_: Color

    // MARK: - Light Themes

    static let `default` = light

    static let light = SyntaxTheme(
        name: "Light",
        background: Color(white: 0.97),
        text: Color(white: 0.1),
        keyword: Color(red: 0.63, green: 0.0, blue: 0.55),      // Purple
        type: Color(red: 0.0, green: 0.45, blue: 0.73),          // Blue
        string: Color(red: 0.77, green: 0.1, blue: 0.09),        // Red
        number: Color(red: 0.11, green: 0.0, blue: 0.81),        // Blue
        comment: Color(red: 0.42, green: 0.47, blue: 0.44),      // Gray-green
        function: Color(red: 0.0, green: 0.55, blue: 0.55),      // Teal
        attribute: Color(red: 0.58, green: 0.39, blue: 0.0),     // Brown
        tag: Color(red: 0.0, green: 0.45, blue: 0.73),           // Blue
        operator_: Color(white: 0.1)
    )

    static let github = SyntaxTheme(
        name: "GitHub",
        background: Color(white: 1.0),
        text: Color(red: 0.14, green: 0.16, blue: 0.19),
        keyword: Color(red: 0.84, green: 0.17, blue: 0.32),      // Red
        type: Color(red: 0.4, green: 0.27, blue: 0.6),           // Purple
        string: Color(red: 0.02, green: 0.33, blue: 0.57),       // Blue
        number: Color(red: 0.02, green: 0.33, blue: 0.57),       // Blue
        comment: Color(red: 0.42, green: 0.48, blue: 0.53),      // Gray
        function: Color(red: 0.4, green: 0.27, blue: 0.6),       // Purple
        attribute: Color(red: 0.02, green: 0.33, blue: 0.57),    // Blue
        tag: Color(red: 0.13, green: 0.53, blue: 0.29),          // Green
        operator_: Color(red: 0.84, green: 0.17, blue: 0.32)     // Red
    )

    static let xcode = SyntaxTheme(
        name: "Xcode",
        background: Color(white: 1.0),
        text: Color(white: 0.0),
        keyword: Color(red: 0.61, green: 0.14, blue: 0.58),      // Magenta
        type: Color(red: 0.11, green: 0.38, blue: 0.54),         // Blue
        string: Color(red: 0.77, green: 0.10, blue: 0.09),       // Red
        number: Color(red: 0.11, green: 0.0, blue: 0.81),        // Blue
        comment: Color(red: 0.36, green: 0.42, blue: 0.36),      // Gray-green
        function: Color(red: 0.23, green: 0.35, blue: 0.40),     // Dark teal
        attribute: Color(red: 0.51, green: 0.27, blue: 0.0),     // Brown
        tag: Color(red: 0.11, green: 0.38, blue: 0.54),          // Blue
        operator_: Color(white: 0.0)
    )

    // MARK: - Dark Themes

    static let dark = SyntaxTheme(
        name: "Dark",
        background: Color(red: 0.12, green: 0.12, blue: 0.14),
        text: Color(white: 0.92),
        keyword: Color(red: 0.99, green: 0.47, blue: 0.66),      // Pink
        type: Color(red: 0.55, green: 0.83, blue: 0.99),         // Light blue
        string: Color(red: 0.99, green: 0.82, blue: 0.55),       // Orange
        number: Color(red: 0.82, green: 0.75, blue: 0.99),       // Light purple
        comment: Color(red: 0.53, green: 0.56, blue: 0.60),      // Gray
        function: Color(red: 0.55, green: 0.99, blue: 0.82),     // Mint
        attribute: Color(red: 0.99, green: 0.75, blue: 0.55),    // Peach
        tag: Color(red: 0.55, green: 0.83, blue: 0.99),          // Light blue
        operator_: Color(white: 0.92)
    )

    static let monokai = SyntaxTheme(
        name: "Monokai",
        background: Color(red: 0.15, green: 0.16, blue: 0.13),
        text: Color(red: 0.97, green: 0.97, blue: 0.95),
        keyword: Color(red: 0.98, green: 0.15, blue: 0.45),      // Pink/Red
        type: Color(red: 0.40, green: 0.85, blue: 0.94),         // Cyan
        string: Color(red: 0.90, green: 0.86, blue: 0.45),       // Yellow
        number: Color(red: 0.68, green: 0.51, blue: 1.0),        // Purple
        comment: Color(red: 0.46, green: 0.44, blue: 0.37),      // Gray
        function: Color(red: 0.65, green: 0.89, blue: 0.18),     // Green
        attribute: Color(red: 0.99, green: 0.60, blue: 0.0),     // Orange
        tag: Color(red: 0.98, green: 0.15, blue: 0.45),          // Pink/Red
        operator_: Color(red: 0.98, green: 0.15, blue: 0.45)     // Pink/Red
    )

    static let dracula = SyntaxTheme(
        name: "Dracula",
        background: Color(red: 0.16, green: 0.16, blue: 0.21),
        text: Color(red: 0.97, green: 0.97, blue: 0.95),
        keyword: Color(red: 1.0, green: 0.47, blue: 0.65),       // Pink
        type: Color(red: 0.55, green: 0.93, blue: 0.99),         // Cyan
        string: Color(red: 0.95, green: 0.98, blue: 0.48),       // Yellow
        number: Color(red: 0.74, green: 0.58, blue: 0.98),       // Purple
        comment: Color(red: 0.38, green: 0.45, blue: 0.53),      // Gray
        function: Color(red: 0.31, green: 0.98, blue: 0.48),     // Green
        attribute: Color(red: 1.0, green: 0.72, blue: 0.42),     // Orange
        tag: Color(red: 1.0, green: 0.47, blue: 0.65),           // Pink
        operator_: Color(red: 1.0, green: 0.47, blue: 0.65)      // Pink
    )

    static let oneDark = SyntaxTheme(
        name: "One Dark",
        background: Color(red: 0.16, green: 0.18, blue: 0.21),
        text: Color(red: 0.67, green: 0.73, blue: 0.82),
        keyword: Color(red: 0.78, green: 0.47, blue: 0.82),      // Purple
        type: Color(red: 0.90, green: 0.75, blue: 0.55),         // Orange/Yellow
        string: Color(red: 0.60, green: 0.76, blue: 0.45),       // Green
        number: Color(red: 0.82, green: 0.60, blue: 0.42),       // Orange
        comment: Color(red: 0.36, green: 0.41, blue: 0.48),      // Gray
        function: Color(red: 0.38, green: 0.67, blue: 0.93),     // Blue
        attribute: Color(red: 0.90, green: 0.75, blue: 0.55),    // Orange/Yellow
        tag: Color(red: 0.90, green: 0.45, blue: 0.45),          // Red
        operator_: Color(red: 0.34, green: 0.71, blue: 0.80)     // Cyan
    )

    static let solarizedDark = SyntaxTheme(
        name: "Solarized Dark",
        background: Color(red: 0.0, green: 0.17, blue: 0.21),
        text: Color(red: 0.51, green: 0.58, blue: 0.59),
        keyword: Color(red: 0.52, green: 0.6, blue: 0.0),        // Green
        type: Color(red: 0.15, green: 0.55, blue: 0.82),         // Blue
        string: Color(red: 0.16, green: 0.63, blue: 0.60),       // Cyan
        number: Color(red: 0.16, green: 0.63, blue: 0.60),       // Cyan
        comment: Color(red: 0.35, green: 0.43, blue: 0.46),      // Gray
        function: Color(red: 0.15, green: 0.55, blue: 0.82),     // Blue
        attribute: Color(red: 0.71, green: 0.54, blue: 0.0),     // Yellow
        tag: Color(red: 0.15, green: 0.55, blue: 0.82),          // Blue
        operator_: Color(red: 0.52, green: 0.6, blue: 0.0)       // Green
    )

    // MARK: - Theme Selection

    static let lightThemes: [SyntaxTheme] = [.light, .github, .xcode]
    static let darkThemes: [SyntaxTheme] = [.dark, .monokai, .dracula, .oneDark, .solarizedDark]

    static func forColorScheme(_ scheme: ColorScheme) -> SyntaxTheme {
        scheme == .dark ? .dark : .light
    }

    static func theme(named name: String) -> SyntaxTheme? {
        let allThemes = lightThemes + darkThemes
        return allThemes.first { $0.name.lowercased() == name.lowercased() }
    }
}

