//
//  NoteBlock.swift
//  TextEditor
//
//  Represents a single block of content (Text or Table) in a Note.
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
    
    var typeString: String
    
    enum BlockType: String, Codable {
        case text, table
    }
    
    var type: BlockType {
        get { BlockType(rawValue: typeString) ?? .text }
        set { typeString = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), orderIndex: Int, text: AttributedString? = nil, table: TableData? = nil, type: BlockType = .text) {
        self.id = id
        self.orderIndex = orderIndex
        self.text = text
        self.table = table
        self.typeString = type.rawValue
    }
}
