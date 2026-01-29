import Foundation
import SwiftData

/// Represents a markdown document stored in the database
@Model
final class Document {
    /// Unique identifier for the document
    @Attribute(.unique) var id: UUID

    /// Document title (extracted from first heading or user-defined)
    var title: String

    /// Raw markdown content
    var content: String

    /// Plain text excerpt for previews (first ~200 chars without markdown)
    var excerpt: String

    /// Word count for statistics
    var wordCount: Int

    /// Character count for statistics
    var characterCount: Int

    /// Creation timestamp
    var createdAt: Date

    /// Last modification timestamp
    var modifiedAt: Date

    /// Last accessed timestamp (for sorting by recent)
    var accessedAt: Date

    /// Whether the document is marked as favorite/pinned
    var isFavorite: Bool

    /// Whether the document is in trash (soft delete)
    var isTrash: Bool

    /// Optional folder relationship
    var folder: Folder?

    /// Tags associated with this document
    @Relationship(deleteRule: .nullify, inverse: \Tag.documents)
    var tags: [Tag]

    /// Document metadata as JSON (extensible for custom properties)
    var metadata: DocumentMetadata

    init(
        id: UUID = UUID(),
        title: String = "Untitled",
        content: String = "",
        folder: Folder? = nil,
        tags: [Tag] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.excerpt = Document.generateExcerpt(from: content)
        self.wordCount = Document.countWords(in: content)
        self.characterCount = content.count
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.accessedAt = Date()
        self.isFavorite = false
        self.isTrash = false
        self.folder = folder
        self.tags = tags
        self.metadata = DocumentMetadata()
    }

    /// Updates the content and recalculates derived fields
    func updateContent(_ newContent: String) {
        content = newContent
        excerpt = Document.generateExcerpt(from: newContent)
        wordCount = Document.countWords(in: newContent)
        characterCount = newContent.count
        modifiedAt = Date()

        // Auto-extract title from first heading if title is default
        if title == "Untitled" || title.isEmpty {
            if let extractedTitle = Document.extractTitle(from: newContent) {
                title = extractedTitle
            }
        }
    }

    /// Marks the document as accessed (for recent documents)
    func markAccessed() {
        accessedAt = Date()
    }

    /// Moves document to trash
    func moveToTrash() {
        isTrash = true
        modifiedAt = Date()
    }

    /// Restores document from trash
    func restore() {
        isTrash = false
        modifiedAt = Date()
    }

    // MARK: - Static Helpers

    static func generateExcerpt(from content: String, maxLength: Int = 200) -> String {
        // Remove markdown syntax for clean excerpt
        var plainText = content

        // Remove headings
        plainText = plainText.replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)

        // Remove bold/italic
        plainText = plainText.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression)
        plainText = plainText.replacingOccurrences(of: #"\*(.+?)\*"#, with: "$1", options: .regularExpression)
        plainText = plainText.replacingOccurrences(of: #"_(.+?)_"#, with: "$1", options: .regularExpression)

        // Remove links
        plainText = plainText.replacingOccurrences(of: #"\[(.+?)\]\(.+?\)"#, with: "$1", options: .regularExpression)

        // Remove code blocks
        plainText = plainText.replacingOccurrences(of: #"```[\s\S]*?```"#, with: "", options: .regularExpression)
        plainText = plainText.replacingOccurrences(of: #"`(.+?)`"#, with: "$1", options: .regularExpression)

        // Clean up whitespace
        plainText = plainText.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        plainText = plainText.trimmingCharacters(in: .whitespacesAndNewlines)

        if plainText.count <= maxLength {
            return plainText
        }

        let index = plainText.index(plainText.startIndex, offsetBy: maxLength)
        return String(plainText[..<index]) + "..."
    }

    static func countWords(in content: String) -> Int {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }

    static func extractTitle(from content: String) -> String? {
        // Try to find first heading
        let headingPattern = #"^#{1,6}\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: headingPattern, options: .anchorsMatchLines),
           let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            return String(content[range]).trimmingCharacters(in: .whitespaces)
        }

        // Fall back to first non-empty line
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                return String(trimmed.prefix(50))
            }
        }

        return nil
    }
}

// MARK: - Document Metadata

/// Extensible metadata for documents
struct DocumentMetadata: Codable {
    /// Custom font size preference for this document
    var fontSize: Int?

    /// Custom theme for this document (overrides app theme)
    var theme: String?

    /// Editor mode preference (source, preview, split)
    var editorMode: EditorMode?

    /// Cursor position for restoring editing state
    var cursorPosition: Int?

    /// Scroll position for restoring view state
    var scrollPosition: Double?

    /// Custom properties as key-value pairs
    var customProperties: [String: String]

    init(
        fontSize: Int? = nil,
        theme: String? = nil,
        editorMode: EditorMode? = nil,
        cursorPosition: Int? = nil,
        scrollPosition: Double? = nil,
        customProperties: [String: String] = [:]
    ) {
        self.fontSize = fontSize
        self.theme = theme
        self.editorMode = editorMode
        self.cursorPosition = cursorPosition
        self.scrollPosition = scrollPosition
        self.customProperties = customProperties
    }
}

/// Editor display modes
enum EditorMode: String, Codable, CaseIterable {
    case source = "source"
    case preview = "preview"
    case split = "split"

    var displayName: String {
        switch self {
        case .source: return "Source"
        case .preview: return "Preview"
        case .split: return "Split"
        }
    }

    var icon: String {
        switch self {
        case .source: return "doc.text"
        case .preview: return "eye"
        case .split: return "rectangle.split.2x1"
        }
    }
}
