//
//  NoteBlock.swift
//  TextEditor
//
//  Represents a single block of content (Text, Table, Accordion, or Code) in a Note.
//

import Foundation
import SwiftData

@Model
class NoteBlock {
    var id: UUID
    var orderIndex: Int
    var text: AttributedString?

    @Relationship(deleteRule: .cascade)
    var table: TableData?

    @Relationship(deleteRule: .cascade)
    var accordion: AccordionData?

    @Relationship(deleteRule: .cascade)
    var codeBlock: CodeBlockData?

    /// If this block is nested inside an accordion, this points to the parent accordion
    var parentAccordion: AccordionData?

    var typeString: String

    enum BlockType: String, Codable {
        case text, table, accordion, code
    }

    var type: BlockType {
        get { BlockType(rawValue: typeString) ?? .text }
        set { typeString = newValue.rawValue }
    }

    init(id: UUID = UUID(), orderIndex: Int, text: AttributedString? = nil, table: TableData? = nil, accordion: AccordionData? = nil, codeBlock: CodeBlockData? = nil, type: BlockType = .text) {
        self.id = id
        self.orderIndex = orderIndex
        self.text = text
        self.table = table
        self.accordion = accordion
        self.codeBlock = codeBlock
        self.typeString = type.rawValue
    }
}
