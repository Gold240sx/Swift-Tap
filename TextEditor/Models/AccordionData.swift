//
//  AccordionData.swift
//  TextEditor
//
//  Represents an expandable/collapsible accordion block.
//  Supports nested blocks (text, tables, accordions) within its content.
//

import Foundation
import SwiftData

@Model
class AccordionData {
    var id: UUID
    var heading: AttributedString
    var isExpanded: Bool
    var levelString: String

    /// Nested blocks inside this accordion (can contain text, tables, or other accordions)
    @Relationship(deleteRule: .cascade, inverse: \NoteBlock.parentAccordion)
    var contentBlocks: [NoteBlock] = []

    enum HeadingLevel: String, Codable {
        case h1, h2, h3
    }

    var level: HeadingLevel {
        get { HeadingLevel(rawValue: levelString) ?? .h1 }
        set { levelString = newValue.rawValue }
    }

    init(id: UUID = UUID(), heading: AttributedString = "", isExpanded: Bool = true, level: HeadingLevel = .h1) {
        self.id = id
        self.heading = heading
        self.isExpanded = isExpanded
        self.levelString = level.rawValue
    }
}
