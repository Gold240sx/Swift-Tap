//
//  NotesView.swift
//  TextEditor
//

import SwiftUI
import SwiftData

struct NotesView: View {
    @Environment(\.modelContext) var context
    @State private var selectedNote: RichTextNote?
    @State private var sortByCreation = true
    @State private var filterCategory = Category.all
    @Query(sort: \Category.name) var categories: [Category]

    var body: some View {
        NavigationSplitView {
            // Sidebar with notes list
            NotesSidebarView(
                selectedNote: $selectedNote,
                sortByCreation: sortByCreation,
                filterCategory: filterCategory,
                onDelete: deleteNote
            )
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createNewNote()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .medium))
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Section("Sort By") {
                            Button {
                                sortByCreation = true
                            } label: {
                                HStack {
                                    Text("Date Created")
                                    if sortByCreation {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            Button {
                                sortByCreation = false
                            } label: {
                                HStack {
                                    Text("Last Modified")
                                    if !sortByCreation {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }

                        Section("Filter") {
                            Button {
                                filterCategory = Category.all
                            } label: {
                                HStack {
                                    Text("All Notes")
                                    if filterCategory == Category.all {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            Button {
                                filterCategory = Category.uncategorized
                            } label: {
                                HStack {
                                    Text("Uncategorized")
                                    if filterCategory == Category.uncategorized {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            ForEach(categories) { category in
                                Button {
                                    filterCategory = category.name
                                } label: {
                                    HStack {
                                        Text(category.name)
                                        if filterCategory == category.name {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        } detail: {
            // Detail view with note editor
            if let note = selectedNote {
                NotesEditorView(note: note)
            } else {
                ContentUnavailableView {
                    Label("No Note Selected", systemImage: "note.text")
                } description: {
                    Text("Select a note from the sidebar or create a new one.")
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(Color(red: 0.0, green: 0.3, blue: 0.8))
        .accentColor(Color(red: 0.0, green: 0.3, blue: 0.8))
    }

    private func createNewNote() {
        let newNote = RichTextNote(text: "")
        context.insert(newNote)
        try? context.save()
        selectedNote = newNote
    }

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
    
    private func deleteNote(_ note: RichTextNote) {
        // If deleting the selected note, clear selection
        if selectedNote?.id == note.id {
            selectedNote = nil
        }
        
        // Fault in note's attributes first
        _ = note.text
        _ = note.title
        _ = note.createdOn
        _ = note.updatedOn
        
        // Clear legacy tables array to avoid conflicts
        note.tables.removeAll()
        
        // Manually delete blocks first to ensure all attributes are faulted in
        // This prevents SwiftData from trying to access lazy-loaded attributes during cascade deletion
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
        try? context.save()
    }
}

// MARK: - Sidebar View

struct NotesSidebarView: View {
    @Query private var notes: [RichTextNote]
    @Binding var selectedNote: RichTextNote?
    var onDelete: (RichTextNote) -> Void

    init(selectedNote: Binding<RichTextNote?>, sortByCreation: Bool, filterCategory: String, onDelete: @escaping (RichTextNote) -> Void) {
        self._selectedNote = selectedNote
        self.onDelete = onDelete

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
                    Text("Create a new note to get started.")
                }
            } else {
                List(selection: $selectedNote) {
                    ForEach(notes) { note in
                        SidebarNoteRow(note: note)
                            .tag(note)
                            .contextMenu {
                                Button(role: .destructive) {
                                    onDelete(note)
                                } label: {
                                    Label("Delete Note", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
}

// MARK: - Sidebar Note Row

struct SidebarNoteRow: View {
    let note: RichTextNote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title
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
    NotesView()
}
