//
//  NoteBlock.swift
//  TextEditor
//
//  Represents a single block of content (Text, Table, Accordion, Code, List, etc.) in a Note.
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

    @Relationship(deleteRule: .cascade)
    var imageData: ImageData?

    @Relationship(deleteRule: .cascade)
    var columnData: ColumnData?

    @Relationship(deleteRule: .cascade)
    var listData: ListData?

    /// If this block is nested inside an accordion, this points to the parent accordion
    var parentAccordion: AccordionData?

    /// If this block is nested inside a column, this points to the parent column
    var parentColumn: Column?

    var typeString: String

    enum BlockType: String, Codable {
        case text, table, accordion, code, image, columns, list
    }

    var type: BlockType {
        get { BlockType(rawValue: typeString) ?? .text }
        set { typeString = newValue.rawValue }
    }

    init(id: UUID = UUID(), orderIndex: Int, text: AttributedString? = nil, table: TableData? = nil, accordion: AccordionData? = nil, codeBlock: CodeBlockData? = nil, imageData: ImageData? = nil, columnData: ColumnData? = nil, listData: ListData? = nil, type: BlockType = .text) {
        self.id = id
        self.orderIndex = orderIndex
        self.text = text
        self.table = table
        self.accordion = accordion
        self.codeBlock = codeBlock
        self.imageData = imageData
        self.columnData = columnData
        self.listData = listData
        self.typeString = type.rawValue
    }
}
