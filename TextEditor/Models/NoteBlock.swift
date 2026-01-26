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

    @Relationship(deleteRule: .cascade)
    var bookmarkData: BookmarkData?

    @Relationship(deleteRule: .cascade)
    var filePathData: FilePathData?

    /// If this block is nested inside an accordion, this points to the parent accordion
    var parentAccordion: AccordionData?

    /// If this block is nested inside a column, this points to the parent column
    var parentColumn: Column?

    var typeString: String

    enum BlockType: String, Codable {
        case text, table, accordion, code, image, columns, list, quote, bookmark, filePath
    }

    var type: BlockType {
        get { BlockType(rawValue: typeString) ?? .text }
        set { typeString = newValue.rawValue }
    }

    var displayName: String {
        switch type {
        case .text: return "Text Block"
        case .table: return "Table"
        case .accordion: return "Accordion"
        case .code: return "Code Block"
        case .image: return "Image"
        case .columns: return "Columns"
        case .list:
            if let listData = listData {
                switch listData.listType {
                case .bullet: return "Bullet List"
                case .numbered: return "Numbered List"
                case .checkbox: return "Checkbox List"
                }
            }
            return "List"
        case .quote: return "Quote"
        case .bookmark: return "Bookmark"
        case .filePath: return "File Link"
        }
    }

    init(id: UUID = UUID(), orderIndex: Int, text: AttributedString? = nil, table: TableData? = nil, accordion: AccordionData? = nil, codeBlock: CodeBlockData? = nil, imageData: ImageData? = nil, columnData: ColumnData? = nil, listData: ListData? = nil, bookmarkData: BookmarkData? = nil, filePathData: FilePathData? = nil, type: BlockType = .text) {
        self.id = id
        self.orderIndex = orderIndex
        self.text = text
        self.table = table
        self.accordion = accordion
        self.codeBlock = codeBlock
        self.imageData = imageData
        self.columnData = columnData
        self.listData = listData
        self.bookmarkData = bookmarkData
        self.filePathData = filePathData
        self.typeString = type.rawValue
    }
}
