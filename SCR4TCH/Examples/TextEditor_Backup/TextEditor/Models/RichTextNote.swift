//
//----------------------------------------------
// Original project: RichNotes
// by  Stewart Lynch on 2025-10-28
//
// Follow me on Mastodon: https://iosdev.space/@StewartLynch
// Follow me on Threads: https://www.threads.net/@stewartlynch
// Follow me on Bluesky: https://bsky.app/profile/stewartlynch.bsky.social
// Follow me on X: https://x.com/StewartLynch
// Follow me on LinkedIn: https://linkedin.com/in/StewartLynch
// Email: slynch@createchsol.com
// Subscribe on YouTube: https://youTube.com/@StewartLynch
// Buy me a ko-fi:  https://ko-fi.com/StewartLynch
//----------------------------------------------
// Copyright © 2025 CreaTECH Solutions. All rights reserved.


import Foundation
import SwiftData

@Model
class RichTextNote {
    enum NoteStatus: String, Codable, CaseIterable {
        case saved
        case temp
        case deleted
    }

    var text: AttributedString
    var createdOn: Date
    var updatedOn: Date
    var title: String = ""
    var category: Category?
    var statusRaw: String = NoteStatus.saved.rawValue
    
    var status: NoteStatus {
        get { NoteStatus(rawValue: statusRaw) ?? .saved }
        set { statusRaw = newValue.rawValue }
    }
    
    var movedToDeletedOn: Date?
    var isPinned: Bool = false
    
    @Relationship(deleteRule: .nullify, inverse: \Tag.notes)
    var tags: [Tag] = []
    
    @Relationship(deleteRule: .cascade)
    var tables: [TableData]
    
    @Relationship(deleteRule: .cascade)
    var blocks: [NoteBlock]

    /// Stores the last used code language for new code blocks (defaults to "swift")
    var lastUsedCodeLanguage: String = "swift"

    var previewText: String {
        guard modelContext != nil else { return "" }
        return blocks.sorted(by: { $0.orderIndex < $1.orderIndex })
            .compactMap { block in
                if let text = block.text {
                    return String(text.characters)
                }
                return nil
            }
            .joined(separator: " ")
    }
    
    /// Extracts all searchable text from the note, including content from all block types
    var allSearchableText: String {
        var textParts: [String] = []
        
        // Add title
        if !title.isEmpty {
            textParts.append(title)
        }
        
        // Add category name
        if let category = category {
            textParts.append(category.name)
        }
        
        // Add tag names
        for tag in tags {
            textParts.append(tag.name)
        }
        
        // Add legacy text field
        let legacyText = String(text.characters)
        if !legacyText.isEmpty {
            textParts.append(legacyText)
        }
        
        // Extract text from all blocks
        for block in blocks.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            textParts.append(extractTextFromBlock(block))
        }
        
        return textParts.joined(separator: " ")
    }
    
    /// Recursively extracts all text from a block and its nested content
    private func extractTextFromBlock(_ block: NoteBlock) -> String {
        var textParts: [String] = []
        
        switch block.type {
        case .text:
            if let text = block.text {
                textParts.append(String(text.characters))
            }
            
        case .table:
            if let table = block.table {
                // Add table title
                if !table.title.isEmpty {
                    textParts.append(table.title)
                }
                // Add all cell content
                for cell in table.cells {
                    if !cell.content.isEmpty {
                        textParts.append(cell.content)
                    }
                }
            }
            
        case .code:
            if let codeBlock = block.codeBlock {
                textParts.append(codeBlock.code)
            }
            
        case .list:
            if let listData = block.listData {
                // Add list title if present
                if let title = listData.title, !title.isEmpty {
                    textParts.append(title)
                }
                // Add all list item text
                for item in listData.items.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                    if let text = item.text {
                        textParts.append(String(text.characters))
                    }
                }
            }
            
        case .accordion:
            if let accordion = block.accordion {
                // Add accordion heading
                textParts.append(String(accordion.heading.characters))
                // Recursively extract text from nested blocks
                for nestedBlock in accordion.contentBlocks.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                    textParts.append(extractTextFromBlock(nestedBlock))
                }
            }
            
        case .columns:
            if let columnData = block.columnData {
                // Extract text from all columns
                for column in columnData.columns.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                    // Recursively extract text from blocks in each column
                    for nestedBlock in column.blocks.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                        textParts.append(extractTextFromBlock(nestedBlock))
                    }
                }
            }
            
        case .quote:
            // Quote blocks use the text property
            if let text = block.text {
                textParts.append(String(text.characters))
            }
            
        case .bookmark:
            if let bookmark = block.bookmarkData {
                if let title = bookmark.title, !title.isEmpty {
                    textParts.append(title)
                }
                if let description = bookmark.descriptionText, !description.isEmpty {
                    textParts.append(description)
                }
                textParts.append(bookmark.urlString)
            }
            
        case .filePath:
            if let filePath = block.filePathData {
                textParts.append(filePath.pathString)
                if let displayName = filePath.displayName, !displayName.isEmpty {
                    textParts.append(displayName)
                }
            }
            
        case .image:
            // Images don't have searchable text content
            break
        }
        
        return textParts.joined(separator: " ")
    }
    
    init(text: AttributedString, createdOn: Date = Date.now, updatedOn: Date = Date.now) {
        self.text = text
        self.createdOn = createdOn
        self.updatedOn = updatedOn
        self.tables = []
        self.blocks = []
    }
    
    static var sample: RichTextNote = RichTextNote(text: """
        Now is the time for all good men to come to the aid of the party.
        
        This is going to be a lot of fun.
        """)
}
