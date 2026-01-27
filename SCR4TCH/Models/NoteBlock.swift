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
    var id: UUID?
    var orderIndex: Int?
    var textData: Data?
    
    var text: AttributedString? {
        get {
            guard let data = textData else { return nil }
            return (try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data))
                .map(AttributedString.init)
        }
        set {
            if let newValue = newValue {
                let nsAttr = NSAttributedString(newValue)
                textData = try? NSKeyedArchiver.archivedData(withRootObject: nsAttr, requiringSecureCoding: false)
            } else {
                textData = nil
            }
        }
    }
    
    var note: RichTextNote?

    @Relationship(deleteRule: .cascade, inverse: \TableData.noteBlock)
    var table: TableData?

    @Relationship(deleteRule: .cascade, inverse: \AccordionData.noteBlock)
    var accordion: AccordionData?

    @Relationship(deleteRule: .cascade, inverse: \CodeBlockData.noteBlock)
    var codeBlock: CodeBlockData?

    @Relationship(deleteRule: .cascade, inverse: \ImageData.noteBlock)
    var imageData: ImageData?

    @Relationship(deleteRule: .cascade, inverse: \ColumnData.noteBlock)
    var columnData: ColumnData?

    @Relationship(deleteRule: .cascade, inverse: \ListData.noteBlock)
    var listData: ListData?

    @Relationship(deleteRule: .cascade, inverse: \BookmarkData.noteBlock)
    var bookmarkData: BookmarkData?

    @Relationship(deleteRule: .cascade, inverse: \FilePathData.noteBlock)
    var filePathData: FilePathData?

    @Relationship(deleteRule: .cascade, inverse: \ReminderData.noteBlock)
    var reminderData: ReminderData?

    /// If this block is nested inside an accordion, this points to the parent accordion
    var parentAccordion: AccordionData?

    /// If this block is nested inside a column, this points to the parent column
    var parentColumn: Column?

    var typeString: String?

    enum BlockType: String, Codable {
        case text, table, accordion, code, image, columns, list, quote, bookmark, filePath, reminder
    }

    var type: BlockType {
        get { BlockType(rawValue: typeString ?? "text") ?? .text }
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
        case .reminder: return "Reminder"
        }
    }

    init(id: UUID = UUID(), orderIndex: Int, text: AttributedString? = nil, table: TableData? = nil, accordion: AccordionData? = nil, codeBlock: CodeBlockData? = nil, imageData: ImageData? = nil, columnData: ColumnData? = nil, listData: ListData? = nil, bookmarkData: BookmarkData? = nil, filePathData: FilePathData? = nil, reminderData: ReminderData? = nil, type: BlockType = .text) {
        self.id = id
        self.orderIndex = orderIndex
        
        if let text = text {
            let nsAttr = NSAttributedString(text)
            self.textData = try? NSKeyedArchiver.archivedData(withRootObject: nsAttr, requiringSecureCoding: false)
        }
        
        self.table = table
        self.accordion = accordion
        self.codeBlock = codeBlock
        self.imageData = imageData
        self.columnData = columnData
        self.listData = listData
        self.bookmarkData = bookmarkData
        self.filePathData = filePathData
        self.reminderData = reminderData
        self.typeString = type.rawValue
    }
}
