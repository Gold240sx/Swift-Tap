//
//  NotesView.swift
//  TextEditor
//

import SwiftUI
import SwiftData

struct NotesView: View {
    @Environment(\.modelContext) var context
    @State private var path = NavigationPath()
    @State private var sortByCreation = true
    @State private var filterCategory = Category.all
    @Query(sort: \Category.name) var categories: [Category]

    var body: some View {
        NavigationStack(path: $path) {
            NotesListView(sortByCreation: sortByCreation, filterCategory: filterCategory)
                .navigationTitle("Notes")
                #if os(iOS)
                .toolbarTitleDisplayMode(.large)
                #endif
                .navigationDestination(for: RichTextNote.self) { note in
                    NotesEditorView(note: note)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            let newNote = RichTextNote(text: "")
                            context.insert(newNote)
                            path.append(newNote)
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
                                    Label("Date Created", systemImage: sortByCreation ? "checkmark" : "")
                                }
                                Button {
                                    sortByCreation = false
                                } label: {
                                    Label("Last Modified", systemImage: !sortByCreation ? "checkmark" : "")
                                }
                            }

                            Section("Filter") {
                                Button {
                                    filterCategory = Category.all
                                } label: {
                                    Label("All Notes", systemImage: filterCategory == Category.all ? "checkmark" : "")
                                }
                                Button {
                                    filterCategory = Category.uncategorized
                                } label: {
                                    Label("Uncategorized", systemImage: filterCategory == Category.uncategorized ? "checkmark" : "")
                                }
                                ForEach(categories) { category in
                                    Button {
                                        filterCategory = category.name
                                    } label: {
                                        Label(category.name, systemImage: filterCategory == category.name ? "checkmark" : "")
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
        }
    }
}

#Preview(traits: .mockData) {
    NotesView()
}
