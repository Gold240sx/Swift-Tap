import Foundation
import SwiftData

/// Represents a folder for organizing documents
@Model
final class Folder {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Folder name
    var name: String

    /// SF Symbol icon name
    var icon: String

    /// Color for the folder (stored as hex string)
    var colorHex: String

    /// Sort order for manual ordering
    var sortOrder: Int

    /// Creation timestamp
    var createdAt: Date

    /// Parent folder for nested organization
    var parent: Folder?

    /// Child folders
    @Relationship(deleteRule: .cascade, inverse: \Folder.parent)
    var children: [Folder]

    /// Documents in this folder
    @Relationship(deleteRule: .nullify, inverse: \Document.folder)
    var documents: [Document]

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder",
        colorHex: String = "#007AFF",
        sortOrder: Int = 0,
        parent: Folder? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.parent = parent
        self.children = []
        self.documents = []
    }

    /// Returns the full path of the folder (e.g., "Parent/Child/Grandchild")
    var fullPath: String {
        var path = [name]
        var current = parent
        while let p = current {
            path.insert(p.name, at: 0)
            current = p.parent
        }
        return path.joined(separator: "/")
    }

    /// Returns the depth level (0 for root folders)
    var depth: Int {
        var level = 0
        var current = parent
        while current != nil {
            level += 1
            current = current?.parent
        }
        return level
    }

    /// Total document count including subfolders
    var totalDocumentCount: Int {
        var count = documents.count
        for child in children {
            count += child.totalDocumentCount
        }
        return count
    }

    /// Active (non-trashed) document count
    var activeDocumentCount: Int {
        var count = documents.filter { !$0.isTrash }.count
        for child in children {
            count += child.activeDocumentCount
        }
        return count
    }
}

// MARK: - Folder Color Helpers

extension Folder {
    /// Predefined folder colors
    static let colorOptions: [(name: String, hex: String)] = [
        ("Blue", "#007AFF"),
        ("Purple", "#AF52DE"),
        ("Pink", "#FF2D55"),
        ("Red", "#FF3B30"),
        ("Orange", "#FF9500"),
        ("Yellow", "#FFCC00"),
        ("Green", "#34C759"),
        ("Teal", "#5AC8FA"),
        ("Gray", "#8E8E93")
    ]

    /// Predefined folder icons
    static let iconOptions: [String] = [
        "folder",
        "folder.fill",
        "doc.text",
        "book",
        "bookmark",
        "star",
        "heart",
        "flag",
        "tag",
        "archivebox",
        "tray.full",
        "briefcase",
        "house",
        "building.2",
        "graduationcap",
        "lightbulb",
        "gearshape",
        "wrench.and.screwdriver",
        "hammer",
        "paintbrush",
        "pencil",
        "scissors",
        "paperclip",
        "link",
        "globe",
        "airplane",
        "car",
        "leaf",
        "flame",
        "bolt"
    ]
}
