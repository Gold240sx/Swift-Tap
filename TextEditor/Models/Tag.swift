//
//  Tag.swift
//  TextEditor
//
//  Tag model for organizing notes
//

import Foundation
import SwiftData

@Model
class Tag {
    @Attribute(.unique)
    var name: String
    var hexColor: String
    
    @Relationship(deleteRule: .nullify)
    var notes: [RichTextNote] = []
    
    init(name: String, hexColor: String = "007AFF") {
        self.name = name
        self.hexColor = hexColor
    }
}
