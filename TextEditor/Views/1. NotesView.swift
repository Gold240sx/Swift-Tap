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
        }
        .tint(Color(red: 0.0, green: 0.3, blue: 0.8)) // Stronger blue for dark mode visibility
        .accentColor(Color(red: 0.0, green: 0.3, blue: 0.8))
    }
}

#Preview(traits: .mockData) {
    NotesView()
}
