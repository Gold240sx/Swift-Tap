//
//  ContentView.swift
//  MarkdownPro
//
//  Created by Michael Martell on 1/11/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Document> { !$0.isTrash }, sort: \Document.modifiedAt, order: .reverse)
    private var documents: [Document]

    @State private var selectedDocument: Document?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        mainContentView
    }
    
    private var mainContentView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar with document list
            DocumentListView(selectedDocument: $selectedDocument)
                .navigationTitle("Documents")
                #if os(macOS)
                .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 350)
                #endif
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: createNewDocument) {
                            Label("New Document", systemImage: "plus")
                        }
                        .keyboardShortcut("n", modifiers: .command)
                    }
                }
        } detail: {
            // Document editor
            if let document = selectedDocument {
                DocumentEditorView(document: document)
                    .id(document.id) // Force refresh when document changes
            } else {
                EmptyDocumentView(onCreate: createNewDocument)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewDocument)) { _ in
            createNewDocument()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveDocument)) { _ in
            saveCurrentDocument()
        }
    }

    private func createNewDocument() {
        let document = Document(
            title: "Untitled",
            content: ""
        )
        modelContext.insert(document)

        // Select the new document
        selectedDocument = document
    }

    private func saveCurrentDocument() {
        guard let document = selectedDocument else { return }
        document.modifiedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [Document.self, Folder.self, Tag.self, EditorSettings.self], inMemory: true)
        .frame(width: 1200, height: 800)
}
