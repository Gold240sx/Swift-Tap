//
//  NoteMigrationHelper.swift
//  TextEditor
//
//  Utility to migrate legacy note data to the block-based system.
//

import Foundation
import SwiftData

struct NoteMigrationHelper {
    static func migrateIfNecessary(note: RichTextNote, context: ModelContext) {
        if note.blocks.isEmpty {
            var currentIndex = 0
            
            // 1. Create text block if text exists OR if the note is completely empty (new note)
            if !note.text.characters.isEmpty || note.tables.isEmpty {
                // For new notes (completely empty), create an empty text block
                // The placeholder will be shown in TextBlockView
                let textBlock = NoteBlock(orderIndex: currentIndex, text: note.text, type: .text)
                note.blocks.append(textBlock)
                context.insert(textBlock)
                currentIndex += 1
            }
            
            // 2. Wrap existing legacy tables in blocks
            for table in note.tables {
                let tableBlock = NoteBlock(orderIndex: currentIndex, table: table, type: .table)
                note.blocks.append(tableBlock)
                context.insert(tableBlock)
                currentIndex += 1
            }
            
            try? context.save()
        }
    }
}
