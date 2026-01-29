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
    @ObservedObject private var langManager = LanguageManager.shared
    @State private var selectedNote: RichTextNote?
    @State private var sortByCreation = true
    @State private var filterCategory = Category.all
    @State private var filterTag: String? = nil
    @State private var statusFilter: NoteStatusFilter = .all
    @State private var showFilters = false // For conditional filter bar
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var sheetPresented = false
    @Query(sort: \Category.name) var categories: [Category]
    @Query private var allSettings: [AppSettings]
    
    private var settings: AppSettings {
        allSettings.first ?? AppSettings.default
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NotesSidebarView(
                selectedNote: $selectedNote,
                sortByCreation: $sortByCreation,
                filterCategory: $filterCategory,
                filterTag: $filterTag,
                statusFilter: statusFilter,
                showFilters: $showFilters,
                sheetPresented: $sheetPresented,
                onStatusChange: { statusFilter = $0 },
                onNewNote: createNewNote,
                onDelete: deleteNote
            )
            #if os(macOS)
            .frame(minWidth: 300)
            .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 400)
            .toolbar(removing: .sidebarToggle)
            #endif
        } detail: {
            // Detail view with note editor
            if let note = selectedNote {
                NotesEditorView(note: note)
            } else {
                ContentUnavailableView {
                    Label(langManager.translate("no_note_selected"), systemImage: "note.text")
                } description: {
                    Text(langManager.translate("select_note_description"))
                }
            }
        }
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .navigation) {
                SidebarButton()
            }
            #endif
        }
        .navigationSplitViewStyle(.balanced)
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 400)
        #endif
        .tint(Color(red: 0.0, green: 0.3, blue: 0.8))
        .accentColor(Color(red: 0.0, green: 0.3, blue: 0.8))
        .onChange(of: selectedNote) { _, newValue in
            if let note = newValue {
                note.markRemindersAsViewed()
            }
        }
        .sheet(isPresented: $sheetPresented) {
            SettingsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            sheetPresented = true
        }
    }

    private func createNewNote() {
        let newNote = RichTextNote(text: "")
        newNote.status = settings.defaultStatus ?? .saved
        
        // Ensure the note has at least one block to start with
        let firstBlock = NoteBlock(orderIndex: 0, text: AttributedString(""), type: .text)
        if newNote.blocks == nil { newNote.blocks = [] }
        newNote.blocks?.append(firstBlock)
        
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
            for nestedBlock in accordion.contentBlocks ?? [] {
                faultInBlockAttributes(nestedBlock)
            }
        }
        
        // Handle nested blocks in columns
        if let columnData = block.columnData {
            for column in columnData.columns ?? [] {
                for nestedBlock in column.blocks ?? [] {
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
        note.tables?.removeAll()
        
        // Manually delete blocks first to ensure all attributes are faulted in
        // This prevents SwiftData from trying to access lazy-loaded attributes during cascade deletion
        let blocksToDelete = Array(note.blocks ?? [])
        for block in blocksToDelete {
            // Recursively fault in all attributes (including nested blocks)
            faultInBlockAttributes(block)
            
            // Remove from note's blocks array
            note.blocks?.removeAll { $0.id == block.id }
            
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
    case deletingSoon = "deleting_soon"
    case deleted
    
    var id: String { rawValue }
    
    var title: String {
        if self == .all { return "All Statuses" }
        return LanguageManager.shared.translate(self.rawValue)
    }
    
    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .saved: return "checkmark.circle"
        case .temp: return "clock"
        case .deletingSoon: return "clock.badge.exclamationmark"
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
    @Binding var showFilters: Bool // Added property
    @Binding var sortByCreation: Bool

    @Binding var filterCategory: String
    @Binding var filterTag: String?
    var onStatusChange: (NoteStatusFilter) -> Void
    var onNewNote: () -> Void
    var onDelete: (RichTextNote) -> Void
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var searchText: String = ""
    @Binding var sheetPresented: Bool
    @State private var isNewNoteHovered = false
    @State private var isGearHovered = false
    @State private var showDeleteAllAlert = false
    @Query private var allSettings: [AppSettings]
    @ObservedObject private var langManager = LanguageManager.shared
    
    private var settings: AppSettings {
        allSettings.first ?? AppSettings.default
    }
    
    init(selectedNote: Binding<RichTextNote?>, sortByCreation: Binding<Bool>, filterCategory: Binding<String>, filterTag: Binding<String?>, statusFilter: NoteStatusFilter, showFilters: Binding<Bool>, sheetPresented: Binding<Bool>, onStatusChange: @escaping (NoteStatusFilter) -> Void, onNewNote: @escaping () -> Void, onDelete: @escaping (RichTextNote) -> Void) {
        self._selectedNote = selectedNote
        self.statusFilter = statusFilter
        self._sortByCreation = sortByCreation
        self._filterCategory = filterCategory
        self._filterTag = filterTag
        self._showFilters = showFilters // Initialize binding
        self._sheetPresented = sheetPresented
        self.onStatusChange = onStatusChange
        self.onNewNote = onNewNote
        self.onDelete = onDelete

        let categoryName = filterCategory.wrappedValue
        let tagName = filterTag.wrappedValue

        // Helper to check status
        let isAllStatus = statusFilter == .all
        
        // Handle raw value mismatch for Deleting Soon
        let targetStatusRaw: String
        if statusFilter == .deletingSoon {
            targetStatusRaw = "Deleting Soon"
        } else {
            targetStatusRaw = statusFilter.rawValue
        }

        if let tagName {
            // Filter by Tag + Status + Category
            if isAllStatus {
               switch categoryName {
                case Category.all:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw != "deleted" && (note.tags?.contains { $0.name == tagName } == true)
                    }
                    _allNotes = Query(filter: predicate)
                case Category.uncategorized:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw != "deleted" && note.category == nil && (note.tags?.contains { $0.name == tagName } == true)
                    }
                    _allNotes = Query(filter: predicate)
                default:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw != "deleted" && note.category?.name == categoryName && (note.tags?.contains { $0.name == tagName } == true)
                    }
                    _allNotes = Query(filter: predicate)
                }
            } else {
                 switch categoryName {
                case Category.all:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw == targetStatusRaw && (note.tags?.contains { $0.name == tagName } == true)
                    }
                    _allNotes = Query(filter: predicate)
                case Category.uncategorized:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw == targetStatusRaw && note.category == nil && (note.tags?.contains { $0.name == tagName } == true)
                    }
                    _allNotes = Query(filter: predicate)
                default:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw == targetStatusRaw && note.category?.name == categoryName && (note.tags?.contains { $0.name == tagName } == true)
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
                        note.statusRaw == targetStatusRaw
                    }
                    _allNotes = Query(filter: predicate)
                case Category.uncategorized:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw == targetStatusRaw && note.category == nil
                    }
                    _allNotes = Query(filter: predicate)
                default:
                    let predicate = #Predicate<RichTextNote> { note in
                        note.statusRaw == targetStatusRaw && note.category?.name == categoryName
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
        case .deletingSoon: return "clock.badge.exclamationmark"
        case .deleted: return "trash"
        case .all: return "tray.full"
        }
    }

    private var statusFilterColor: Color {
        switch statusFilter {
        case .saved: return .blue
        case .temp: return .orange
        case .deletingSoon: return .red
        case .deleted: return .red
        case .all: return .primary
        }
    }

    private var isFiltering: Bool {
        !searchText.isEmpty ||
        filterCategory != Category.all ||
        filterTag != nil ||
        statusFilter != .all || // Changed to .all to match reset state
        !sortByCreation
    }
    
    private func resetFilters() {
        withAnimation {
            searchText = ""
            filterCategory = Category.all
            filterTag = nil
            sortByCreation = true
            onStatusChange(.all) // Changed to .all
            selectedNote = nil // Clear selection to prevent forcing it into view
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Header with Logo
            HStack {
                Spacer()
                Spacer()
                Spacer()
                Image(langManager.translate("logo_image"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: langManager.scaledFontSize(20))
                Spacer()
                Spacer()
                
                Button {
                    sheetPresented.toggle()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: langManager.scaledFontSize(18), weight: .medium))
                        .foregroundStyle(isGearHovered ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .opacity(isGearHovered ? 0.7 : 1)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovered in
                    isGearHovered = hovered
                }
            }
            .padding(.top, 2) // Align with stoplights when ignoring safe area
            .padding(.horizontal, 12)
            
            VStack(spacing: 4) {
                                // Expanded Filters
                if showFilters {
                    VStack(spacing: 8) {
                        // Reset Filters Text Button
                        HStack {
                            Spacer()
                            if isFiltering {
                                Button {
                                    resetFilters()
                                } label: {
                                    Text(langManager.translate("reset_filters"))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                        .padding(.trailing, 8)
                                        .padding(.top, 4)
                                }
                                .buttonStyle(.plain)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                            }
                        }
                        .padding(.horizontal, 4)
                        .frame(height: isFiltering ? 14 : 0)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Search Bar row
                HStack(spacing: 8) {
                    // Filters Toggle
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showFilters.toggle()
                        }
                    } label: {
                        Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: langManager.scaledFontSize(16), weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(0)
                            .background(showFilters ? Color.accentColor.opacity(0.1) : Color.black.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: langManager.scaledFontSize(14)))
                            .foregroundStyle(.secondary)
                        TextField(langManager.translate("search_placeholder"), text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: langManager.scaledFontSize(14)))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(langManager.translate("clear_search"))
                        }
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.20))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // New Note Button
                    Button {
                        onNewNote()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: langManager.scaledFontSize(16), weight: .medium))
                            .foregroundStyle(isNewNoteHovered ? .white : .primary)
                            .padding(8)
                            .background(isNewNoteHovered ? Color.accentColor : Color.black.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .onHover { isNewNoteHovered = $0 }
                    .help(langManager.translate("new_note_tooltip"))
                }
                .padding(.trailing, 8)
                .padding(.leading, 12)
                .padding(.vertical, 4)

                if (showFilters) {
                              // Filters row
                        HStack(spacing: 0) {
                            // Sort Button
                            Menu {
                                Button {
                                    sortByCreation = true
                                } label: {
                                    Label {
                                        Text(langManager.translate("date_created"))
                                    } icon: {
                                        if sortByCreation {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                Button {
                                    sortByCreation = false
                                } label: {
                                    Label {
                                        Text(langManager.translate("last_modified"))
                                    } icon: {
                                        if !sortByCreation {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            } label: {
                                filterButtonLabel(icon: "arrow.up.arrow.down", title: langManager.translate("sort"))
                            }
                            .background(Color.black.opacity(0.20))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(maxWidth: .infinity)

                            // Category Picker
                            Menu {
                                Button {
                                    filterCategory = Category.all
                                } label: {
                                    Label {
                                        Text(langManager.translate("all_categories"))
                                    } icon: {
                                        if filterCategory == Category.all {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                Button {
                                    filterCategory = Category.uncategorized
                                } label: {
                                    Label {
                                        Text(langManager.translate("uncategorized"))
                                    } icon: {
                                        if filterCategory == Category.uncategorized {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                Divider()
                                ForEach(categories) { category in
                                    Button {
                                        filterCategory = category.name ?? Category.uncategorized
                                    } label: {
                                        Label {
                                            Text(category.name ?? langManager.translate("uncategorized"))
                                        } icon: {
                                            if (category.name ?? Category.uncategorized) == filterCategory {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                filterButtonLabel(icon: "folder", title: filterCategory == Category.all ? langManager.translate("category") : (filterCategory == Category.uncategorized ? langManager.translate("uncategorized") : filterCategory))
                               .foregroundStyle(.secondary)
                            }
                             .background(Color.black.opacity(0.50))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(maxWidth: .infinity)
                            
                            // Tags Picker
                            Menu {
                                Button {
                                    filterTag = nil
                                } label: {
                                    Label {
                                        Text(langManager.translate("all_tags"))
                                    } icon: {
                                        if filterTag == nil {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                Divider()
                                ForEach(allTags) { tag in
                                    Button {
                                        filterTag = tag.name
                                    } label: {
                                        Label {
                                            Text(tag.name ?? langManager.translate("tags"))
                                        } icon: {
                                            if filterTag == tag.name {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                filterButtonLabel(icon: "tag", title: filterTag ?? langManager.translate("tags"))
                            }
                             .background(Color.black.opacity(0.50))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(maxWidth: .infinity)
                            
                            // Status Picker
                            Menu {
                                ForEach(NoteStatusFilter.allCases) { status in
                                    Button {
                                        onStatusChange(status)
                                    } label: {
                                        Label {
                                            Text(status.title)
                                        } icon: {
                                            if statusFilter == status {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                filterButtonLabel(icon: statusFilterIcon, title: statusFilter.title)
                            }
                             .background(Color.black.opacity(0.50))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .foregroundStyle(.secondary)
                        .accentColor(.secondary)
                }
            }
            .padding(.vertical, 4)
            .accentColor(.secondary) // Force secondary tint for menus
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.4))
            )
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            // Delete All Button
            if statusFilter == .deleted && !filteredNotes.isEmpty {
                Button {
                    showDeleteAllAlert = true
                } label: {
                    Text("Delete All")
                        .font(.system(size: langManager.scaledFontSize(12), weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Content area
            if filteredNotes.isEmpty {
                VStack {
                    Spacer()
                    ContentUnavailableView {
                        Label(searchText.isEmpty ? langManager.translate("no_notes") : langManager.translate("no_results"), systemImage: searchText.isEmpty ? "note.text" : "magnifyingglass")
                    } description: {
                        Text(searchText.isEmpty ? langManager.translate("create_first_note") : langManager.translate("search_no_results"))
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredNotes) { note in
                        SidebarNoteRow(note: note, isSelected: selectedNote == note)
                            .tag(note)
                            .listRowSeparator(.hidden)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedNote = note
                            }
                            .contextMenu {
                                if note.status == .deleted {
                                    Button(role: .destructive) {
                                        onDelete(note)
                                    } label: {
                                        Label(langManager.translate("delete_permanently"), systemImage: "trash.fill")
                                    }
                                    Button {
                                        note.status = .saved
                                        note.movedToDeletedOn = nil
                                    } label: {
                                        Label(langManager.translate("restore_to_saved"), systemImage: "arrow.uturn.backward")
                                    }
                                } else {
                                    Button {
                                        note.isPinned.toggle()
                                        try? context.save()
                                    } label: {
                                        Label(note.isPinned ? langManager.translate("unpin_note") : langManager.translate("pin_note"), systemImage: note.isPinned ? "pin.slash" : "pin")
                                    }
                                    
                                    Button(role: .destructive) {
                                        onDelete(note)
                                    } label: {
                                        Label(langManager.translate("move_to_trash"), systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.top, 8)
            }
        }
        .ignoresSafeArea(edges: .top)
        .alert("Delete All Notes?", isPresented: $showDeleteAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                let notesToDelete = filteredNotes
                for note in notesToDelete {
                    onDelete(note)
                }
            }
        } message: {
            Text("Are you sure you want to permanently delete all notes in the trash? This action cannot be undone.")
        }
    }

    @ViewBuilder
    private func filterButtonLabel(icon: String, title: String) -> some View {
        GeometryReader { geo in
            let showLabels = geo.size.width > 250 // Dynamic based on width
            Group {
                if showLabels {
                    VStack(spacing: 4) {
                        LiquidGlassCircle {
                            Image(systemName: icon)
                                .font(.system(size: langManager.scaledFontSize(14), weight: .medium))
                                .foregroundStyle(Color.accentColor)
                        }
                        Text(title)
                            .font(.system(size: langManager.scaledFontSize(10), weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .lineLimit(1)
                    }
                } else {
                    LiquidGlassCircle {
                        Image(systemName: icon)
                            .font(.system(size: langManager.scaledFontSize(16), weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 44)
    }
}

private struct LiquidGlassCircle<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
            .frame(width: 32, height: 32)
            .background(Color.black.opacity(0.05)) // Subtle base color
            .background(.ultraThinMaterial.opacity(0.5)) // 50% translucent glass effect
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .white.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Sidebar Note Row

struct SidebarNoteRow: View {
    let note: RichTextNote
    let isSelected: Bool
    @ObservedObject private var langManager = LanguageManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title
            HStack(alignment: .top) {
                if let emoji = note.emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: langManager.scaledFontSize(14)))
                }
                
                Text(noteTitle)
                    .font(.system(size: langManager.scaledFontSize(13), weight: .semibold))
                    .lineLimit(1)
                
                if note.hasUnviewedReminders || note.isPinned {
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        if note.hasUnviewedReminders {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: langManager.scaledFontSize(11), weight: .bold))
                                .foregroundStyle(.red)
                                .help(langManager.translate("unviewed_reminder"))
                        }
                        
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: langManager.scaledFontSize(10)))
                                .foregroundStyle(Color.accentColor)
                                .rotationEffect(.degrees(45))
                        }
                    }
                    .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)

            // Preview text
            if !previewBody.isEmpty {
                Text(previewBody)
                    .font(.system(size: langManager.scaledFontSize(11)))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 11)
            }

            // Footer: Category + Date
            HStack {
                if let category = note.category {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: category.hexColor ?? "#808080") ?? .gray)
                            .frame(width: 8, height: 8)
                        Text(category.name ?? langManager.translate("uncategorized"))
                    }
                    .font(.system(size: langManager.scaledFontSize(10)))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 11)
                }
                
                if note.status == .temp {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                        Text(langManager.translate("temp"))
                    }
                    .font(.system(size: langManager.scaledFontSize(10)))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 11)

                } else if note.status == .deletingSoon {
                    HStack(spacing: 2) {
                        Image(systemName: "clock.badge.exclamationmark")
                        Text(langManager.translate("deleting_soon"))
                    }
                    .font(.system(size: langManager.scaledFontSize(10)))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 11)
                } else if note.status == .deleted {
                    HStack(spacing: 2) {
                        Image(systemName: "trash")
                        Text(langManager.translate("deleted"))
                    }
                    .font(.system(size: langManager.scaledFontSize(10)))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 11)
                }

                Spacer()

                Text(note.updatedOn.dateDescription)
                    .font(.system(size: langManager.scaledFontSize(10)))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 11)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.black.opacity(0.12))
                .padding(.horizontal, 4)
        )

    }

    private var noteTitle: String {
        // Safety check: if detached, return placeholder
        guard note.modelContext != nil else { return "Deleted Note" }
        
        if !note.title.isEmpty {
            return note.title
        }
        let text = note.previewText.isEmpty ? String(note.text.characters) : note.previewText
        let firstLine = text.components(separatedBy: .newlines).first ?? ""
        return firstLine.isEmpty ? langManager.translate("untitled") : String(firstLine.prefix(50))
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

#if os(macOS)
struct SidebarButton: View {
    @ObservedObject private var langManager = LanguageManager.shared
    var body: some View {
        Button(action: toggleSidebar) {
            Label {
                Text(langManager.translate("toggle_sidebar"))
            } icon: {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: langManager.scaledFontSize(16)))
            }
        }
        .help(langManager.translate("toggle_sidebar"))
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
}
#endif
