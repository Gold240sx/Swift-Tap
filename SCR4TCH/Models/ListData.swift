//
//  ListData.swift
//  TextEditor
//
//  Represents a list block containing multiple list items.
//  Supports bullet lists, numbered lists, and checkbox lists.
//

import Foundation
import SwiftData

@Model
class ListItem {
    var id: UUID?
    var orderIndex: Int?
    var textData: Data?
    var isChecked: Bool?
    
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

    var parentList: ListData?

    init(id: UUID = UUID(), orderIndex: Int, text: AttributedString? = nil, isChecked: Bool = false) {
        self.id = id
        self.orderIndex = orderIndex
        
        if let text = text {
            let nsAttr = NSAttributedString(text)
            self.textData = try? NSKeyedArchiver.archivedData(withRootObject: nsAttr, requiringSecureCoding: false)
        }
        
        self.isChecked = isChecked
    }
}

@Model
class ListData {
    var id: UUID?
    var title: String?
    var listTypeString: String?
    
    var noteBlock: NoteBlock?

    @Relationship(deleteRule: .cascade, inverse: \ListItem.parentList)
    var items: [ListItem]? = []

    enum ListType: String, Codable {
        case bullet
        case numbered
        case checkbox
    }

    var listType: ListType {
        get { ListType(rawValue: listTypeString ?? "bullet") ?? .bullet }
        set { listTypeString = newValue.rawValue }
    }

    init(id: UUID = UUID(), title: String? = nil, listType: ListType = .bullet) {
        self.id = id
        self.title = title
        self.listTypeString = listType.rawValue
    }
}
