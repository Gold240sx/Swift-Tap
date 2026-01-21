//
//  NotesListView.swift
//  TextEditor
//

import SwiftUI
import SwiftData

struct NotesListView: View {
    @Query private var notes: [RichTextNote]
    @Environment(\.modelContext) var context

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
                            context.delete(notes[index])
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
