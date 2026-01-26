//
//  NotesListView.swift
//  TextEditor
//

import SwiftUI
import SwiftData

struct NotesListView: View {
    @Query private var notes: [RichTextNote]
    @Environment(\.modelContext) var context
    
    /// Recursively faults in all attributes of a block and its nested blocks
    private func faultInBlockAttributes(_ block: NoteBlock) {
        // Force fault resolution by accessing attributes
        _ = block.text
        _ = block.type
        _ = block.orderIndex
        _ = block.typeString
        
        // Handle nested blocks in accordions
        if let accordion = block.accordion {
            _ = accordion.heading
            _ = accordion.level
            for nestedBlock in accordion.contentBlocks {
                faultInBlockAttributes(nestedBlock)
            }
        }
        
        // Handle nested blocks in columns
        if let columnData = block.columnData {
            for column in columnData.columns {
                for nestedBlock in column.blocks {
                    faultInBlockAttributes(nestedBlock)
                }
            }
        }
    }
    
    private func deleteNoteSafely(_ note: RichTextNote, context: ModelContext) {
        // Fault in note's attributes first
        _ = note.text
        _ = note.title
        _ = note.createdOn
        _ = note.updatedOn
        
        // Clear legacy tables array
        note.tables.removeAll()
        
        // Manually delete blocks first to ensure all attributes are faulted in
        let blocksToDelete = Array(note.blocks)
        for block in blocksToDelete {
            // Recursively fault in all attributes (including nested blocks)
            faultInBlockAttributes(block)
            
            // Remove from note's blocks array
            note.blocks.removeAll { $0.id == block.id }
            
            // Delete the block (this will cascade delete related data)
            context.delete(block)
        }
        
        // Save after deleting blocks
        try? context.save()
        
        // Now delete the note
        context.delete(note)
    }

    init(sortByCreation: Bool, filterCategory: String) {
        let sortDescriptors: [SortDescriptor<RichTextNote>] = if sortByCreation {
            [SortDescriptor(\RichTextNote.createdOn, order: .reverse)]
        } else {
            [SortDescriptor(\RichTextNote.updatedOn, order: .reverse)]
        }
        switch filterCategory {
        case Category.all:
            _notes = Query(sort: sortDescriptors)
        case Category.uncategorized:
            let predicate = #Predicate<RichTextNote> { note in
                note.category == nil
            }
            _notes = Query(filter: predicate, sort: sortDescriptors)
        default:
            let predicate = #Predicate<RichTextNote> { note in
                note.category?.name.contains(filterCategory) == true
            }
            _notes = Query(filter: predicate, sort: sortDescriptors)
        }
    }

    var body: some View {
        Group {
            if notes.isEmpty {
                ContentUnavailableView {
                    Label("No Notes", systemImage: "note.text")
                } description: {
                    Text("Tap the compose button to create your first note.")
                }
            } else {
                List {
                    ForEach(notes) { note in
                        NavigationLink(value: note) {
                            NoteRowView(note: note)
                        }
                    }
                    .onDelete { indices in
                        for index in indices {
                            let note = notes[index]
                            deleteNoteSafely(note, context: context)
                        }
                        try? context.save()
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #else
                .listStyle(.inset)
                #endif
            }
        }
    }
}

// MARK: - Note Row View

struct NoteRowView: View {
    let note: RichTextNote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title/Preview
            Text(noteTitle)
                .font(.headline)
                .lineLimit(1)

            // Preview text
            if !previewBody.isEmpty {
                Text(previewBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Footer: Category + Date
            HStack {
                if let category = note.category {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: category.hexColor) ?? .gray)
                            .frame(width: 8, height: 8)
                        Text(category.name)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(note.updatedOn, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var noteTitle: String {
        if !note.title.isEmpty {
            return note.title
        }
        let text = note.previewText.isEmpty ? String(note.text.characters) : note.previewText
        let firstLine = text.components(separatedBy: .newlines).first ?? ""
        return firstLine.isEmpty ? "Untitled" : String(firstLine.prefix(50))
    }

    private var previewBody: String {
        let text = note.previewText.isEmpty ? String(note.text.characters) : note.previewText
        let lines = text.components(separatedBy: .newlines)
        if lines.count > 1 {
            return lines.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
        }
        return ""
    }
}

#Preview(traits: .mockData) {
    NavigationStack {
        NotesListView(sortByCreation: true, filterCategory: Category.all)
    }
}
