import Foundation
import SwiftData

/// Represents a tag for categorizing documents
@Model
final class Tag {
    /// Unique identifier
    @Attribute(.unique) var id: UUID

    /// Tag name (must be unique)
    @Attribute(.unique) var name: String

    /// Color for the tag (stored as hex string)
    var colorHex: String

    /// Creation timestamp
    var createdAt: Date

    /// Documents with this tag
    var documents: [Document]

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#007AFF"
    ) {
        self.id = id
        self.name = name.lowercased().trimmingCharacters(in: .whitespaces)
        self.colorHex = colorHex
        self.createdAt = Date()
        self.documents = []
    }

    /// Number of documents using this tag
    var documentCount: Int {
        documents.filter { !$0.isTrash }.count
    }
}

// MARK: - Tag Color Helpers

extension Tag {
    /// Predefined tag colors
    static let colorOptions: [(name: String, hex: String)] = [
        ("Blue", "#007AFF"),
        ("Indigo", "#5856D6"),
        ("Purple", "#AF52DE"),
        ("Pink", "#FF2D55"),
        ("Red", "#FF3B30"),
        ("Orange", "#FF9500"),
        ("Yellow", "#FFCC00"),
        ("Green", "#34C759"),
        ("Teal", "#5AC8FA"),
        ("Cyan", "#32ADE6"),
        ("Mint", "#00C7BE"),
        ("Gray", "#8E8E93")
    ]

    /// Returns a random color hex from options
    static func randomColorHex() -> String {
        colorOptions.randomElement()?.hex ?? "#007AFF"
    }
}
