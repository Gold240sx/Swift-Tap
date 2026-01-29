//
//  NotesView.swift
//  TextEditor
//

import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

struct NotesView: View {
    @Environment(\.modelContext) var context
    @State private var selectedNote: RichTextNote?
    @State private var sortByCreation = true
    @State private var filterCategory = Category.all
    @State private var filterTag: String? = nil
    @State private var statusFilter: NoteStatusFilter = .saved
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @Query(sort: \Category.name) var categories: [Category]
    @Query private var allSettings: [AppSettings]
    
    private var settings: AppSettings {
        allSettings.first ?? AppSettings.default
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar with notes list
            NotesSidebarView(
                selectedNote: $selectedNote,
                sortByCreation: $sortByCreation,
                filterCategory: $filterCategory,
                filterTag: $filterTag,
                statusFilter: statusFilter,
                onStatusChange: { statusFilter = $0 },
                onNewNote: createNewNote,
                onDelete: deleteNote
            )
            #if os(macOS)
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(nsImage: NSApplication.shared.applicationIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                        Text("SCR4TCH")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                }
            }
            #endif
        } detail: {
            // Detail view with note editor
            if let note = selectedNote {
                NotesEditorView(note: note)
                    .toolbar(removing: .sidebarToggle)
            } else {
                ContentUnavailableView {
                    Label("No Note Selected", systemImage: "note.text")
                } description: {
                    Text("Select a note from the sidebar or create a new one.")
                }
            }
                .toolbar(removing: .sidebarToggle)
        }
        .toolbar{
            ToolbarItem(placement: .navigation) {
                SidebarButton()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 200)
        .tint(Color(red: 0.0, green: 0.3, blue: 0.8))
        .accentColor(Color(red: 0.0, green: 0.3, blue: 0.8))
    }

    private func createNewNote() {
        let newNote = RichTextNote(text: "")
        newNote.status = settings.defaultStatus
        
        // Ensure the note has at least one block to start with
        let firstBlock = NoteBlock(orderIndex: 0, text: AttributedString(""), type: .text)
        newNote.blocks.append(firstBlock)
        
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
        if note.status == .deleted {
            // Permanently delete if already in deleted status
            performPermanentDelete(note)
        } else {
            // Otherwise, move to deleted status
            note.status = .deleted
            note.movedToDeletedOn = Date.now
            try? context.save()
            
            if selectedNote?.id == note.id {
                selectedNote = nil
            }
        }
    }
    
    private func performPermanentDelete(_ note: RichTextNote) {
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

// MARK: - Filter Enum
enum NoteStatusFilter: String, CaseIterable, Identifiable {
    case all
    case saved
    case temp
    case deleted
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .all: return "All Purposes"
        default: return rawValue.capitalized
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .saved: return "checkmark.circle"
        case .temp: return "clock"
        case .deleted: return "trash"
        }
    }
}

// MARK: - Sidebar View

struct NotesSidebarView: View {
    @Environment(\.modelContext) var context
    @Query private var allNotes: [RichTextNote]
    @Binding var selectedNote: RichTextNote?
    var statusFilter: NoteStatusFilter
    @Binding var sortByCreation: Bool

    @Binding var filterCategory: String
    @Binding var filterTag: String?
    var onStatusChange: (NoteStatusFilter) -> Void
    var onNewNote: () -> Void
    var onDelete: (RichTextNote) -> Void
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var searchText: String = ""

    init(selectedNote: Binding<RichTextNote?>, sortByCreation: Binding<Bool>, filterCategory: Binding<String>, filterTag: Binding<String?>, statusFilter: NoteStatusFilter, onStatusChange: @escaping (NoteStatusFilter) -> Void, onNewNote: @escaping () -> Void, onDelete: @escaping (RichTextNote) -> Void) {
        self._selectedNote = selectedNote
        self.statusFilter = statusFilter
        self._sortByCreation = sortByCreation
        self._filterCategory = filterCategory
        self._filterTag = filterTag
        self.onStatusChange = onStatusChange
        self.onNewNote = onNewNote
        self.onDelete = onDelete

        let categoryName = filterCategory.wrappedValue
        let tagName = filterTag.wrappedValue

        // Helper to check status
        let statusRaw = statusFilter.rawValue
        let isAllStatus = statusFilter == .all

        if let tagName {
            // Filter by Tag + Status + Category
            if isAllStatus {
               switch categoryName {
                case Category.all:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw != "deleted" && note.tags.contains { $0.name == tagName }
                    }
                    _allNotes = Query(filter: predicate)
                case Category.uncategorized:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw != "deleted" && note.category == nil && note.tags.contains { $0.name == tagName }
                    }
                    _allNotes = Query(filter: predicate)
                default:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw != "deleted" && note.category?.name == categoryName && note.tags.contains { $0.name == tagName }
                    }
                    _allNotes = Query(filter: predicate)
                }
            } else {
                 switch categoryName {
                case Category.all:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw == statusRaw && note.tags.contains { $0.name == tagName }
                    }
                    _allNotes = Query(filter: predicate)
                case Category.uncategorized:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw == statusRaw && note.category == nil && note.tags.contains { $0.name == tagName }
                    }
                    _allNotes = Query(filter: predicate)
                default:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw == statusRaw && note.category?.name == categoryName && note.tags.contains { $0.name == tagName }
                    }
                    _allNotes = Query(filter: predicate)
                }
            }
        } else {
            // No Tag Filter (Existing Logic)
            if isAllStatus {
                switch categoryName {
                case Category.all:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw != "deleted"
                    }
                    _allNotes = Query(filter: predicate)
                case Category.uncategorized:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw != "deleted" && note.category == nil
                    }
                    _allNotes = Query(filter: predicate)
                default:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw != "deleted" && note.category?.name == categoryName
                    }
                    _allNotes = Query(filter: predicate)
                }
            } else {
                switch categoryName {
                case Category.all:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw == statusRaw
                    }
                    _allNotes = Query(filter: predicate)
                case Category.uncategorized:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw == statusRaw && note.category == nil
                    }
                    _allNotes = Query(filter: predicate)
                default:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw == statusRaw && note.category?.name == categoryName
                    }
                    _allNotes = Query(filter: predicate)
                }
            }
        }
    }
    
    /// Filtered and sorted notes based on search text and pinned status
    private var filteredNotes: [RichTextNote] {
        let base = searchText.isEmpty ? allNotes : allNotes.filter { note in
            // Safety check: Don't access attributes if note is detached or deleted
            guard note.modelContext != nil else { return false }
            
            let allText = note.allSearchableText.lowercased()
            return allText.contains(searchText.lowercased())
        }
        
        let sortedNotes = base.sorted { n1, n2 in
            // Safety check for sorting as well
            guard n1.modelContext != nil && n2.modelContext != nil else { return false }
            
            if n1.isPinned != n2.isPinned {
                return n1.isPinned // Pinned first
            }
            if sortByCreation {
                return n1.createdOn > n2.createdOn
            } else {
                return n1.updatedOn > n2.updatedOn
            }
        }
        
        // Ensure selected note is always visible
        if let selected = selectedNote, !sortedNotes.contains(where: { $0.id == selected.id }) {
            return [selected] + sortedNotes
        }
        
        return sortedNotes
    }

    private var statusFilterIcon: String {
        switch statusFilter {
        case .saved: return "checkmark.circle"
        case .temp: return "clock"
        case .deleted: return "trash"
        case .all: return "tray.full"
        }
    }

    private var statusFilterColor: Color {
        switch statusFilter {
        case .saved: return .blue
        case .temp: return .orange
        case .deleted: return .red
        case .all: return .primary
        }
    }

    private var isFiltering: Bool {
        !searchText.isEmpty ||
        filterCategory != Category.all ||
        filterTag != nil ||
        statusFilter != .saved ||
        !sortByCreation
    }
    
    private func resetFilters() {
        withAnimation {
            searchText = ""
            filterCategory = Category.all
            filterTag = nil
            sortByCreation = true
            onStatusChange(.saved)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar and Status Picker inline
            // Search bar, Status Picker, and Sort Button inline
            
            // Search Bar Row
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Button {
                    onNewNote()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Create New Note")
                
                if isFiltering {
                    Button {
                        resetFilters()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Reset filters and search")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)
            
            // Filter Row (Categories | Status | Sort)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Category Picker
                    Menu {
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
                        Divider()
                        ForEach(categories) { category in
                            Button {
                                filterCategory = category.name
                            } label: {
                                Label(category.name, systemImage: filterCategory == category.name ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text(filterCategory == Category.all ? "Category" : filterCategory)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    // Tags Picker
                    Menu {
                        Button {
                            filterTag = nil
                        } label: {
                            Label("All Tags", systemImage: filterTag == nil ? "checkmark" : "")
                        }
                        Divider()
                        ForEach(allTags) { tag in
                            Button {
                                filterTag = tag.name
                            } label: {
                                Label(tag.name, systemImage: filterTag == tag.name ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                            Text(filterTag ?? "Tags")
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    // Status Picker
                    Menu {
                        ForEach(NoteStatusFilter.allCases) { status in
                            Button {
                                onStatusChange(status)
                            } label: {
                                Label(status.title, systemImage: status.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: statusFilterIcon)
                            Text(statusFilter.title)
                        }
                        .padding(8)
                        .background(statusFilterColor.opacity(0.1))
                        .foregroundStyle(statusFilterColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    // Sort Button
                    Menu {
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
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 10)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            Divider()
            
            // Content area
            if filteredNotes.isEmpty {
                VStack {
                    Spacer()
                    ContentUnavailableView {
                        Label(searchText.isEmpty ? "No Notes" : "No Results", systemImage: searchText.isEmpty ? "note.text" : "magnifyingglass")
                    } description: {
                        Text(searchText.isEmpty ? "Create a new note to get started." : "No notes match your search.")
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedNote) {
                    ForEach(filteredNotes) { note in
                        SidebarNoteRow(note: note)
                            .tag(note)
                            .contextMenu {
                                if note.status == .deleted {
                                    Button(role: .destructive) {
                                        onDelete(note)
                                    } label: {
                                        Label("Delete Permanently", systemImage: "trash.fill")
                                    }
                                    Button {
                                        note.status = .saved
                                        note.movedToDeletedOn = nil
                                    } label: {
                                        Label("Restore to Saved", systemImage: "arrow.uturn.backward")
                                    }
                                } else {
                                    Button {
                                        note.isPinned.toggle()
                                        try? context.save()
                                    } label: {
                                        Label(note.isPinned ? "Unpin Note" : "Pin Note", systemImage: note.isPinned ? "pin.slash" : "pin")
                                    }
                                    
                                    Button(role: .destructive) {
                                        onDelete(note)
                                    } label: {
                                        Label("Move to Trash", systemImage: "trash")
                                    }
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
            HStack(alignment: .top) {
                Text(noteTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                if note.isPinned {
                    Spacer()
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                        .rotationEffect(.degrees(45))
                }
            }

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
                
                if note.status == .temp {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                        Text("Temp")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                } else if note.status == .deleted {
                    HStack(spacing: 2) {
                        Image(systemName: "trash")
                        Text("Deleted")
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
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
        // Safety check: if detached, return placeholder
        guard note.modelContext != nil else { return "Deleted Note" }
        
        if !note.title.isEmpty {
            return note.title
        }
        let text = note.previewText.isEmpty ? String(note.text.characters) : note.previewText
        let firstLine = text.components(separatedBy: .newlines).first ?? ""
        return firstLine.isEmpty ? "Untitled" : String(firstLine.prefix(50))
    }

    private var previewBody: String {
        // Safety check: if detached, return empty
        guard note.modelContext != nil else { return "" }
        
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
