//
//  CodeBlockData.swift
//  TextEditor
//
//  Represents a syntax-highlighted code block.
//

import Foundation
import SwiftData

@Model
class CodeBlockData {
    var id: UUID
    var code: String
    var languageString: String
    var showLineNumbers: Bool
    var themeString: String

    var language: Language {
        get { Language(rawValue: languageString) ?? .plainText }
        set { languageString = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        code: String = "",
        language: Language = .swift,
        showLineNumbers: Bool = true,
        theme: String = "default"
    ) {
        self.id = id
        self.code = code
        self.languageString = language.rawValue
        self.showLineNumbers = showLineNumbers
        self.themeString = theme
    }
}
