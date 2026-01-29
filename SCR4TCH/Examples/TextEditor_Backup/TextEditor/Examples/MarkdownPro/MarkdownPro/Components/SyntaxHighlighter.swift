import SwiftUI

/// Native Swift syntax highlighter supporting multiple languages and themes
struct SyntaxHighlighter {
    let theme: SyntaxTheme
    let fontSize: CGFloat

    init(theme: SyntaxTheme = .default, fontSize: CGFloat = 14) {
        self.theme = theme
        self.fontSize = fontSize
    }

    /// Highlights code and returns an AttributedString
    func highlight(_ code: String, language: String) -> AttributedString {
        let lang = Language(rawValue: language.lowercased()) ?? .plainText

        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        // Apply syntax highlighting based on language
        switch lang {
        case .swift:
            result = highlightSwift(code)
        case .python:
            result = highlightPython(code)
        case .javascript, .typescript:
            result = highlightJavaScript(code)
        case .html:
            result = highlightHTML(code)
        case .css:
            result = highlightCSS(code)
        case .json:
            result = highlightJSON(code)
        case .rust:
            result = highlightRust(code)
        case .go:
            result = highlightGo(code)
        case .java, .kotlin:
            result = highlightJava(code)
        case .c, .cpp, .objectivec:
            result = highlightC(code)
        case .ruby:
            result = highlightRuby(code)
        case .php:
            result = highlightPHP(code)
        case .sql:
            result = highlightSQL(code)
        case .bash, .shell, .zsh:
            result = highlightBash(code)
        case .yaml:
            result = highlightYAML(code)
        case .markdown:
            result = highlightMarkdown(code)
        case .plainText:
            break
        }

        return result
    }

    // MARK: - Swift Highlighting

    private func highlightSwift(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        let keywords = [
            "import", "class", "struct", "enum", "protocol", "extension", "func", "var", "let",
            "if", "else", "guard", "switch", "case", "default", "for", "while", "repeat",
            "return", "throw", "throws", "try", "catch", "do", "break", "continue", "fallthrough",
            "where", "in", "as", "is", "nil", "true", "false", "self", "Self", "super",
            "init", "deinit", "get", "set", "willSet", "didSet", "subscript", "static",
            "private", "fileprivate", "internal", "public", "open", "final", "override",
            "mutating", "nonmutating", "lazy", "weak", "unowned", "inout", "some", "any",
            "async", "await", "actor", "nonisolated", "isolated", "@main", "@State",
            "@Binding", "@Published", "@ObservedObject", "@StateObject", "@Environment",
            "@EnvironmentObject", "@ViewBuilder", "@escaping", "@autoclosure", "@available",
            "typealias", "associatedtype", "precedencegroup", "operator", "infix", "prefix", "postfix"
        ]

        let types = [
            "String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set",
            "Optional", "Result", "Error", "Void", "Any", "AnyObject", "Never",
            "View", "Text", "Button", "Image", "VStack", "HStack", "ZStack", "List",
            "NavigationView", "NavigationStack", "ScrollView", "ForEach", "Group",
            "Color", "Font", "CGFloat", "CGPoint", "CGSize", "CGRect", "UUID", "Date", "URL",
            "Data", "Codable", "Encodable", "Decodable", "Hashable", "Equatable", "Comparable",
            "Identifiable", "ObservableObject", "Publisher", "Subscriber"
        ]

        // Apply patterns
        result = applyPattern(to: result, code: code, pattern: #"//.*$"#, color: theme.comment, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"/\*[\s\S]*?\*/"#, color: theme.comment)
        result = applyPattern(to: result, code: code, pattern: #"\"(?:[^\"\\]|\\.)*\""#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"\"\"\"[\s\S]*?\"\"\""#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: ##"#".*?"#"##, color: theme.string)
        result = applyKeywords(to: result, code: code, keywords: keywords, color: theme.keyword)
        result = applyKeywords(to: result, code: code, keywords: types, color: theme.type)
        result = applyPattern(to: result, code: code, pattern: #"\b\d+\.?\d*\b"#, color: theme.number)
        result = applyPattern(to: result, code: code, pattern: #"@\w+"#, color: theme.attribute)
        result = applyPattern(to: result, code: code, pattern: #"\b[A-Z][a-zA-Z0-9]*\b"#, color: theme.type)
        result = applyPattern(to: result, code: code, pattern: #"\b\w+(?=\s*\()"#, color: theme.function)

        return result
    }

    // MARK: - Python Highlighting

    private func highlightPython(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        let keywords = [
            "and", "as", "assert", "async", "await", "break", "class", "continue",
            "def", "del", "elif", "else", "except", "finally", "for", "from",
            "global", "if", "import", "in", "is", "lambda", "nonlocal", "not",
            "or", "pass", "raise", "return", "try", "while", "with", "yield",
            "True", "False", "None", "self", "cls"
        ]

        let builtins = [
            "print", "len", "range", "str", "int", "float", "bool", "list", "dict",
            "set", "tuple", "type", "isinstance", "hasattr", "getattr", "setattr",
            "open", "input", "map", "filter", "zip", "enumerate", "sorted", "reversed",
            "sum", "min", "max", "abs", "round", "pow", "divmod", "hex", "oct", "bin",
            "ord", "chr", "repr", "format", "id", "hash", "callable", "iter", "next",
            "super", "property", "classmethod", "staticmethod", "Exception", "ValueError",
            "TypeError", "KeyError", "IndexError", "AttributeError", "ImportError"
        ]

        result = applyPattern(to: result, code: code, pattern: #"#.*$"#, color: theme.comment, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"\"\"\"[\s\S]*?\"\"\""#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"'''[\s\S]*?'''"#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"\"(?:[^\"\\]|\\.)*\""#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"'(?:[^'\\]|\\.)*'"#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"f\"[^\"]*\""#, color: theme.string)
        result = applyKeywords(to: result, code: code, keywords: keywords, color: theme.keyword)
        result = applyKeywords(to: result, code: code, keywords: builtins, color: theme.function)
        result = applyPattern(to: result, code: code, pattern: #"\b\d+\.?\d*\b"#, color: theme.number)
        result = applyPattern(to: result, code: code, pattern: #"@\w+"#, color: theme.attribute)
        result = applyPattern(to: result, code: code, pattern: #"\b\w+(?=\s*\()"#, color: theme.function)

        return result
    }

    // MARK: - JavaScript/TypeScript Highlighting

    private func highlightJavaScript(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        let keywords = [
            "async", "await", "break", "case", "catch", "class", "const", "continue",
            "debugger", "default", "delete", "do", "else", "export", "extends", "finally",
            "for", "function", "if", "import", "in", "instanceof", "let", "new", "of",
            "return", "static", "super", "switch", "this", "throw", "try", "typeof",
            "var", "void", "while", "with", "yield", "true", "false", "null", "undefined",
            "interface", "type", "enum", "implements", "private", "protected", "public",
            "readonly", "abstract", "as", "from", "get", "set", "constructor"
        ]

        let builtins = [
            "console", "document", "window", "Math", "JSON", "Array", "Object", "String",
            "Number", "Boolean", "Date", "RegExp", "Error", "Promise", "Map", "Set",
            "WeakMap", "WeakSet", "Symbol", "Proxy", "Reflect", "parseInt", "parseFloat",
            "isNaN", "isFinite", "encodeURI", "decodeURI", "setTimeout", "setInterval",
            "clearTimeout", "clearInterval", "fetch", "require", "module", "exports"
        ]

        result = applyPattern(to: result, code: code, pattern: #"//.*$"#, color: theme.comment, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"/\*[\s\S]*?\*/"#, color: theme.comment)
        result = applyPattern(to: result, code: code, pattern: #"`(?:[^`\\]|\\.)*`"#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"\"(?:[^\"\\]|\\.)*\""#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"'(?:[^'\\]|\\.)*'"#, color: theme.string)
        result = applyKeywords(to: result, code: code, keywords: keywords, color: theme.keyword)
        result = applyKeywords(to: result, code: code, keywords: builtins, color: theme.type)
        result = applyPattern(to: result, code: code, pattern: #"\b\d+\.?\d*\b"#, color: theme.number)
        result = applyPattern(to: result, code: code, pattern: #"\b\w+(?=\s*\()"#, color: theme.function)
        result = applyPattern(to: result, code: code, pattern: #"=>"#, color: theme.keyword)

        return result
    }

    // MARK: - HTML Highlighting

    private func highlightHTML(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        result = applyPattern(to: result, code: code, pattern: #"<!--[\s\S]*?-->"#, color: theme.comment)
        result = applyPattern(to: result, code: code, pattern: #"</?[a-zA-Z][a-zA-Z0-9]*"#, color: theme.keyword)
        result = applyPattern(to: result, code: code, pattern: #"/?\s*>"#, color: theme.keyword)
        result = applyPattern(to: result, code: code, pattern: #"\b[a-zA-Z-]+(?=\s*=)"#, color: theme.attribute)
        result = applyPattern(to: result, code: code, pattern: #"\"[^\"]*\""#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"'[^']*'"#, color: theme.string)

        return result
    }

    // MARK: - CSS Highlighting

    private func highlightCSS(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        result = applyPattern(to: result, code: code, pattern: #"/\*[\s\S]*?\*/"#, color: theme.comment)
        result = applyPattern(to: result, code: code, pattern: #"[.#]?[a-zA-Z_-][a-zA-Z0-9_-]*(?=\s*\{)"#, color: theme.type)
        result = applyPattern(to: result, code: code, pattern: #"[a-zA-Z-]+(?=\s*:)"#, color: theme.attribute)
        result = applyPattern(to: result, code: code, pattern: #"#[0-9a-fA-F]{3,8}\b"#, color: theme.number)
        result = applyPattern(to: result, code: code, pattern: #"\b\d+\.?\d*(px|em|rem|%|vh|vw|s|ms)?\b"#, color: theme.number)
        result = applyPattern(to: result, code: code, pattern: #"\"[^\"]*\""#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"'[^']*'"#, color: theme.string)

        return result
    }

    // MARK: - JSON Highlighting

    private func highlightJSON(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        result = applyPattern(to: result, code: code, pattern: #"\"[^\"]*\"(?=\s*:)"#, color: theme.attribute)
        result = applyPattern(to: result, code: code, pattern: #":\s*\"[^\"]*\""#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"\b(true|false|null)\b"#, color: theme.keyword)
        result = applyPattern(to: result, code: code, pattern: #"-?\b\d+\.?\d*([eE][+-]?\d+)?\b"#, color: theme.number)

        return result
    }

    // MARK: - Rust Highlighting

    private func highlightRust(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        let keywords = [
            "as", "async", "await", "break", "const", "continue", "crate", "dyn",
            "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in",
            "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return",
            "self", "Self", "static", "struct", "super", "trait", "true", "type",
            "unsafe", "use", "where", "while", "macro_rules"
        ]

        let types = [
            "i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64",
            "u128", "usize", "f32", "f64", "bool", "char", "str", "String", "Vec",
            "Option", "Result", "Box", "Rc", "Arc", "Cell", "RefCell", "HashMap",
            "HashSet", "BTreeMap", "BTreeSet", "Mutex", "RwLock"
        ]

        result = applyPattern(to: result, code: code, pattern: #"//.*$"#, color: theme.comment, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"/\*[\s\S]*?\*/"#, color: theme.comment)
        result = applyPattern(to: result, code: code, pattern: #"\"(?:[^\"\\]|\\.)*\""#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: ##"r#*"[\s\S]*?"#*"##, color: theme.string)
        result = applyKeywords(to: result, code: code, keywords: keywords, color: theme.keyword)
        result = applyKeywords(to: result, code: code, keywords: types, color: theme.type)
        result = applyPattern(to: result, code: code, pattern: #"\b\d+\.?\d*\b"#, color: theme.number)
        result = applyPattern(to: result, code: code, pattern: #"#\[.*?\]"#, color: theme.attribute)
        result = applyPattern(to: result, code: code, pattern: #"\b\w+!"#, color: theme.function)
        result = applyPattern(to: result, code: code, pattern: #"\b\w+(?=\s*\()"#, color: theme.function)

        return result
    }

    // MARK: - Go Highlighting

    private func highlightGo(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        let keywords = [
            "break", "case", "chan", "const", "continue", "default", "defer", "else",
            "fallthrough", "for", "func", "go", "goto", "if", "import", "interface",
            "map", "package", "range", "return", "select", "struct", "switch", "type",
            "var", "true", "false", "nil", "iota"
        ]

        let types = [
            "bool", "byte", "complex64", "complex128", "error", "float32", "float64",
            "int", "int8", "int16", "int32", "int64", "rune", "string", "uint",
            "uint8", "uint16", "uint32", "uint64", "uintptr"
        ]

        let builtins = [
            "append", "cap", "close", "complex", "copy", "delete", "imag", "len",
            "make", "new", "panic", "print", "println", "real", "recover"
        ]

        result = applyPattern(to: result, code: code, pattern: #"//.*$"#, color: theme.comment, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"/\*[\s\S]*?\*/"#, color: theme.comment)
        result = applyPattern(to: result, code: code, pattern: #"\"(?:[^\"\\]|\\.)*\""#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"`[^`]*`"#, color: theme.string)
        result = applyKeywords(to: result, code: code, keywords: keywords, color: theme.keyword)
        result = applyKeywords(to: result, code: code, keywords: types, color: theme.type)
        result = applyKeywords(to: result, code: code, keywords: builtins, color: theme.function)
        result = applyPattern(to: result, code: code, pattern: #"\b\d+\.?\d*\b"#, color: theme.number)
        result = applyPattern(to: result, code: code, pattern: #"\b\w+(?=\s*\()"#, color: theme.function)

        return result
    }

    // MARK: - Java/Kotlin Highlighting

    private func highlightJava(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        let keywords = [
            "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char",
            "class", "const", "continue", "default", "do", "double", "else", "enum",
            "extends", "final", "finally", "float", "for", "goto", "if", "implements",
            "import", "instanceof", "int", "interface", "long", "native", "new",
            "package", "private", "protected", "public", "return", "short", "static",
            "strictfp", "super", "switch", "synchronized", "this", "throw", "throws",
            "transient", "try", "void", "volatile", "while", "true", "false", "null",
            "var", "val", "fun", "when", "object", "companion", "data", "sealed",
            "suspend", "inline", "crossinline", "noinline", "reified", "override", "open"
        ]

        result = applyPattern(to: result, code: code, pattern: #"//.*$"#, color: theme.comment, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"/\*[\s\S]*?\*/"#, color: theme.comment)
        result = applyPattern(to: result, code: code, pattern: #"\"(?:[^\"\\]|\\.)*\""#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"'(?:[^'\\]|\\.)*'"#, color: theme.string)
        result = applyKeywords(to: result, code: code, keywords: keywords, color: theme.keyword)
        result = applyPattern(to: result, code: code, pattern: #"\b\d+\.?\d*[fFdDlL]?\b"#, color: theme.number)
        result = applyPattern(to: result, code: code, pattern: #"@\w+"#, color: theme.attribute)
        result = applyPattern(to: result, code: code, pattern: #"\b[A-Z][a-zA-Z0-9]*\b"#, color: theme.type)
        result = applyPattern(to: result, code: code, pattern: #"\b\w+(?=\s*\()"#, color: theme.function)

        return result
    }

    // MARK: - C/C++/Objective-C Highlighting

    private func highlightC(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        let keywords = [
            "auto", "break", "case", "char", "const", "continue", "default", "do",
            "double", "else", "enum", "extern", "float", "for", "goto", "if", "inline",
            "int", "long", "register", "restrict", "return", "short", "signed", "sizeof",
            "static", "struct", "switch", "typedef", "union", "unsigned", "void",
            "volatile", "while", "_Bool", "_Complex", "_Imaginary",
            "class", "public", "private", "protected", "virtual", "override", "final",
            "namespace", "using", "template", "typename", "new", "delete", "this",
            "try", "catch", "throw", "nullptr", "true", "false", "constexpr", "noexcept",
            "@interface", "@implementation", "@end", "@property", "@synthesize",
            "@protocol", "@optional", "@required", "@class", "@selector", "@encode",
            "nil", "Nil", "YES", "NO", "self", "super", "id", "instancetype",
            "#include", "#import", "#define", "#ifdef", "#ifndef", "#endif", "#pragma"
        ]

        result = applyPattern(to: result, code: code, pattern: #"//.*$"#, color: theme.comment, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"/\*[\s\S]*?\*/"#, color: theme.comment)
        result = applyPattern(to: result, code: code, pattern: #"\"(?:[^\"\\]|\\.)*\""#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"<[a-zA-Z0-9_./]+>"#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"@\"(?:[^\"\\]|\\.)*\""#, color: theme.string)
        result = applyKeywords(to: result, code: code, keywords: keywords, color: theme.keyword)
        result = applyPattern(to: result, code: code, pattern: #"\b\d+\.?\d*[fFlLuU]*\b"#, color: theme.number)
        result = applyPattern(to: result, code: code, pattern: #"0x[0-9a-fA-F]+\b"#, color: theme.number)
        result = applyPattern(to: result, code: code, pattern: #"\b\w+(?=\s*\()"#, color: theme.function)

        return result
    }

    // MARK: - Ruby Highlighting

    private func highlightRuby(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        let keywords = [
            "alias", "and", "begin", "break", "case", "class", "def", "defined?",
            "do", "else", "elsif", "end", "ensure", "false", "for", "if", "in",
            "module", "next", "nil", "not", "or", "redo", "rescue", "retry",
            "return", "self", "super", "then", "true", "undef", "unless", "until",
            "when", "while", "yield", "require", "require_relative", "include",
            "extend", "attr_reader", "attr_writer", "attr_accessor", "private",
            "protected", "public", "raise", "lambda", "proc"
        ]

        result = applyPattern(to: result, code: code, pattern: #"#.*$"#, color: theme.comment, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"=begin[\s\S]*?=end"#, color: theme.comment)
        result = applyPattern(to: result, code: code, pattern: #"\"(?:[^\"\\]|\\.)*\""#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"'(?:[^'\\]|\\.)*'"#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #":\w+"#, color: theme.string)
        result = applyKeywords(to: result, code: code, keywords: keywords, color: theme.keyword)
        result = applyPattern(to: result, code: code, pattern: #"\b\d+\.?\d*\b"#, color: theme.number)
        result = applyPattern(to: result, code: code, pattern: #"@{1,2}\w+"#, color: theme.attribute)
        result = applyPattern(to: result, code: code, pattern: #"\$\w+"#, color: theme.attribute)
        result = applyPattern(to: result, code: code, pattern: #"\b[A-Z][a-zA-Z0-9]*\b"#, color: theme.type)
        result = applyPattern(to: result, code: code, pattern: #"\b\w+[?!]?\s*(?=\(|do|\{)"#, color: theme.function)

        return result
    }

    // MARK: - PHP Highlighting

    private func highlightPHP(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        let keywords = [
            "abstract", "and", "array", "as", "break", "callable", "case", "catch",
            "class", "clone", "const", "continue", "declare", "default", "die", "do",
            "echo", "else", "elseif", "empty", "enddeclare", "endfor", "endforeach",
            "endif", "endswitch", "endwhile", "eval", "exit", "extends", "final",
            "finally", "fn", "for", "foreach", "function", "global", "goto", "if",
            "implements", "include", "include_once", "instanceof", "insteadof",
            "interface", "isset", "list", "match", "namespace", "new", "or", "print",
            "private", "protected", "public", "readonly", "require", "require_once",
            "return", "static", "switch", "throw", "trait", "try", "unset", "use",
            "var", "while", "xor", "yield", "true", "false", "null"
        ]

        result = applyPattern(to: result, code: code, pattern: #"//.*$"#, color: theme.comment, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"#.*$"#, color: theme.comment, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"/\*[\s\S]*?\*/"#, color: theme.comment)
        result = applyPattern(to: result, code: code, pattern: #"\"(?:[^\"\\]|\\.)*\""#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"'(?:[^'\\]|\\.)*'"#, color: theme.string)
        result = applyKeywords(to: result, code: code, keywords: keywords, color: theme.keyword)
        result = applyPattern(to: result, code: code, pattern: #"\$\w+"#, color: theme.attribute)
        result = applyPattern(to: result, code: code, pattern: #"\b\d+\.?\d*\b"#, color: theme.number)
        result = applyPattern(to: result, code: code, pattern: #"\b\w+(?=\s*\()"#, color: theme.function)

        return result
    }

    // MARK: - SQL Highlighting

    private func highlightSQL(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        let keywords = [
            "SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "IN", "LIKE", "BETWEEN",
            "IS", "NULL", "AS", "ON", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER",
            "FULL", "CROSS", "UNION", "ALL", "DISTINCT", "ORDER", "BY", "ASC", "DESC",
            "GROUP", "HAVING", "LIMIT", "OFFSET", "INSERT", "INTO", "VALUES", "UPDATE",
            "SET", "DELETE", "CREATE", "TABLE", "DROP", "ALTER", "ADD", "COLUMN",
            "INDEX", "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "CONSTRAINT", "CHECK",
            "DEFAULT", "UNIQUE", "CASCADE", "RESTRICT", "DATABASE", "SCHEMA", "VIEW",
            "FUNCTION", "PROCEDURE", "TRIGGER", "IF", "ELSE", "CASE", "WHEN", "THEN",
            "END", "BEGIN", "COMMIT", "ROLLBACK", "TRANSACTION", "EXISTS", "COUNT",
            "SUM", "AVG", "MIN", "MAX", "COALESCE", "NULLIF", "CAST", "CONVERT",
            "TRUE", "FALSE"
        ]

        let types = [
            "INT", "INTEGER", "BIGINT", "SMALLINT", "TINYINT", "FLOAT", "DOUBLE",
            "DECIMAL", "NUMERIC", "VARCHAR", "CHAR", "TEXT", "BLOB", "DATE", "TIME",
            "DATETIME", "TIMESTAMP", "BOOLEAN", "BOOL", "SERIAL", "UUID"
        ]

        result = applyPattern(to: result, code: code, pattern: #"--.*$"#, color: theme.comment, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"/\*[\s\S]*?\*/"#, color: theme.comment)
        result = applyPattern(to: result, code: code, pattern: #"'(?:[^'\\]|\\.)*'"#, color: theme.string)
        result = applyKeywords(to: result, code: code, keywords: keywords, color: theme.keyword, caseInsensitive: true)
        result = applyKeywords(to: result, code: code, keywords: types, color: theme.type, caseInsensitive: true)
        result = applyPattern(to: result, code: code, pattern: #"\b\d+\.?\d*\b"#, color: theme.number)

        return result
    }

    // MARK: - Bash/Shell Highlighting

    private func highlightBash(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        let keywords = [
            "if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case",
            "esac", "in", "function", "return", "local", "export", "unset", "readonly",
            "declare", "typeset", "source", "alias", "unalias", "break", "continue",
            "exit", "trap", "shift", "eval", "exec", "set", "true", "false"
        ]

        let builtins = [
            "echo", "printf", "read", "cd", "pwd", "ls", "cp", "mv", "rm", "mkdir",
            "rmdir", "touch", "cat", "grep", "sed", "awk", "find", "xargs", "sort",
            "uniq", "wc", "head", "tail", "cut", "paste", "tr", "tee", "chmod",
            "chown", "sudo", "su", "ssh", "scp", "curl", "wget", "tar", "gzip",
            "gunzip", "zip", "unzip", "git", "docker", "npm", "yarn", "pip", "python"
        ]

        result = applyPattern(to: result, code: code, pattern: #"#.*$"#, color: theme.comment, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"\"(?:[^\"\\]|\\.)*\""#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"'[^']*'"#, color: theme.string)
        result = applyKeywords(to: result, code: code, keywords: keywords, color: theme.keyword)
        result = applyKeywords(to: result, code: code, keywords: builtins, color: theme.function)
        result = applyPattern(to: result, code: code, pattern: #"\$\{?[a-zA-Z_][a-zA-Z0-9_]*\}?"#, color: theme.attribute)
        result = applyPattern(to: result, code: code, pattern: #"\b\d+\b"#, color: theme.number)

        return result
    }

    // MARK: - YAML Highlighting

    private func highlightYAML(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        result = applyPattern(to: result, code: code, pattern: #"#.*$"#, color: theme.comment, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"^[a-zA-Z_][a-zA-Z0-9_-]*(?=\s*:)"#, color: theme.attribute, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"\"(?:[^\"\\]|\\.)*\""#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"'[^']*'"#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"\b(true|false|yes|no|null|~)\b"#, color: theme.keyword)
        result = applyPattern(to: result, code: code, pattern: #"\b\d+\.?\d*\b"#, color: theme.number)
        result = applyPattern(to: result, code: code, pattern: #"^\s*-\s"#, color: theme.keyword, options: .anchorsMatchLines)

        return result
    }

    // MARK: - Markdown Highlighting

    private func highlightMarkdown(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        result.font = .system(size: fontSize, design: .monospaced)
        result.foregroundColor = theme.text

        result = applyPattern(to: result, code: code, pattern: #"^#{1,6}\s+.*$"#, color: theme.keyword, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"\*\*[^*]+\*\*"#, color: theme.keyword)
        result = applyPattern(to: result, code: code, pattern: #"\*[^*]+\*"#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"__[^_]+__"#, color: theme.keyword)
        result = applyPattern(to: result, code: code, pattern: #"_[^_]+_"#, color: theme.string)
        result = applyPattern(to: result, code: code, pattern: #"`[^`]+`"#, color: theme.function)
        result = applyPattern(to: result, code: code, pattern: #"\[[^\]]+\]\([^)]+\)"#, color: theme.attribute)
        result = applyPattern(to: result, code: code, pattern: #"^\s*[-*+]\s"#, color: theme.type, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"^\s*\d+\.\s"#, color: theme.type, options: .anchorsMatchLines)
        result = applyPattern(to: result, code: code, pattern: #"^>\s.*$"#, color: theme.comment, options: .anchorsMatchLines)

        return result
    }

    // MARK: - Helper Methods

    private func applyPattern(
        to attributed: AttributedString,
        code: String,
        pattern: String,
        color: Color,
        options: NSRegularExpression.Options = []
    ) -> AttributedString {
        var result = attributed

        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return result
        }

        let matches = regex.matches(in: code, range: NSRange(code.startIndex..., in: code))

        for match in matches.reversed() {
            if let range = Range(match.range, in: code) {
                let matchedText = String(code[range])
                if let attrRange = result.range(of: matchedText) {
                    result[attrRange].foregroundColor = color
                }
            }
        }

        return result
    }

    private func applyKeywords(
        to attributed: AttributedString,
        code: String,
        keywords: [String],
        color: Color,
        caseInsensitive: Bool = false
    ) -> AttributedString {
        var result = attributed

        for keyword in keywords {
            let pattern = caseInsensitive ? #"\b\#(keyword)\b"# : #"\b"# + NSRegularExpression.escapedPattern(for: keyword) + #"\b"#
            let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []

            if let regex = try? NSRegularExpression(pattern: pattern, options: options) {
                let matches = regex.matches(in: code, range: NSRange(code.startIndex..., in: code))

                for match in matches {
                    if let range = Range(match.range, in: code) {
                        let matchedText = String(code[range])
                        if let attrRange = result.range(of: matchedText) {
                            result[attrRange].foregroundColor = color
                        }
                    }
                }
            }
        }

        return result
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
