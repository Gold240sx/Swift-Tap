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


import SwiftUI
import SwiftData
import Combine
import UniformTypeIdentifiers

extension UTType {
    static let noteBlock = UTType(exportedAs: "com.stewartlynch.noteblock")
}

struct ScrollTopPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct BlockPositionPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

enum ScrollDirection {
    case up
    case down
}

class ScrollManager {
    var scrollProxy: ScrollViewProxy?
    var timer: Timer?
    var direction: ScrollDirection?
    
    func startScrolling(direction: ScrollDirection) {
        guard self.direction != direction || timer == nil else { return }
        self.direction = direction
        print("ScrollManager: Starting scroll \(direction)")
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let direction = self.direction, let proxy = self.scrollProxy else { 
                print("ScrollManager: Timer fired but missing dependencies")
                return 
            }
            
            Task { @MainActor in
                withAnimation(.linear(duration: 0.05)) {
                    switch direction {
                    case .up:
                        proxy.scrollTo("scroll-top", anchor: .top)
                    case .down:
                        proxy.scrollTo("scroll-bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    func stopScrolling() {
        timer?.invalidate()
        timer = nil
        direction = nil
    }
}




struct NotesEditorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var note: RichTextNote
    @State private var moreEditing = false
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var selectedCategory: String = Category.uncategorized
    @State private var editCategories = false
    @State private var editTags = false
    @FocusState private var focusedBlockID: UUID?
    @FocusState private var isTitleFocused: Bool
    @State private var selections: [UUID: AttributedTextSelection] = [:]
    @State private var activeBlockID: UUID?
    @Environment(\.undoManager) var undoManager
    @State private var showJson = false
    @State private var dropState: DropState?
    @State private var blockHeights: [UUID: CGFloat] = [:]
    @State private var blockPositions: [UUID: CGFloat] = [:] // Track block Y positions in scroll view
    @State private var scrollViewHeight: CGFloat = 0
    @State private var draggingBlock: NoteBlock?
    @State private var scrollManager = ScrollManager()
    
    @State private var copiedBlock: NoteBlock? //
    @State private var titleEventMonitor: Any?
    private let saveTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    // MARK: - Main Editor Content
    
    @ViewBuilder
    private var editorTitleField: some View {
        TextField("Page Title", text: $note.title, axis: .vertical)
            .font(.system(size: 34, weight: .bold))
            .textFieldStyle(.plain)
            .padding(.bottom, 8)
            .id("scroll-top")
            .focused($isTitleFocused)
            .onChange(of: note.title) {
                note.updatedOn = Date.now
            }
            .onChange(of: isTitleFocused) { _, newValue in
                if newValue {
                    setupTitleEventMonitor()
                } else {
                    removeTitleEventMonitor()
                }
            }
    }

    @ViewBuilder
    private func blocksList(scrollGeo: GeometryProxy) -> some View {
        ForEach(note.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })) { block in
            blockRowView(for: block)
                .padding(4)
                .background(
                     GeometryReader { geo in
                         let blockGlobalY = geo.frame(in: .global).minY
                         let scrollGlobalY = scrollGeo.frame(in: .global).minY
                         let relativeY = blockGlobalY - scrollGlobalY
                         
                         return Color.clear
                             .preference(key: BlockPositionPreferenceKey.self, value: [block.id: relativeY])
                             .onAppear {
                                 blockHeights[block.id] = geo.size.height
                                 blockPositions[block.id] = relativeY
                             }
                             .onChange(of: geo.size.height) { _, newHeight in
                                 blockHeights[block.id] = newHeight
                             }
                     }
                )
                .overlay(alignment: .top) {
                    if dropState?.targetID == block.id && dropState?.edge == .top {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            .frame(height: 4)
                            .padding(.top, -6)
                    }
                }
                .overlay(alignment: .bottom) {
                    if dropState?.targetID == block.id && dropState?.edge == .bottom {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            .frame(height: 4)
                            .padding(.bottom, -6)
                    }
                }
                .onDrop(of: [UTType.noteBlock], delegate: BlockDropDelegate(
                    block: block,
                    draggingBlock: $draggingBlock,
                    dropState: $dropState,
                    blockHeights: blockHeights,
                    blockPosition: blockPositions[block.id] ?? 0,
                    scrollViewHeight: scrollViewHeight,
                    reorderBlock: handleBlockDrop,
                    onDragNearEdge: { direction in
                        startAutoScroll(direction: direction)
                    },
                    onDragEnded: {
                        stopAutoScroll()
                    },
                    totalBlocks: note.blocks.count
                ))
        }
    }
    
    @ViewBuilder
    private var mainEditorContent: some View {
        ScrollViewReader { proxy in
            GeometryReader { scrollGeo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        editorTitleField
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear {
                                            scrollManager.scrollProxy = proxy
                                        }
                                }
                            )

                        blocksList(scrollGeo: scrollGeo)
                        
                        // Bottom spacer for scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("scroll-bottom")
                    }
                }
                    .coordinateSpace(name: "scroll")
                    .background(
                        Color.clear
                            .contentShape(Rectangle())
                            .onDrop(of: [UTType.noteBlock], delegate: BackgroundDropDelegate(
                                draggingBlock: $draggingBlock,
                                dropState: $dropState,
                                onDragEnded: {
                                    print("NotesEditorView: BackgroundDropDelegate onDragEnded")
                                    stopAutoScroll()
                                }
                            ))
                    )
                .padding(.bottom, 50) // Space at bottom to scroll
                .contentShape(Rectangle())
                .onTapGesture {
                    // Clicking the empty area of the scroll view clears all table selections
                    NotificationCenter.default.post(name: NSNotification.Name("DeselectAllTables"), object: nil)
                    focusedBlockID = nil
                }
                .onChange(of: draggingBlock) { _, newValue in
                    if newValue == nil {
                        stopAutoScroll()
                    }
                }
                .onPreferenceChange(BlockPositionPreferenceKey.self) { positions in
                    // Update block positions continuously during scrolling
                    for (id, position) in positions {
                        blockPositions[id] = position
                    }
                }
                .onAppear {
                    scrollViewHeight = scrollGeo.size.height
                    scrollManager.scrollProxy = proxy
                }
                .onChange(of: scrollGeo.size.height) { _, newHeight in
                    scrollViewHeight = newHeight
                }
            }
        }
    
    }

    private func startAutoScroll(direction: ScrollDirection?) {
        if let direction = direction {
            scrollManager.startScrolling(direction: direction)
        } else {
            scrollManager.stopScrolling()
        }
    }
    
    private func stopAutoScroll() {
        scrollManager.stopScrolling()
    }
    

    

    var currentText: Binding<AttributedString> {
        Binding(
            get: {
                if let id = activeBlockID, let block = note.blocks.first(where: { $0.id == id }) {
                    return block.text ?? ""
                }
                return ""
            },
            set: { newValue in
                if let id = activeBlockID, let block = note.blocks.first(where: { $0.id == id }) {
                    // Store text directly without transformation to preserve selection
                    // Colors are already properly set (intentColor + adaptive foregroundColor)
                    // by MoreFormattingView when the user picks a color
                    block.text = newValue
                }
            }
        )
    }

    var currentSelection: Binding<AttributedTextSelection> {
        Binding(
            get: {
                if let id = activeBlockID {
                    return selections[id] ?? AttributedTextSelection()
                }
                return AttributedTextSelection()
            },
            set: { newValue in
                if let id = activeBlockID {
                    selections[id] = newValue
                }
            }
        )
    }
    
    /// Recursively faults in all attributes of a block and its nested blocks
    private func faultInBlockAttributes(_ block: NoteBlock) {
        // Force fault resolution by accessing attributes
        _ = block.id
        _ = block.text
        _ = block.type
        _ = block.orderIndex
        _ = block.typeString
        
        // Deep fault for each block type content
        if let table = block.table {
            _ = table.id
            _ = table.title
            _ = table.rowCount
            _ = table.columnCount
            for cell in table.cells {
                _ = cell.id
                _ = cell.content
                _ = cell.row
                _ = cell.column
            }
        }
        
        if let codeBlock = block.codeBlock {
            _ = codeBlock.id
            _ = codeBlock.code
            _ = codeBlock.languageString
            _ = codeBlock.themeString
        }
        
        if let imageData = block.imageData {
            _ = imageData.id
            _ = imageData.urlString
            _ = imageData.altText
        }
        
        if let columnData = block.columnData {
            _ = columnData.id
            _ = columnData.columnCount
            for column in columnData.columns {
                _ = column.id
                _ = column.orderIndex
                _ = column.widthRatio
                for nestedBlock in column.blocks {
                    faultInBlockAttributes(nestedBlock)
                }
            }
        }
        
        if let listData = block.listData {
            _ = listData.id
            _ = listData.listTypeString
            for item in listData.items {
                _ = item.id
                _ = item.text
                _ = item.isChecked
                _ = item.orderIndex
            }
        }
        
        if let bookmarkData = block.bookmarkData {
            _ = bookmarkData.id
            _ = bookmarkData.urlString
            _ = bookmarkData.title
            _ = bookmarkData.descriptionText
        }
        
        if let filePathData = block.filePathData {
            _ = filePathData.id
            _ = filePathData.pathString
            _ = filePathData.displayName
        }
        
        // Handle nested blocks in accordions
        if let accordion = block.accordion {
            _ = accordion.id
            _ = accordion.heading
            _ = accordion.level
            _ = accordion.levelString
            _ = accordion.isExpanded
            for nestedBlock in accordion.contentBlocks {
                faultInBlockAttributes(nestedBlock)
            }
        }
    }
    
    private func deleteNoteSafely() {
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
        try? context.save()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0){
            mainEditorContent
        }
        .padding([.horizontal, .bottom])
            #if os(iOS)
            .toolbarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if note.blocks.isEmpty || (note.blocks.count == 1 && note.blocks.first?.text?.characters.isEmpty == true) {
                        deleteNoteSafely()
                    }
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                }
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Section("Purpose") {
                        statusSelectionView
                    }
                    
                    Section("Organization") {
                        categorySelectionView
                        
                        Button {
                            editCategories.toggle()
                        } label: {
                            Label("Manage Categories", systemImage: "square.and.pencil")
                        }
                        
                        Button {
                            editTags.toggle()
                        } label: {
                            Label("Manage Tags", systemImage: "tag")
                        }
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.white)
                }
            }
            #endif

            #if os(iOS)
            ToolbarItemGroup(placement: .keyboard) {
                Group {
                    FormatStyleButtons(text: currentText, selection: currentSelection)
                    Spacer()
                    Button {
                        moreEditing.toggle()
                    } label: {
                        Image(systemName: "textformat.alt")
                    }
                    Button {
                        focusedBlockID = nil
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                }
                .disabled(focusedBlockID == nil)
            }
            #else
            ToolbarItemGroup(placement: .primaryAction) {
                FormatStyleButtons(text: currentText, selection: currentSelection)
                Button {
                    moreEditing.toggle()
                } label: {
                    Image(systemName: "textformat.alt")
                }
            }

            ToolbarItemGroup(placement: .secondaryAction) {
                Button {
                    showJson.toggle()
                } label: {
                    Image(systemName: "curlybraces")
                }
                .help("JSON Output")

                .popover(isPresented: $showJson) {
                    JsonOutputView(note: note)
                        .frame(width: 500, height: 600)
                }
            }
            #endif
        }
        .onChange(of: focusedBlockID) { _, newValue in
            if let newValue {
                activeBlockID = newValue
            }
        }
        #if os(iOS)
        .sheet(isPresented: $moreEditing) {
            MoreFormattingView(text: currentText, selection: currentSelection)
                .presentationDetents([.height(200)])
        }
        #else
        .popover(isPresented: $moreEditing) {
            MoreFormattingView(text: currentText, selection: currentSelection)
                .frame(width: 400, height: 250)
        }
        #endif
        .onChange(of: note.blocks) {
            note.updatedOn = Date.now
        }
        .onAppear {
            // Run migration if needed
            NoteMigrationHelper.migrateIfNecessary(note: note, context: context)

            // Auto-focus first text block if nothing is focused
            if focusedBlockID == nil {
                if let firstTextBlock = note.blocks.sorted(by: { $0.orderIndex < $1.orderIndex }).first(where: { $0.type == .text }) {
                    focusedBlockID = firstTextBlock.id
                    activeBlockID = firstTextBlock.id
                }
            } else {
                activeBlockID = focusedBlockID
            }
        }
        .onReceive(saveTimer) { _ in
            if context.hasChanges {
                try? context.save()
            }
        }
        .onAppear {
            syncUndoManager()
        }
        .onDisappear {
            removeTitleEventMonitor()
        }
        .onChange(of: undoManager) {
            syncUndoManager()
        }
         // Paste without cursor support
        .onPasteCommand(of: [.text, .plainText, UTType.utf8PlainText]) { providers in
             pasteAtEnd(providers)
        }
        #if os(iOS)
        .sheet(isPresented: $editCategories) {
            CategoriesView()
        }
        .sheet(isPresented: $editTags) {
            TagsSelectionView(note: note)
        }
        #else
        .popover(isPresented: $editCategories) {
            CategoriesView()
                .frame(width: 400, height: 500)
        }
        .popover(isPresented: $editTags) {
            TagsSelectionView(note: note)
                .frame(width: 400, height: 500)
        }
        #endif
        .popover(item: $activeElementPopover) { item in
            switch item {
            case .table:
                TableGridPicker(selectedRows: .constant(0), selectedCols: .constant(0)) { rows, cols in
                    insertTable(rows: rows, cols: cols)
                    activeElementPopover = nil
                }
            case .accordion:
                AccordionPicker { level in
                    insertAccordion(level: level)
                    activeElementPopover = nil
                }
            case .image:
                ImageInsertSheet(isPresented: Binding(
                    get: { activeElementPopover == .image },
                    set: { if !$0 { activeElementPopover = nil } }
                )) { url, alt, width, height in
                    insertImage(url: url, alt: alt, width: width, height: height)
                }
            }
        }
    }
    
    private func pasteAtEnd(_ providers: [NSItemProvider]) {
        guard focusedBlockID == nil else { return } // Let default handler handle if focused
        
        for provider in providers {
            if provider.canLoadObject(ofClass: String.self) {
                provider.loadObject(ofClass: String.self) { string, _ in
                    if let text = string {
                        DispatchQueue.main.async {
                            let sorted = note.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })
                            let newIndex = sorted.count
                            let newBlock = NoteBlock(orderIndex: newIndex, text: AttributedString(text), type: .text)
                            note.blocks.append(newBlock)
                            context.insert(newBlock)
                            try? context.save()
                        }
                    }
                }
            }
        }
    }


    // MARK: - Purpose View
    
    @ViewBuilder
    private var statusSelectionView: some View {
        Picker("Purpose", selection: Binding(
            get: { note.status },
            set: { newStatus in
                note.status = newStatus
                if newStatus == .deleted {
                    note.movedToDeletedOn = Date.now
                } else {
                    note.movedToDeletedOn = nil
                }
                try? context.save()
            }
        )) {
            ForEach(RichTextNote.NoteStatus.allCases, id: \.self) { status in
                Label(status.rawValue.capitalized, systemImage: status == .temp ? "clock" : (status == .deleted ? "trash" : "checkmark.circle"))
                    .tag(status)
            }
        }
    }
    
    @ViewBuilder
    private var expirationInfoView: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
            Text("Temp")
                .fontWeight(.bold)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.15))
        .foregroundStyle(.orange)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var categorySelectionView: some View {
        Picker("Category", selection: $selectedCategory) {
            Text(Category.uncategorized).tag(Category.uncategorized)
            ForEach(categories) { category in
                Text(category.name).tag(category.name)
            }
        }
        .onChange(of: selectedCategory) {
            if let category = categories.first(where: {$0.name == selectedCategory}) {
                note.category = category
            } else {
                note.category = nil
            }
            try? context.save()
        }
        .onAppear {
            if let category = note.category {
                selectedCategory = category.name
            }
        }
    }

    // MARK: - Block Row View with Drag Handle

    @ViewBuilder
    private func blockRowView(for block: NoteBlock) -> some View {
        BlockRowHoverContainer(block: block) { isHovered in
            HStack(alignment: .top, spacing: 6) {
                // Block controls with hover state
                BlockControlsView(
                    block: block,
                    draggingBlock: $draggingBlock,
                    copiedBlock: copiedBlock,
                    isHovered: isHovered,
                    onInsertTextBlockAfter: { insertTextBlockAfter($0) },
                    onInsertTableAfter: { block, rows, cols in insertTableAfterBlock(block, rows: rows, cols: cols) },
                    onInsertAccordionAfter: { block, level in insertAccordionAfterBlock(block, level: level) },
                    onInsertImageAfter: { insertImageAfterBlock($0) },
                    onInsertCodeBlockAfter: { insertCodeBlockAfterBlock($0) },
                    onInsertQuoteAfter: { insertQuoteAfterBlock($0) },
                    onInsertColumnsAfter: { insertColumnsAfterBlock($0, ratios: $1) },
                    onInsertListAfter: { insertListAfterBlock($0, type: $1) },
                    onInsertFilePathAfter: { insertFilePathAfterBlock($0) },
                    onDuplicate: { duplicateBlock($0) },
                    onCopy: { copyBlock($0) },
                    onCut: { cutBlock($0) },
                    onPasteAfter: { pasteBlockAfter($0) },
                    onDelete: { removeBlock($0) },
                    onSelectContent: { selectBlockContent($0) }
                )

                // Block content
                blockContentView(for: block)
            }
        }
    }
    
    @ViewBuilder
    private func blockContentView(for block: NoteBlock) -> some View {
        if block.type == .text {
                    TextBlockView(
                        block: block,
                        selection: Binding(
                            get: { selections[block.id] ?? AttributedTextSelection() },
                            set: { selections[block.id] = $0 }
                        ),
                        focusState: $focusedBlockID,
                        onDelete: {
                            removeBlock(block)
                        },
                        onMerge: {
                            mergeWithPreviousBlock(block)
                        },
                        onExtractSelection: {
                            extractSelection(from: block)
                        },
                        onInsertBookmark: { url in
                            insertBookmark(url: url, afterBlock: block)
                        }
                    )
                } else if let listData = block.listData {
                    ListBlockView(
                        listData: listData,
                        selections: $selections,
                        focusState: $focusedBlockID,
                        onDelete: {
                            removeBlock(block)
                        }
                    )
                } else if let table = block.table {
                    TableEditorView(table: table, note: note, onDelete: {
                        removeBlock(block)
                    })
                    .contextMenu {
                        Button(role: .destructive) {
                            removeBlock(block)
                        } label: {
                            Label("Delete Table", systemImage: "trash")
                        }
                    }
                    .onTapGesture {
                        // Clicking a table should deselect other tables
                        NotificationCenter.default.post(name: NSNotification.Name("DeselectAllTables"), object: table.id)
                        focusedBlockID = nil
                    }
                } else if let accordion = block.accordion {
                    AccordionBlockView(
                        accordion: accordion,
                        headingSelection: Binding(
                            get: { selections[accordion.id] ?? AttributedTextSelection() },
                            set: { selections[accordion.id] = $0 }
                        ),
                        selections: $selections,
                        headingFocusID: accordion.id,
                        focusState: $focusedBlockID,
                        note: note,
                        onDelete: {
                            removeBlock(block)
                        },
                        onInsertTable: { targetAccordion, rows, cols in
                            insertTableInAccordion(targetAccordion, rows: rows, cols: cols)
                        },
                        onInsertAccordion: { targetAccordion, level in
                            insertAccordionInAccordion(targetAccordion, level: level)
                        },
                        onInsertCodeBlock: { targetAccordion in
                            insertCodeBlockInAccordion(targetAccordion)
                        },
                        onRemoveBlock: { nestedBlock in
                            removeBlockFromAccordion(nestedBlock)
                        },
                        onMergeNestedBlock: { nestedBlock, accordion in
                            mergeNestedBlock(nestedBlock, in: accordion)
                        },
                        onDropAction: { dragged, target, edge in
                            handleBlockDrop(dragged: dragged, target: target, edge: edge)
                        },
                        onInsertTextBlockAfter: { nestedBlock, targetAccordion in
                            insertTextBlockAfterInAccordion(nestedBlock, accordion: targetAccordion)
                        },
                        onInsertTableAfter: { nestedBlock, targetAccordion, rows, cols in
                            insertTableAfterInAccordion(nestedBlock, accordion: targetAccordion, rows: rows, cols: cols)
                        },
                        onInsertAccordionAfter: { nestedBlock, targetAccordion, level in
                            insertAccordionAfterInAccordion(nestedBlock, accordion: targetAccordion, level: level)
                        },
                        onInsertCodeBlockAfter: { nestedBlock, accordion in
                            insertCodeBlockAfterInAccordion(nestedBlock, accordion: accordion)
                        },
                        onInsertQuoteAfter: { block, accordion in
                            self.insertQuoteAfterBlockInAccordion(block, accordion: accordion)
                        },
                        onInsertListAfter: { nestedBlock, accordion, type in
                            insertListAfterInAccordion(nestedBlock, accordion: accordion, type: type)
                        },
                        onInsertFilePathAfter: { nestedBlock, targetAccordion in
                            insertFilePathAfterInAccordion(nestedBlock, accordion: targetAccordion)
                        },
                        onCopyBlock: { nestedBlock in
                            copyBlockInAccordion(nestedBlock)
                        },
                        onCutBlock: { nestedBlock in
                            cutBlockInAccordion(nestedBlock)
                        },
                        onPasteBlockAfter: { nestedBlock, targetAccordion in
                            pasteBlockAfterInAccordion(nestedBlock, accordion: targetAccordion)
                        },
                        copiedBlock: copiedBlock,
                        draggingBlock: $draggingBlock
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            removeBlock(block)
                        } label: {
                            Label("Delete Accordion", systemImage: "trash")
                        }
                    }
                } else if let codeBlock = block.codeBlock {
                    CodeBlockView(
                        codeBlock: codeBlock,
                        note: note,
                        onDelete: {
                            removeBlock(block)
                        }
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            removeBlock(block)
                        } label: {
                            Label("Delete Code Block", systemImage: "trash")
                        }
                    }
                } else if block.type == .quote {
                    QuoteBlockView(
                        block: block,
                        selection: Binding(
                            get: { selections[block.id] ?? AttributedTextSelection() },
                            set: { selections[block.id] = $0 }
                        ),
                        focusState: $focusedBlockID,
                        onDelete: {
                            removeBlock(block)
                        },
                        onMerge: {
                            mergeWithPreviousBlock(block)
                        }
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            removeBlock(block)
                        } label: {
                            Label("Delete Quote", systemImage: "trash")
                        }
                    }
                } else if let imageData = block.imageData {
                    ImageBlockView(
                        imageData: imageData,
                        onDelete: {
                            removeBlock(block)
                        }
                    )
                } else if let bookmarkData = block.bookmarkData {
                    BookmarkBlockView(
                        bookmarkData: bookmarkData,
                        onDelete: {
                            removeBlock(block)
                        }
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            removeBlock(block)
                        } label: {
                            Label("Delete Bookmark", systemImage: "trash")
                        }
                    }
                } else if let filePathData = block.filePathData {
                    FilePathBlockView(
                        filePathData: filePathData,
                        onDelete: {
                            removeBlock(block)
                        }
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            removeBlock(block)
                        } label: {
                            Label("Delete File Link", systemImage: "trash")
                        }
                    }
                } else if let columnData = block.columnData {
                    ColumnBlockView(
                        columnData: columnData,
                        selections: $selections,
                        focusState: $focusedBlockID,
                        note: note,
                        onDelete: {
                            removeBlock(block)
                        },
                        onInsertTable: { column, rows, cols in
                             insertTableInColumn(column, rows: rows, cols: cols)
                        },
                        onInsertAccordion: { column, level in
                             insertAccordionInColumn(column, level: level)
                        },
                        onInsertCodeBlock: { column in
                             insertCodeBlockInColumn(column)
                        },
                        onInsertFilePath: { column in
                             insertFilePathInColumn(column)
                        },
                        onRemoveBlock: { nestedBlock in
                             removeBlockFromColumn(nestedBlock)
                        },
                        onMergeNestedBlock: { nestedBlock, column in
                             mergeNestedBlockInColumn(nestedBlock, in: column)
                        },
                        onDropAction: { dragged, target, edge in
                             handleBlockDrop(dragged: dragged, target: target, edge: edge)
                        },
                        onInsertTextBlockAfter: { nestedBlock, column in
                            insertTextBlockAfterInColumn(nestedBlock, column: column)
                        },
                        onInsertTableAfter: { nestedBlock, column, rows, cols in
                            insertTableAfterInColumn(nestedBlock, column: column, rows: rows, cols: cols)
                        },
                        onInsertAccordionAfter: { nestedBlock, column, level in
                            insertAccordionAfterInColumn(nestedBlock, column: column, level: level)
                        },
                        onInsertCodeBlockAfter: { block, column in
                            self.insertCodeBlockAfterInColumn(block, column: column)
                        },
                        onInsertQuoteAfter: { block, column in
                            self.insertQuoteAfterBlockInColumn(block, column)
                        },
                        onInsertListAfter: { block, column, type in
                            insertListAfterInColumn(block, column: column, type: type)
                        },
                        onInsertFilePathAfter: { block, column in
                            insertFilePathAfterInColumn(block, column: column)
                        },
                        onCopyBlock: { nestedBlock in
                            copyBlockInColumn(nestedBlock)
                        },
                        onCutBlock: { nestedBlock in
                            cutBlockInColumn(nestedBlock)
                        },
                        onPasteBlockAfter: { nestedBlock, column in
                            pasteBlockAfterInColumn(nestedBlock, column: column)
                        },
                        onInsertBookmark: { url, block in
                            insertBookmark(url: url, afterBlock: block)
                        },
                        copiedBlock: copiedBlock,
                        onInsertTableInAccordion: { accordion, rows, cols in
                             insertTableInAccordion(accordion, rows: rows, cols: cols)
                        },
                        onInsertAccordionInAccordion: { parent, level in
                             insertAccordionInAccordion(parent, level: level)
                        },
                        onInsertCodeBlockInAccordion: { accordion in
                             insertCodeBlockInAccordion(accordion)
                        },
                        onRemoveBlockFromAccordion: { block in
                             removeBlockFromAccordion(block)
                        },
                        onMergeNestedBlockInAccordion: { block, accordion in
                             mergeNestedBlock(block, in: accordion)
                        },
                        onDropActionInAccordion: { dragged, target, edge in
                             handleBlockDrop(dragged: dragged, target: target, edge: edge)
                        },
                        onInsertTextBlockAfterInAccordion: { block, accordion in
                             insertTextBlockAfterInAccordion(block, accordion: accordion)
                        },
                        onInsertTableAfterInAccordion: { block, accordion, rows, cols in
                             insertTableAfterInAccordion(block, accordion: accordion, rows: rows, cols: cols)
                        },
                        onInsertAccordionAfterInAccordion: { block, accordion, level in
                             insertAccordionAfterInAccordion(block, accordion: accordion, level: level)
                        },
                        onInsertCodeBlockAfterInAccordion: { block, accordion in
                             insertCodeBlockAfterInAccordion(block, accordion: accordion)
                        },
                        onInsertListAfterInAccordion: { block, accordion, type in
                             insertListAfterInAccordion(block, accordion: accordion, type: type)
                        },
                        onInsertFilePathAfterInAccordion: { block, accordion in
                             insertFilePathAfterInAccordion(block, accordion: accordion)
                        },
                        onCopyBlockInAccordion: { block in
                             copyBlockInAccordion(block)
                        },
                        onCutBlockInAccordion: { block in
                             cutBlockInAccordion(block)
                        },
                        onPasteBlockAfterInAccordion: { block, accordion in
                             pasteBlockAfterInAccordion(block, accordion: accordion)
                        },
                        onInsertQuoteAfterInAccordion: { block, accordion in
                             self.insertQuoteAfterBlockInAccordion(block, accordion: accordion)
                        },
                        draggingBlock: $draggingBlock
                    )
                }
    }

    private func syncUndoManager() {
        if let undoManager {
            context.undoManager = undoManager
            context.undoManager?.levelsOfUndo = 100
        }
    }

    @State private var activeElementPopover: ElementPopover?
    @State private var insertionTargetBlockID: UUID?  // Captured when popover opens

    enum ElementPopover: Identifiable {
        case table
        case accordion
        case image
        
        var id: Self { self }
    }

    private func findBlock(id: UUID) -> NoteBlock? {
        // BFS or DFS search
        // Since we don't have a flat list, we search recursively
        // A stack-based iterative search would be safer for deep nesting, but recursive is easier for now.
        return findBlockRecursive(in: note.blocks, id: id)
    }
    
    private func findBlockRecursive(in blocks: [NoteBlock], id: UUID) -> NoteBlock? {
        for block in blocks {
            if block.id == id { return block }
            if let accordion = block.accordion {
                if let found = findBlockRecursive(in: accordion.contentBlocks, id: id) {
                    return found
                }
            }
            if let columnData = block.columnData {
                for column in columnData.columns {
                    if let found = findBlockRecursive(in: column.blocks, id: id) {
                        return found
                    }
                }
            }
        }
        return nil
    }

    /// Helper to insert a block at the root level, handling text splitting if necessary
    private func insertBlockAtRoot(_ createBlock: (Int) -> NoteBlock) {
        let sortedBlocks = note.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })
        var targetOrderIndex = sortedBlocks.count

        // Use insertionTargetBlockID (captured when popover opens), fall back to activeBlockID or focusedBlockID
        let effectiveFocusedID = insertionTargetBlockID ?? activeBlockID ?? focusedBlockID

        // Clear the insertion target after using it
        defer { insertionTargetBlockID = nil }

        if let focusedID = effectiveFocusedID,
           let focusedBlock = sortedBlocks.first(where: { $0.id == focusedID }) {

            // Check if focused block is an empty text block - replace it
            if isTextBlockEmpty(focusedBlock) {
                let orderIndex = focusedBlock.orderIndex

                // Remove the empty text block
                note.blocks.removeAll { $0.id == focusedBlock.id }
                context.delete(focusedBlock)

                // Insert new block at same position
                let newBlock = createBlock(orderIndex)
                note.blocks.append(newBlock)
                context.insert(newBlock)

                try? context.save()
                return
            }

            // Default: Insert after focused block
            targetOrderIndex = focusedBlock.orderIndex + 1

            // Attempt to split text block
            if let selection = selections[focusedID],
               let text = focusedBlock.text,
               !text.characters.isEmpty {

                var splitIndex: AttributedString.Index?
                switch selection.indices(in: text) {
                case .insertionPoint(let index):
                    splitIndex = index
                case .ranges(let rangeSet):
                    if let firstRange = rangeSet.ranges.first {
                        splitIndex = firstRange.lowerBound
                    }
                }

                if let index = splitIndex, index < text.endIndex {
                     // Split text logic aligns with original insertTable implementation
                     let prefix = text[..<index]
                     let suffix = text[index...]

                     // 1. Update focused block
                     focusedBlock.text = AttributedString(prefix)

                     // Shift all blocks >= targetOrderIndex by 2 (one for new block, one for suffix)
                     for block in note.blocks where block.orderIndex >= targetOrderIndex {
                         block.orderIndex += 2
                     }

                     // Create and insert NewBlock
                     let newBlock = createBlock(targetOrderIndex)
                     note.blocks.append(newBlock)
                     context.insert(newBlock)

                     // Create and insert SuffixBlock
                     let suffixBlock = NoteBlock(orderIndex: targetOrderIndex + 1, text: AttributedString(suffix), type: .text)
                     note.blocks.append(suffixBlock)
                     context.insert(suffixBlock)

                     try? context.save()
                     return
                }
            }
        }

        // Fallback: No split, just insert at targetOrderIndex
        for block in note.blocks where block.orderIndex >= targetOrderIndex {
            block.orderIndex += 1
        }

        let newBlock = createBlock(targetOrderIndex)
        note.blocks.append(newBlock)
        context.insert(newBlock)

        try? context.save()
    }

    private func insertCodeBlock() {
        let effectiveFocusedID = insertionTargetBlockID ?? activeBlockID ?? focusedBlockID
        if let focusedID = effectiveFocusedID,
           let focusedBlock = findBlock(id: focusedID),
           let parentAccordion = focusedBlock.parentAccordion {
            insertCodeBlockInAccordion(parentAccordion)
            return
        }

        // Root insertion logic
        let language = Language(rawValue: note.lastUsedCodeLanguage) ?? .swift
        let newCodeBlock = CodeBlockData(language: language)
        context.insert(newCodeBlock)

        insertBlockAtRoot { index in
             NoteBlock(orderIndex: index, codeBlock: newCodeBlock, type: .code)
        }
    }

    private func insertQuote() {
        insertBlockAtRoot { index in
            let block = NoteBlock(orderIndex: index, text: "", type: .quote)
            // Focus the new quote block
            DispatchQueue.main.async {
                self.focusedBlockID = block.id
            }
            return block
        }
    }

    private func insertTable(rows: Int, cols: Int) {
        let effectiveFocusedID = insertionTargetBlockID ?? activeBlockID ?? focusedBlockID
        if let focusedID = effectiveFocusedID,
           let focusedBlock = findBlock(id: focusedID),
           let parentAccordion = focusedBlock.parentAccordion {
            insertTableInAccordion(parentAccordion, rows: rows, cols: cols)
            return
        }

        let newTable = TableData(rowCount: rows, columnCount: cols)
        context.insert(newTable)

        insertBlockAtRoot { index in
            NoteBlock(orderIndex: index, table: newTable, type: .table)
        }
    }

    private func extractSelection(from block: NoteBlock) {
        guard let text = block.text, !text.characters.isEmpty,
              let selection = selections[block.id] else { return }
        
        var selectedRange: Range<AttributedString.Index>?
        
        // Simple case for ranges
        if case .ranges(let rangeSet) = selection.indices(in: text) {
             selectedRange = rangeSet.ranges.first
        }
        
        guard let range = selectedRange else { return }
        
        // Split logic
        let prefix = text[..<range.lowerBound]
        let selectedText = text[range]
        let suffix = text[range.upperBound...]
        
        let hasPrefix = !prefix.characters.isEmpty
        let hasSuffix = !suffix.characters.isEmpty
        
        // Base order index
        let baseIndex = block.orderIndex
        
        var parts: [AttributedString] = []
        if hasPrefix { parts.append(AttributedString(prefix)) }
        parts.append(AttributedString(selectedText))
        if hasSuffix { parts.append(AttributedString(suffix)) }
        
        // Reuse current block for the first part? 
        // Or cleaner: delete current and insert 3 new ones?
        // Updating current preserves ID if possible, which is good for focus but tricky if prefix is empty.
        // If prefix is empty, the first part is the Selection. So current block becomes the selected text block.
        
        let neededSlots = parts.count - 1
        
        if neededSlots > 0 {
            for b in note.blocks where b.orderIndex > baseIndex {
                b.orderIndex += neededSlots
            }
        }
        
        // Update first block
        if let firstPart = parts.first {
            block.text = firstPart
        }
        
        // Create subsequent blocks
        for (offset, part) in parts.dropFirst().enumerated() {
            let newBlock = NoteBlock(orderIndex: baseIndex + 1 + offset, text: part, type: .text)
            note.blocks.append(newBlock)
            context.insert(newBlock)
        }
        
        try? context.save()
    }

    private func insertAccordion(level: AccordionData.HeadingLevel) {
        let effectiveFocusedID = insertionTargetBlockID ?? activeBlockID ?? focusedBlockID
        if let focusedID = effectiveFocusedID,
           let focusedBlock = findBlock(id: focusedID),
           let parentAccordion = focusedBlock.parentAccordion {
            insertAccordionInAccordion(parentAccordion, level: level)
            return
        }

        let newAccordion = AccordionData(level: level)
        context.insert(newAccordion)
        // Create initial text block inside the accordion
        let initialTextBlock = NoteBlock(orderIndex: 0, text: "", type: .text)
        initialTextBlock.parentAccordion = newAccordion
        newAccordion.contentBlocks.append(initialTextBlock)
        context.insert(initialTextBlock)

        insertBlockAtRoot { index in
            let block = NoteBlock(orderIndex: index, accordion: newAccordion, type: .accordion)
            // Focus the new accordion's heading
            focusedBlockID = newAccordion.id
            return block
        }
    }

    // MARK: - Nested Block Operations

    /// Insert a table inside an accordion
    private func insertTableInAccordion(_ accordion: AccordionData, rows: Int, cols: Int) {
        let newTable = TableData(rowCount: rows, columnCount: cols)
        context.insert(newTable)

        let sortedBlocks = accordion.contentBlocks.sorted(by: { $0.orderIndex < $1.orderIndex })
        let targetOrderIndex = sortedBlocks.count

        // Shift subsequent blocks
        for block in accordion.contentBlocks where block.orderIndex >= targetOrderIndex {
            block.orderIndex += 1
        }

        let tableBlock = NoteBlock(orderIndex: targetOrderIndex, table: newTable, type: .table)
        tableBlock.parentAccordion = accordion
        accordion.contentBlocks.append(tableBlock)
        context.insert(tableBlock)

        try? context.save()
    }

    /// Insert a nested accordion inside another accordion
    private func insertAccordionInAccordion(_ parentAccordion: AccordionData, level: AccordionData.HeadingLevel) {
        let newAccordion = AccordionData(level: level)
        context.insert(newAccordion)

        // Create initial text block inside the nested accordion
        let initialTextBlock = NoteBlock(orderIndex: 0, text: "", type: .text)
        initialTextBlock.parentAccordion = newAccordion
        newAccordion.contentBlocks.append(initialTextBlock)
        context.insert(initialTextBlock)

        let sortedBlocks = parentAccordion.contentBlocks.sorted(by: { $0.orderIndex < $1.orderIndex })
        let targetOrderIndex = sortedBlocks.count

        // Shift subsequent blocks
        for block in parentAccordion.contentBlocks where block.orderIndex >= targetOrderIndex {
            block.orderIndex += 1
        }

        let accordionBlock = NoteBlock(orderIndex: targetOrderIndex, accordion: newAccordion, type: .accordion)
        accordionBlock.parentAccordion = parentAccordion
        parentAccordion.contentBlocks.append(accordionBlock)
        context.insert(accordionBlock)

        // Focus the new nested accordion
        focusedBlockID = newAccordion.id

        try? context.save()
    }

    // MARK: - Column Operations
    
    private func insertColumns(ratios: [Double]) {
        // Prevent nesting columns within columns
        if let focusedID = focusedBlockID,
           let focusedBlock = findBlock(id: focusedID),
           focusedBlock.parentColumn != nil {
            // Block is inside a column - don't allow nested columns
            return
        }

        let count = ratios.count
        print("Inserting \(count) columns with ratios: \(ratios)")
        let newColumnData = ColumnData(columnCount: count)
        
        // Create columns and build the graph first
        for i in 0..<count {
            let col = Column(orderIndex: i, widthRatio: ratios[i])
            col.parentColumnData = newColumnData
            
            // Create initial empty text block in each column
            let textBlock = NoteBlock(orderIndex: 0, text: "", type: .text)
            textBlock.parentColumn = col
            col.blocks.append(textBlock)
            
            newColumnData.columns.append(col)
        }
        
        // Insert the root of the graph
        context.insert(newColumnData)
        print("Inserted ColumnData with \(newColumnData.columns.count) columns.")
        
        insertBlockAtRoot { index in
            let block = NoteBlock(orderIndex: index, columnData: newColumnData, type: .columns)
            // Focus first block of first column
            if let firstCol = newColumnData.columns.sorted(by: {$0.orderIndex < $1.orderIndex}).first,
               let firstBlock = firstCol.blocks.first {
                focusedBlockID = firstBlock.id
            }
            return block
        }
    }
    
    private func insertTableInColumn(_ column: Column, rows: Int, cols: Int) {
        let newTable = TableData(rowCount: rows, columnCount: cols)
        context.insert(newTable)

        let targetOrderIndex = column.blocks.count
        
        let tableBlock = NoteBlock(orderIndex: targetOrderIndex, table: newTable, type: .table)
        tableBlock.parentColumn = column
        column.blocks.append(tableBlock)
        context.insert(tableBlock)
        
        try? context.save()
    }
    
    private func insertAccordionInColumn(_ column: Column, level: AccordionData.HeadingLevel) {
        let newAccordion = AccordionData(level: level)
        context.insert(newAccordion)
        
        let initialTextBlock = NoteBlock(orderIndex: 0, text: "", type: .text)
        initialTextBlock.parentAccordion = newAccordion
        newAccordion.contentBlocks.append(initialTextBlock)
        context.insert(initialTextBlock)
        
        let targetOrderIndex = column.blocks.count
        
        let accordionBlock = NoteBlock(orderIndex: targetOrderIndex, accordion: newAccordion, type: .accordion)
        accordionBlock.parentColumn = column
        column.blocks.append(accordionBlock)
        context.insert(accordionBlock)
        
        focusedBlockID = newAccordion.id
        try? context.save()
    }
    
    private func insertCodeBlockInColumn(_ column: Column) {
        let language = Language(rawValue: note.lastUsedCodeLanguage) ?? .swift
        let newCodeBlock = CodeBlockData(language: language)
        context.insert(newCodeBlock)

        let targetOrderIndex = column.blocks.count

        let codeBlock = NoteBlock(orderIndex: targetOrderIndex, codeBlock: newCodeBlock, type: .code)
        codeBlock.parentColumn = column
        column.blocks.append(codeBlock)
        context.insert(codeBlock)

        try? context.save()
    }

    private func insertFilePathInColumn(_ column: Column) {
        // Use activeBlockID which persists even when focus is lost
        let capturedFocusedID = activeBlockID ?? focusedBlockID

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = "Select a file or folder to link"
        panel.prompt = "Link"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                DispatchQueue.main.async {
                    let filePathData = FilePathData.create(from: url)
                    self.context.insert(filePathData)

                    // Find the focused block fresh from the column
                    let focusedBlock = capturedFocusedID.flatMap { id in
                        column.blocks.first { $0.id == id }
                    }

                    // Check if focused block is an empty text block - replace it
                    if let focusedBlock = focusedBlock,
                       self.isTextBlockEmpty(focusedBlock) {
                        let orderIndex = focusedBlock.orderIndex

                        // Remove the empty text block
                        column.blocks.removeAll { $0.id == focusedBlock.id }
                        self.context.delete(focusedBlock)

                        // Insert at same position
                        let newBlock = NoteBlock(orderIndex: orderIndex, filePathData: filePathData, type: .filePath)
                        newBlock.parentColumn = column
                        column.blocks.append(newBlock)
                        self.context.insert(newBlock)
                    } else if let focusedBlock = focusedBlock {
                        // Insert after focused block
                        let targetIndex = focusedBlock.orderIndex + 1

                        for block in column.blocks where block.orderIndex >= targetIndex {
                            block.orderIndex += 1
                        }

                        let newBlock = NoteBlock(orderIndex: targetIndex, filePathData: filePathData, type: .filePath)
                        newBlock.parentColumn = column
                        column.blocks.append(newBlock)
                        self.context.insert(newBlock)
                    } else {
                        // Append at end
                        let sortedBlocks = column.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })
                        let targetOrderIndex = (sortedBlocks.last?.orderIndex ?? -1) + 1

                        let newBlock = NoteBlock(orderIndex: targetOrderIndex, filePathData: filePathData, type: .filePath)
                        newBlock.parentColumn = column
                        column.blocks.append(newBlock)
                        self.context.insert(newBlock)
                    }

                    try? self.context.save()
                }
            }
        }
    }

    private func removeBlockFromColumn(_ block: NoteBlock) {
        // Remove from parent column's blocks array first
        if let parentColumn = block.parentColumn {
            parentColumn.blocks.removeAll { $0.id == block.id }

            // Re-index remaining blocks
            let sorted = parentColumn.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })
            for (index, b) in sorted.enumerated() {
                b.orderIndex = index
            }
        }

        // Now delete the block
        context.delete(block)
        try? context.save()
    }
    
    private func mergeNestedBlockInColumn(_ block: NoteBlock, in column: Column) {
        // Find previous block in column
        let sorted = column.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })
        guard let index = sorted.firstIndex(where: { $0.id == block.id }), index > 0 else { return }
        
        let prevBlock = sorted[index - 1]
        
        if prevBlock.type == .text && block.type == .text {
            // Check content
        }
        
        // Simple implementation: Just focus previous block
        focusedBlockID = prevBlock.id
        try? context.save()
    }



    /// Insert a code block inside an accordion
    private func insertCodeBlockInAccordion(_ accordion: AccordionData) {
        let language = Language(rawValue: note.lastUsedCodeLanguage) ?? .swift
        let newCodeBlock = CodeBlockData(language: language)
        context.insert(newCodeBlock)

        let sortedBlocks = accordion.contentBlocks.sorted(by: { $0.orderIndex < $1.orderIndex })
        let targetOrderIndex = sortedBlocks.count

        // Shift subsequent blocks
        for block in accordion.contentBlocks where block.orderIndex >= targetOrderIndex {
            block.orderIndex += 1
        }

        let codeBlockItem = NoteBlock(orderIndex: targetOrderIndex, codeBlock: newCodeBlock, type: .code)
        codeBlockItem.parentAccordion = accordion
        accordion.contentBlocks.append(codeBlockItem)
        context.insert(codeBlockItem)

        try? context.save()
    }

    /// Remove a block from its parent accordion
    private func removeBlockFromAccordion(_ block: NoteBlock) {
        guard let parentAccordion = block.parentAccordion else { return }

        // Clear focus if this block is focused
        if focusedBlockID == block.id || activeBlockID == block.id {
            focusedBlockID = nil
            activeBlockID = nil
        }

        faultInBlockAttributes(block)

        let removedOrder = block.orderIndex
        
        // Remove from parent collection first
        parentAccordion.contentBlocks.removeAll(where: { $0.id == block.id })

        // Re-index remaining blocks
        for b in parentAccordion.contentBlocks where b.orderIndex > removedOrder {
            b.orderIndex -= 1
        }

        // Perform deletion
        context.delete(block)
        
        // Ensure the accordion always has at least one element
        if parentAccordion.contentBlocks.isEmpty {
            let emptyBlock = NoteBlock(orderIndex: 0, text: "", type: .text)
            emptyBlock.parentAccordion = parentAccordion
            parentAccordion.contentBlocks.append(emptyBlock)
            context.insert(emptyBlock)
            
            // Focus the new empty block
            DispatchQueue.main.async {
                self.focusedBlockID = emptyBlock.id
            }
        }

        try? context.save()
    }

    private func removeBlock(_ block: NoteBlock) {
        // Clear focus if this block is focused
        if focusedBlockID == block.id || activeBlockID == block.id {
            focusedBlockID = nil
            activeBlockID = nil
        }

        faultInBlockAttributes(block)

        // Capture surrounding blocks before deletion for potential merging
        let sortedBlocks = note.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })
        let removedOrder = block.orderIndex
        
        let prevBlock = sortedBlocks.first(where: { $0.orderIndex == removedOrder - 1 })
        let nextBlock = sortedBlocks.first(where: { $0.orderIndex == removedOrder + 1 })

        // Remove from parent collection
        note.blocks.removeAll(where: { $0.id == block.id })

        // Re‑index remaining blocks
        for b in note.blocks where b.orderIndex > removedOrder {
            b.orderIndex -= 1
        }

        // Delete the block
        context.delete(block)

        // If the removed block was NOT a text block, attempt to merge adjacent text blocks
        if block.type != .text {
            if let prev = prevBlock, let next = nextBlock,
               prev.type == .text, next.type == .text,
               let prevText = prev.text, let nextText = next.text {
                
                // Ensure adjacent blocks are still in the note and valid
                if note.blocks.contains(where: { $0.id == prev.id }) && 
                   note.blocks.contains(where: { $0.id == next.id }) {
                    
                    // Combine the attributed strings
                    var combined = prevText
                    combined.append(AttributedString("\n"))
                    combined.append(nextText)
                    prev.text = combined

                    let nextOrder = next.orderIndex
                    // Remove the next block and shift indices
                    note.blocks.removeAll(where: { $0.id == next.id })
                    context.delete(next)
                    
                    for b in note.blocks where b.orderIndex > nextOrder {
                        b.orderIndex -= 1
                    }
                }
            }
        }

        try? context.save()
    }

    // MARK: - Duplicate, Copy, Paste Block

    private func duplicateBlock(_ block: NoteBlock) {
        let newBlock = BlockCopyHelper.createCopy(from: block, context: context)
        let insertIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in note.blocks where b.orderIndex >= insertIndex {
            b.orderIndex += 1
        }

        newBlock.orderIndex = insertIndex
        note.blocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()

        // Focus the new block
        DispatchQueue.main.async {
            focusedBlockID = newBlock.id
        }
    }

    private func copyBlock(_ block: NoteBlock) {
        copiedBlock = block
    }
    
    private func cutBlock(_ block: NoteBlock) {
        copiedBlock = block
        removeBlock(block)
    }

    private func pasteBlockAfter(_ targetBlock: NoteBlock) {
        guard let source = copiedBlock else { return }

        let newBlock = BlockCopyHelper.createCopy(from: source, context: context)
        let insertIndex = targetBlock.orderIndex + 1

        // Shift subsequent blocks
        for b in note.blocks where b.orderIndex >= insertIndex {
            b.orderIndex += 1
        }

        newBlock.orderIndex = insertIndex
        note.blocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()

        // Focus the new block
        DispatchQueue.main.async {
            focusedBlockID = newBlock.id
        }
    }
    
    // MARK: - Copy/Cut/Paste for Nested Blocks
    
    /// Copies a nested block in an accordion
    private func copyBlockInAccordion(_ block: NoteBlock) {
        copiedBlock = block
    }
    
    /// Cuts a nested block in an accordion
    private func cutBlockInAccordion(_ block: NoteBlock) {
        copiedBlock = block
        removeBlockFromAccordion(block)
    }
    
    /// Pastes a block after a nested block in an accordion
    private func pasteBlockAfterInAccordion(_ targetBlock: NoteBlock, accordion: AccordionData) {
        guard let source = copiedBlock else { return }

        let newBlock = BlockCopyHelper.createCopy(from: source, context: context)
        let insertIndex = targetBlock.orderIndex + 1

        // Shift subsequent blocks
        for b in accordion.contentBlocks where b.orderIndex >= insertIndex {
            b.orderIndex += 1
        }

        newBlock.orderIndex = insertIndex
        newBlock.parentAccordion = accordion
        accordion.contentBlocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()

        // Focus the new block
        DispatchQueue.main.async {
            focusedBlockID = newBlock.id
        }
    }
    
    /// Copies a nested block in a column
    private func copyBlockInColumn(_ block: NoteBlock) {
        copiedBlock = block
    }
    
    /// Cuts a nested block in a column
    private func cutBlockInColumn(_ block: NoteBlock) {
        copiedBlock = block
        removeBlockFromColumn(block)
    }
    
    /// Pastes a block after a nested block in a column
    private func pasteBlockAfterInColumn(_ targetBlock: NoteBlock, column: Column) {
        guard let source = copiedBlock else { return }

        let newBlock = BlockCopyHelper.createCopy(from: source, context: context)
        let insertIndex = targetBlock.orderIndex + 1

        // Shift subsequent blocks
        for b in column.blocks where b.orderIndex >= insertIndex {
            b.orderIndex += 1
        }

        newBlock.orderIndex = insertIndex
        newBlock.parentColumn = column
        column.blocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()

        // Focus the new block
        DispatchQueue.main.async {
            focusedBlockID = newBlock.id
        }
    }

    private func selectBlockContent(_ block: NoteBlock) {
        if block.type == .text {
            // Focus the block
            focusedBlockID = block.id
            // Select all text
            DispatchQueue.main.async {
                 NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            }
        } else {
             focusedBlockID = block.id
        }
    }

    // MARK: - Drag and Drop Reordering

    private func handleBlockDrop(dragged: NoteBlock, target: NoteBlock, edge: DropEdge) {
        guard dragged.id != target.id else { return }

        // 1. Identify Source and Remove
        // We must remove the block from its current location first to simplify insertion logic
        // But we need to know WHERE it was to remove it.
        // It could be in note.blocks OR inside an accordion.
        
        // Remove from Root
        if dragged.parentAccordion == nil && dragged.parentColumn == nil {
            if let index = note.blocks.firstIndex(where: { $0.id == dragged.id }) {
                note.blocks.remove(at: index)
            }
        } else if let oldParent = dragged.parentAccordion {
            // Remove from old Accordion
            if let index = oldParent.contentBlocks.firstIndex(where: { $0.id == dragged.id }) {
                oldParent.contentBlocks.remove(at: index)
            }
        } else if let oldColumn = dragged.parentColumn {
            // Remove from old Column
            if let index = oldColumn.blocks.firstIndex(where: { $0.id == dragged.id }) {
                oldColumn.blocks.remove(at: index)
            }
        }
        
        // 2. Identify Target Destination
        if let targetParent = target.parentAccordion {
            // Target is inside an accordion
            insertBlock(dragged, into: &targetParent.contentBlocks, relativeTo: target, edge: edge)
            dragged.parentAccordion = targetParent
            dragged.parentColumn = nil
        } else if let targetColumn = target.parentColumn {
            // Target is inside a column
            insertBlock(dragged, into: &targetColumn.blocks, relativeTo: target, edge: edge)
            dragged.parentColumn = targetColumn
            dragged.parentAccordion = nil
        } else {
            // Target is in Root
            insertBlock(dragged, into: &note.blocks, relativeTo: target, edge: edge)
            dragged.parentAccordion = nil
            dragged.parentColumn = nil
        }
        
        // 3. Re-index and Save
        // We should re-index the collection we modified.
        // Actually `insertBlock` function below handles re-indexing.
        
        try? context.save()
    }
    
    private func insertBlock(_ block: NoteBlock, into list: inout [NoteBlock], relativeTo target: NoteBlock, edge: DropEdge) {
        // Sort list by orderIndex to ensure correct insertion point
        list.sort(by: { $0.orderIndex < $1.orderIndex })
        
        guard let targetIndex = list.firstIndex(where: { $0.id == target.id }) else {
            // Fallback: Append
            list.append(block)
            reindex(list)
            return
        }
        
        var insertionIndex = targetIndex
        if edge == .bottom {
            insertionIndex += 1
        }
        
        if insertionIndex >= list.count {
            list.append(block)
        } else {
            list.insert(block, at: insertionIndex)
        }
        
        reindex(list)
    }
    
    private func reindex(_ list: [NoteBlock]) {
        for (index, block) in list.enumerated() {
            block.orderIndex = index
        }
    }

    private func mergeWithPreviousBlock(_ block: NoteBlock) {
        let sortedBlocks = note.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })
        guard let currentIndex = sortedBlocks.firstIndex(where: { $0.id == block.id }),
              currentIndex > 0 else { return }
        
        let prevBlock = sortedBlocks[currentIndex - 1]
        
        if prevBlock.type == .text {
            // Merge logic
            if let currentText = block.text, let prevText = prevBlock.text {
                var combined = prevText
                // We append directly
                combined.append(currentText)
                prevBlock.text = combined
                
                // Set focus to previous block
                focusedBlockID = prevBlock.id
                
                // Ideally we would set the cursor position to the join point here
                // but AttributedTextSelection binding api is not exposed easily for setting index.
                // We rely on user tapping or using arrow keys for now, 
                // but at least focus is preserved on the merged block.

                // Remove current block
                removeBlock(block)
                // removeBlock saves context
            }
        }
    }

    private func mergeNestedBlock(_ block: NoteBlock, in accordion: AccordionData) {
        let sortedBlocks = accordion.contentBlocks.sorted(by: { $0.orderIndex < $1.orderIndex })
        guard let currentIndex = sortedBlocks.firstIndex(where: { $0.id == block.id }),
              currentIndex > 0 else { return }
        
        let prevBlock = sortedBlocks[currentIndex - 1]
        
        if prevBlock.type == .text {
            // Merge logic
            if let currentText = block.text, let prevText = prevBlock.text {
                var combined = prevText
                combined.append(currentText)
                prevBlock.text = combined
                
                // Set focus to previous block
                focusedBlockID = prevBlock.id
                
                // Remove current block
                removeBlockFromAccordion(block)
            }
        }
    }

    private func insertImage(url: String, alt: String?, width: Double?, height: Double?) {
        let effectiveFocusedID = insertionTargetBlockID ?? activeBlockID ?? focusedBlockID
        if let focusedID = effectiveFocusedID,
           let focusedBlock = findBlock(id: focusedID),
           let parentAccordion = focusedBlock.parentAccordion {
            insertImageInAccordion(parentAccordion, url: url, alt: alt, width: width, height: height)
            return
        }
        
        // Root insertion
        let newImage = ImageData(urlString: url, width: width, height: height, altText: alt)
        context.insert(newImage)
        
        insertBlockAtRoot { index in
             NoteBlock(orderIndex: index, imageData: newImage, type: .image)
        }
    }
    
    private func insertImageInAccordion(_ accordion: AccordionData, url: String, alt: String?, width: Double?, height: Double?) {
        let newImage = ImageData(urlString: url, width: width, height: height, altText: alt)
        context.insert(newImage)
        
        let sortedBlocks = accordion.contentBlocks.sorted(by: { $0.orderIndex < $1.orderIndex })
        let targetOrderIndex = sortedBlocks.count
        
        // Shift subsequent blocks
        for block in accordion.contentBlocks where block.orderIndex >= targetOrderIndex {
            block.orderIndex += 1
        }
        
        let imageBlock = NoteBlock(orderIndex: targetOrderIndex, imageData: newImage, type: .image)
        imageBlock.parentAccordion = accordion
        accordion.contentBlocks.append(imageBlock)
        context.insert(imageBlock)

        try? context.save()
    }

    private func insertList(type: ListData.ListType) {
        let newListData = ListData(listType: type)
        context.insert(newListData)

        // Create initial empty item
        let initialItem = ListItem(orderIndex: 0, text: "")
        initialItem.parentList = newListData
        newListData.items.append(initialItem)
        context.insert(initialItem)

        insertBlockAtRoot { index in
            let block = NoteBlock(orderIndex: index, listData: newListData, type: .list)
            // Focus the first item
            DispatchQueue.main.async {
                self.focusedBlockID = initialItem.id
            }
            return block
        }
    }

    private func insertBulletList() {
        insertList(type: .bullet)
    }

    private func insertNumberedList() {
        insertList(type: .numbered)
    }

    private func insertCheckboxList() {
        insertList(type: .checkbox)
    }

    // MARK: - File Path Operations

    /// Shows a file picker to select a local file
    private func showFilePathPicker() {
        // Use activeBlockID which persists even when focus is lost (e.g., when clicking toolbar button)
        let capturedFocusedID = activeBlockID ?? focusedBlockID

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = "Select a file or folder to link"
        panel.prompt = "Link"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                DispatchQueue.main.async {
                    self.insertFilePathAtFocusedBlock(url: url, focusedID: capturedFocusedID)
                }
            }
        }
    }

    /// Checks if a text block is effectively empty (only whitespace/newlines)
    private func isTextBlockEmpty(_ block: NoteBlock) -> Bool {
        guard block.type == .text else { return false }
        guard let text = block.text else { return true }
        let plainText = String(text.characters)
        return plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Inserts a file path block at the focused block's position
    private func insertFilePathAtFocusedBlock(url: URL, focusedID: UUID?) {
        let filePathData = FilePathData.create(from: url)
        context.insert(filePathData)

        // Find the current focused block fresh from the model
        guard let focusedID = focusedID,
              let focusedBlock = note.blocks.first(where: { $0.id == focusedID }) else {
            // No focused block at root, check columns
            if let focusedID = focusedID {
                // Search in columns
                for block in note.blocks {
                    if let columnData = block.columnData {
                        for column in columnData.columns {
                            if let colBlock = column.blocks.first(where: { $0.id == focusedID }) {
                                insertFilePathInColumnAtBlock(filePathData: filePathData, focusedBlock: colBlock, column: column)
                                return
                            }
                        }
                    }
                }
            }
            // Fallback: insert at end
            let sortedBlocks = note.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })
            let newIndex = (sortedBlocks.last?.orderIndex ?? -1) + 1
            let newBlock = NoteBlock(orderIndex: newIndex, filePathData: filePathData, type: .filePath)
            note.blocks.append(newBlock)
            context.insert(newBlock)
            try? context.save()
            return
        }

        // Check if it's in a column
        if let column = focusedBlock.parentColumn {
            insertFilePathInColumnAtBlock(filePathData: filePathData, focusedBlock: focusedBlock, column: column)
            return
        }

        // Root level block
        // Check if focused block is an empty text block - replace it
        if isTextBlockEmpty(focusedBlock) {
            let orderIndex = focusedBlock.orderIndex

            // Remove the empty text block from the array and delete it
            note.blocks.removeAll { $0.id == focusedBlock.id }
            context.delete(focusedBlock)

            // Insert file path block at same position
            let newBlock = NoteBlock(orderIndex: orderIndex, filePathData: filePathData, type: .filePath)
            note.blocks.append(newBlock)
            context.insert(newBlock)
        } else {
            // Insert after the focused block
            let targetIndex = focusedBlock.orderIndex + 1

            // Shift subsequent blocks
            for block in note.blocks where block.orderIndex >= targetIndex {
                block.orderIndex += 1
            }

            let newBlock = NoteBlock(orderIndex: targetIndex, filePathData: filePathData, type: .filePath)
            note.blocks.append(newBlock)
            context.insert(newBlock)
        }

        try? context.save()
    }

    /// Helper to insert file path in a column at the focused block
    private func insertFilePathInColumnAtBlock(filePathData: FilePathData, focusedBlock: NoteBlock, column: Column) {
        // Check if focused block is an empty text block - replace it
        if isTextBlockEmpty(focusedBlock) {
            let orderIndex = focusedBlock.orderIndex

            // Remove the empty text block
            column.blocks.removeAll { $0.id == focusedBlock.id }
            context.delete(focusedBlock)

            // Insert file path block at same position
            let newBlock = NoteBlock(orderIndex: orderIndex, filePathData: filePathData, type: .filePath)
            newBlock.parentColumn = column
            column.blocks.append(newBlock)
            context.insert(newBlock)
        } else {
            // Insert after the focused block
            let targetIndex = focusedBlock.orderIndex + 1

            // Shift subsequent blocks in column
            for block in column.blocks where block.orderIndex >= targetIndex {
                block.orderIndex += 1
            }

            let newBlock = NoteBlock(orderIndex: targetIndex, filePathData: filePathData, type: .filePath)
            newBlock.parentColumn = column
            column.blocks.append(newBlock)
            context.insert(newBlock)
        }

        try? context.save()
    }

    // MARK: - Title Enter Key Handling
    
    private func setupTitleEventMonitor() {
        if titleEventMonitor != nil { return }
        
        titleEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.isTitleFocused else { return event }
            
            // Enter key (keyCode 36)
            if event.keyCode == 36 {
                // Check if there's content below the title
                if !self.note.blocks.isEmpty {
                    DispatchQueue.main.async {
                        self.insertTextBlockAtBeginning()
                    }
                    return nil // Consume the event to prevent newline in title
                }
            }
            
            return event
        }
    }
    
    private func removeTitleEventMonitor() {
        if let monitor = titleEventMonitor {
            NSEvent.removeMonitor(monitor)
            titleEventMonitor = nil
        }
    }
    
    /// Inserts an empty text block at the beginning of the page (orderIndex 0)
    private func insertTextBlockAtBeginning() {
        // Shift all existing blocks up by 1
        for block in note.blocks {
            block.orderIndex += 1
        }
        
        // Create new text block at orderIndex 0
        let newBlock = NoteBlock(orderIndex: 0, text: AttributedString(""), type: .text)
        note.blocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()
        
        // Focus the new block
        DispatchQueue.main.async {
            self.focusedBlockID = newBlock.id
        }
    }

    // MARK: - Insert After Block Operations (+ Menu)

    /// Inserts a text block after the specified block
    private func insertTextBlockAfter(_ block: NoteBlock) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in note.blocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let newBlock = NoteBlock(orderIndex: targetIndex, text: "", type: .text)
        note.blocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()

        // Focus the new block
        DispatchQueue.main.async {
            self.focusedBlockID = newBlock.id
        }
    }

    /// Inserts a table after the specified block
    private func insertTableAfterBlock(_ block: NoteBlock, rows: Int, cols: Int) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in note.blocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let newTable = TableData(rowCount: rows, columnCount: cols)
        context.insert(newTable)

        let newBlock = NoteBlock(orderIndex: targetIndex, table: newTable, type: .table)
        note.blocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()
    }

    /// Inserts an accordion after the specified block
    private func insertAccordionAfterBlock(_ block: NoteBlock, level: AccordionData.HeadingLevel) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in note.blocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let newAccordion = AccordionData(level: level)
        context.insert(newAccordion)

        // Create initial text block inside the accordion
        let initialTextBlock = NoteBlock(orderIndex: 0, text: "", type: .text)
        initialTextBlock.parentAccordion = newAccordion
        newAccordion.contentBlocks.append(initialTextBlock)
        context.insert(initialTextBlock)

        let newBlock = NoteBlock(orderIndex: targetIndex, accordion: newAccordion, type: .accordion)
        note.blocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()

        // Focus the accordion heading
        DispatchQueue.main.async {
            self.focusedBlockID = newAccordion.id
        }
    }

    /// Inserts an image after the specified block (opens image picker)
    private func insertImageAfterBlock(_ block: NoteBlock) {
        insertionTargetBlockID = block.id
        activeElementPopover = .image
    }

    /// Inserts a code block after the specified block
    private func insertCodeBlockAfterBlock(_ block: NoteBlock) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in note.blocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let language = Language(rawValue: note.lastUsedCodeLanguage) ?? .swift
        let newCodeBlock = CodeBlockData(language: language)
        context.insert(newCodeBlock)

        let newBlock = NoteBlock(orderIndex: targetIndex, codeBlock: newCodeBlock, type: .code)
        note.blocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()
    }

    /// Inserts a quote after the specified block
    private func insertQuoteAfterBlock(_ block: NoteBlock) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in note.blocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let newBlock = NoteBlock(orderIndex: targetIndex, text: "", type: .quote)
        note.blocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()

        // Focus the new quote block
        DispatchQueue.main.async {
            self.focusedBlockID = newBlock.id
        }
    }
    
    private func insertQuoteAfterBlockInColumn(_ block: NoteBlock, _ column: Column) {
        let targetIndex = block.orderIndex + 1
        
        // Shift subsequent blocks in column
        for b in column.blocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }
        
        let newBlock = NoteBlock(orderIndex: targetIndex, text: "", type: .quote)
        newBlock.parentColumn = column
        column.blocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()
        
        // Focus the new quote block
        DispatchQueue.main.async {
            self.focusedBlockID = newBlock.id
        }
    }
    
    private func insertQuoteAfterBlockInAccordion(_ block: NoteBlock, accordion: AccordionData) {
        let titleOrder = block.orderIndex + 1
        
        // Shift subsequent blocks
        for b in accordion.contentBlocks where b.orderIndex >= titleOrder {
            b.orderIndex += 1
        }
        
        let newBlock = NoteBlock(orderIndex: titleOrder, text: "", type: .quote)
        newBlock.parentAccordion = accordion
        accordion.contentBlocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()
        
        // Focus the new quote block
        DispatchQueue.main.async {
            self.focusedBlockID = newBlock.id
        }
    }
    
    /// Inserts columns after the specified block
    private func insertColumnsAfterBlock(_ block: NoteBlock, ratios: [Double]) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in note.blocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let count = ratios.count
        let newColumnData = ColumnData(columnCount: count)

        // Create columns
        for i in 0..<count {
            let col = Column(orderIndex: i, widthRatio: ratios[i])
            col.parentColumnData = newColumnData

            // Create initial empty text block in each column
            let textBlock = NoteBlock(orderIndex: 0, text: "", type: .text)
            textBlock.parentColumn = col
            col.blocks.append(textBlock)

            newColumnData.columns.append(col)
        }

        context.insert(newColumnData)

        let newBlock = NoteBlock(orderIndex: targetIndex, columnData: newColumnData, type: .columns)
        note.blocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()

        // Focus first block of first column
        if let firstCol = newColumnData.columns.sorted(by: { $0.orderIndex < $1.orderIndex }).first,
           let firstBlock = firstCol.blocks.first {
            DispatchQueue.main.async {
                self.focusedBlockID = firstBlock.id
            }
        }
    }

    /// Inserts a list after the specified block
    private func insertListAfterBlock(_ block: NoteBlock, type: ListData.ListType) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in note.blocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let newListData = ListData(listType: type)
        context.insert(newListData)

        // Create initial empty item
        let initialItem = ListItem(orderIndex: 0, text: "")
        initialItem.parentList = newListData
        newListData.items.append(initialItem)
        context.insert(initialItem)

        let newBlock = NoteBlock(orderIndex: targetIndex, listData: newListData, type: .list)
        note.blocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()

        // Focus the first item
        DispatchQueue.main.async {
            self.focusedBlockID = initialItem.id
        }
    }

    /// Inserts a file path link after the specified block (opens file picker)
    private func insertFilePathAfterBlock(_ block: NoteBlock) {
        let capturedBlockID = block.id

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = "Select a file or folder to link"
        panel.prompt = "Link"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                DispatchQueue.main.async {
                    guard let targetBlock = self.note.blocks.first(where: { $0.id == capturedBlockID }) else { return }
                    let targetIndex = targetBlock.orderIndex + 1

                    // Shift subsequent blocks
                    for b in self.note.blocks where b.orderIndex >= targetIndex {
                        b.orderIndex += 1
                    }

                    let filePathData = FilePathData.create(from: url)
                    self.context.insert(filePathData)

                    let newBlock = NoteBlock(orderIndex: targetIndex, filePathData: filePathData, type: .filePath)
                    self.note.blocks.append(newBlock)
                    self.context.insert(newBlock)
                    try? self.context.save()
                }
            }
        }
    }

    // MARK: - Insert After Nested Block Operations (+ Menu for Accordions/Columns)

    /// Inserts a text block after a nested block in an accordion
    private func insertTextBlockAfterInAccordion(_ block: NoteBlock, accordion: AccordionData) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in accordion.contentBlocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let newBlock = NoteBlock(orderIndex: targetIndex, text: "", type: .text)
        newBlock.parentAccordion = accordion
        accordion.contentBlocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()

        // Focus the new block
        DispatchQueue.main.async {
            self.focusedBlockID = newBlock.id
        }
    }

    /// Inserts a table after a nested block in an accordion
    private func insertTableAfterInAccordion(_ block: NoteBlock, accordion: AccordionData, rows: Int, cols: Int) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in accordion.contentBlocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let newTable = TableData(rowCount: rows, columnCount: cols)
        context.insert(newTable)

        let newBlock = NoteBlock(orderIndex: targetIndex, table: newTable, type: .table)
        newBlock.parentAccordion = accordion
        accordion.contentBlocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()
    }

    /// Inserts an accordion after a nested block in an accordion
    private func insertAccordionAfterInAccordion(_ block: NoteBlock, accordion: AccordionData, level: AccordionData.HeadingLevel) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in accordion.contentBlocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let newAccordion = AccordionData(level: level)
        context.insert(newAccordion)

        // Create initial text block inside the nested accordion
        let initialTextBlock = NoteBlock(orderIndex: 0, text: "", type: .text)
        initialTextBlock.parentAccordion = newAccordion
        newAccordion.contentBlocks.append(initialTextBlock)
        context.insert(initialTextBlock)

        let accordionBlock = NoteBlock(orderIndex: targetIndex, accordion: newAccordion, type: .accordion)
        accordionBlock.parentAccordion = accordion
        accordion.contentBlocks.append(accordionBlock)
        context.insert(accordionBlock)
        try? context.save()

        // Focus the new nested accordion
        DispatchQueue.main.async {
            self.focusedBlockID = newAccordion.id
        }
    }

    /// Inserts a code block after a nested block in an accordion
    private func insertCodeBlockAfterInAccordion(_ block: NoteBlock, accordion: AccordionData) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in accordion.contentBlocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let language = Language(rawValue: note.lastUsedCodeLanguage) ?? .swift
        let newCodeBlock = CodeBlockData(language: language)
        context.insert(newCodeBlock)

        let newBlock = NoteBlock(orderIndex: targetIndex, codeBlock: newCodeBlock, type: .code)
        newBlock.parentAccordion = accordion
        accordion.contentBlocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()
    }

    /// Inserts a list after a nested block in an accordion
    private func insertListAfterInAccordion(_ block: NoteBlock, accordion: AccordionData, type: ListData.ListType) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in accordion.contentBlocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let newListData = ListData(listType: type)
        context.insert(newListData)

        // Create initial empty item
        let initialItem = ListItem(orderIndex: 0, text: "")
        initialItem.parentList = newListData
        newListData.items.append(initialItem)
        context.insert(initialItem)

        let newBlock = NoteBlock(orderIndex: targetIndex, listData: newListData, type: .list)
        newBlock.parentAccordion = accordion
        accordion.contentBlocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()

        // Focus the first item
        DispatchQueue.main.async {
            self.focusedBlockID = initialItem.id
        }
    }

    /// Inserts a file path link after a nested block in an accordion (opens file picker)
    private func insertFilePathAfterInAccordion(_ block: NoteBlock, accordion: AccordionData) {
        let capturedBlockID = block.id

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = "Select a file or folder to link"
        panel.prompt = "Link"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                DispatchQueue.main.async {
                    guard let targetBlock = accordion.contentBlocks.first(where: { $0.id == capturedBlockID }) else { return }
                    let targetIndex = targetBlock.orderIndex + 1

                    // Shift subsequent blocks
                    for b in accordion.contentBlocks where b.orderIndex >= targetIndex {
                        b.orderIndex += 1
                    }

                    let filePathData = FilePathData.create(from: url)
                    self.context.insert(filePathData)

                    let newBlock = NoteBlock(orderIndex: targetIndex, filePathData: filePathData, type: .filePath)
                    newBlock.parentAccordion = accordion
                    accordion.contentBlocks.append(newBlock)
                    self.context.insert(newBlock)
                    try? self.context.save()
                }
            }
        }
    }

    /// Inserts a text block after a nested block in a column
    private func insertTextBlockAfterInColumn(_ block: NoteBlock, column: Column) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in column.blocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let newBlock = NoteBlock(orderIndex: targetIndex, text: "", type: .text)
        newBlock.parentColumn = column
        column.blocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()

        // Focus the new block
        DispatchQueue.main.async {
            self.focusedBlockID = newBlock.id
        }
    }

    /// Inserts a table after a nested block in a column
    private func insertTableAfterInColumn(_ block: NoteBlock, column: Column, rows: Int, cols: Int) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in column.blocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let newTable = TableData(rowCount: rows, columnCount: cols)
        context.insert(newTable)

        let newBlock = NoteBlock(orderIndex: targetIndex, table: newTable, type: .table)
        newBlock.parentColumn = column
        column.blocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()
    }

    /// Inserts an accordion after a nested block in a column
    private func insertAccordionAfterInColumn(_ block: NoteBlock, column: Column, level: AccordionData.HeadingLevel) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in column.blocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let newAccordion = AccordionData(level: level)
        context.insert(newAccordion)

        // Create initial text block inside the accordion
        let initialTextBlock = NoteBlock(orderIndex: 0, text: "", type: .text)
        initialTextBlock.parentAccordion = newAccordion
        newAccordion.contentBlocks.append(initialTextBlock)
        context.insert(initialTextBlock)

        let accordionBlock = NoteBlock(orderIndex: targetIndex, accordion: newAccordion, type: .accordion)
        accordionBlock.parentColumn = column
        column.blocks.append(accordionBlock)
        context.insert(accordionBlock)
        try? context.save()

        // Focus the accordion heading
        DispatchQueue.main.async {
            self.focusedBlockID = newAccordion.id
        }
    }

    /// Inserts a code block after a nested block in a column
    private func insertCodeBlockAfterInColumn(_ block: NoteBlock, column: Column) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in column.blocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let language = Language(rawValue: note.lastUsedCodeLanguage) ?? .swift
        let newCodeBlock = CodeBlockData(language: language)
        context.insert(newCodeBlock)

        let newBlock = NoteBlock(orderIndex: targetIndex, codeBlock: newCodeBlock, type: .code)
        newBlock.parentColumn = column
        column.blocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()
    }

    /// Inserts a list after a nested block in a column
    private func insertListAfterInColumn(_ block: NoteBlock, column: Column, type: ListData.ListType) {
        let targetIndex = block.orderIndex + 1

        // Shift subsequent blocks
        for b in column.blocks where b.orderIndex >= targetIndex {
            b.orderIndex += 1
        }

        let newListData = ListData(listType: type)
        context.insert(newListData)

        // Create initial empty item
        let initialItem = ListItem(orderIndex: 0, text: "")
        initialItem.parentList = newListData
        newListData.items.append(initialItem)
        context.insert(initialItem)

        let newBlock = NoteBlock(orderIndex: targetIndex, listData: newListData, type: .list)
        newBlock.parentColumn = column
        column.blocks.append(newBlock)
        context.insert(newBlock)
        try? context.save()

        // Focus the first item
        DispatchQueue.main.async {
            self.focusedBlockID = initialItem.id
        }
    }

    /// Inserts a file path link after a nested block in a column (opens file picker)
    private func insertFilePathAfterInColumn(_ block: NoteBlock, column: Column) {
        let capturedBlockID = block.id

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = "Select a file or folder to link"
        panel.prompt = "Link"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                DispatchQueue.main.async {
                    guard let targetBlock = column.blocks.first(where: { $0.id == capturedBlockID }) else { return }
                    let targetIndex = targetBlock.orderIndex + 1

                    // Shift subsequent blocks
                    for b in column.blocks where b.orderIndex >= targetIndex {
                        b.orderIndex += 1
                    }

                    let filePathData = FilePathData.create(from: url)
                    self.context.insert(filePathData)

                    let newBlock = NoteBlock(orderIndex: targetIndex, filePathData: filePathData, type: .filePath)
                    newBlock.parentColumn = column
                    column.blocks.append(newBlock)
                    self.context.insert(newBlock)
                    try? self.context.save()
                }
            }
        }
    }

    // MARK: - Bookmark Operations

    /// Inserts a bookmark block after a given block
    private func insertBookmark(url: URL, afterBlock: NoteBlock? = nil) {
        Task {
            // Fetch metadata
            var metadata: URLMetadata?
            do {
                metadata = try await URLMetadataFetcher.shared.fetch(url: url)
            } catch {
                // Continue without metadata
            }

            await MainActor.run {
                let bookmarkData = BookmarkData(
                    urlString: url.absoluteString,
                    title: metadata?.title,
                    descriptionText: metadata?.description,
                    faviconURLString: metadata?.faviconURL?.absoluteString,
                    ogImageURLString: metadata?.ogImageURL?.absoluteString,
                    fetchedAt: Date()
                )
                context.insert(bookmarkData)

                if let afterBlock = afterBlock {
                    // Check if the afterBlock is an empty text block
                    let isReplaceable = afterBlock.type == .text && (afterBlock.text?.characters.isEmpty ?? true)

                    if isReplaceable {
                        // Replace the empty block
                        afterBlock.type = .bookmark
                        afterBlock.bookmarkData = bookmarkData
                        afterBlock.text = nil
                        focusedBlockID = nil // Reset focus to force refresh or just blur
                    } else {
                        // Insert after the specified block
                        let targetIndex = afterBlock.orderIndex + 1

                        // Shift subsequent blocks
                        for block in note.blocks where block.orderIndex >= targetIndex {
                            block.orderIndex += 1
                        }

                        let newBlock = NoteBlock(orderIndex: targetIndex, bookmarkData: bookmarkData, type: .bookmark)
                        note.blocks.append(newBlock)
                        context.insert(newBlock)
                    }
                } else {
                    // Use the standard insertion method
                    insertBlockAtRoot { index in
                        NoteBlock(orderIndex: index, bookmarkData: bookmarkData, type: .bookmark)
                    }
                }

                try? context.save()
            }
        }
    }
}

// MARK: - Block Drop Delegate

// MARK: - Drop Helper Types

enum DropEdge {
    case top
    case bottom
}

struct DropState: Equatable {
    let targetID: UUID
    let edge: DropEdge
}

// MARK: - Block Drop Delegate

struct BlockDropDelegate: DropDelegate {
    let block: NoteBlock
    @Binding var draggingBlock: NoteBlock?
    @Binding var dropState: DropState?
    let blockHeights: [UUID: CGFloat]
    let blockPosition: CGFloat // Block's Y position in scroll view
    let scrollViewHeight: CGFloat // Height of visible scroll area
    let reorderBlock: (NoteBlock, NoteBlock, DropEdge) -> Void
    var onDragNearEdge: ((ScrollDirection?) -> Void)?
    var onDragEnded: (() -> Void)?
    let totalBlocks: Int

    func validateDrop(info: DropInfo) -> Bool {
        let valid = info.hasItemsConforming(to: [UTType.noteBlock, UTType.plainText, UTType.text])
        print("BlockDropDelegate: validateDrop -> \(valid)")
        return valid
    }

    func dropEntered(info: DropInfo) {
        print("BlockDropDelegate: dropEntered for target \(block.id)")
        guard let dragging = draggingBlock, dragging.id != block.id else { 
            print("BlockDropDelegate: dropEntered IGNORED (dragging self or nil)")
            return 
        }
        // Initial state, will be updated in dropUpdated
        dropState = DropState(targetID: block.id, edge: .bottom)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let dragging = draggingBlock, dragging.id != block.id else { 
            return nil 
        }
        
        let y = info.location.y
        let height = blockHeights[block.id] ?? 0
        let edge: DropEdge = y < height / 2 ? .top : .bottom
        
        // print("BlockDropDelegate: dropUpdated y=\(y) height=\(height) edge=\(edge) pos=\(blockPosition)")
        
        if dropState?.targetID != block.id || dropState?.edge != edge {
            dropState = DropState(targetID: block.id, edge: edge)
        }
        
        // Check if dragging near top or bottom of visible scroll area (within 40px)
        // blockPosition is the block's top edge position relative to the scroll view's visible area
        // Positive values mean the block is below the top of the visible area
        // Negative values mean the block is above the top of the visible area
        
        var scrollDirection: ScrollDirection? = nil
        
        // Get the block's bottom position relative to visible area
        let blockBottom = blockPosition + height
        
        // Check if near top of visible area (within 40px from top)
        // blockPosition between 0 and 40 means the top of the block is within 40px of the visible top
        if blockPosition >= 0 && blockPosition < 40 {
            scrollDirection = .up
        }
        // Check if near bottom of visible area (within 40px from bottom)
        // blockBottom between scrollViewHeight - 40 and scrollViewHeight means within 40px of bottom
        else if blockBottom > scrollViewHeight - 40 && blockBottom <= scrollViewHeight {
            scrollDirection = .down
        }
        // Also check if block is partially visible at top (scrolled up)
        else if blockPosition < 0 && blockBottom > 0 {
            scrollDirection = .up
        }
        // Also check if block is partially visible at bottom (scrolled down)
        else if blockPosition < scrollViewHeight && blockBottom > scrollViewHeight {
            scrollDirection = .down
        }
        
        if let direction = scrollDirection {
            print("BlockDropDelegate: Requesting scroll \(direction)")
        }
        onDragNearEdge?(scrollDirection)
        
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let dragging = draggingBlock, let state = dropState else {
            draggingBlock = nil
            dropState = nil
            onDragEnded?()
            return false
        }
        
        if state.targetID == block.id {
             reorderBlock(dragging, block, state.edge)
        }
        
        draggingBlock = nil
        dropState = nil
        onDragEnded?()
        return true
    }
    
    func dropExited(info: DropInfo) {
        if dropState?.targetID == block.id {
            dropState = nil
        }
    }
}

struct BackgroundDropDelegate: DropDelegate {
    @Binding var draggingBlock: NoteBlock?
    @Binding var dropState: DropState?
    var onDragEnded: (() -> Void)?

    func performDrop(info: DropInfo) -> Bool {
        draggingBlock = nil
        dropState = nil
        onDragEnded?()
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        // Return move to allow drop on background
        return DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        // Just in case we need to cleanup when moving out of the scroll area entirely
        // But usually draggingBlock is enough
    }
}



#Preview(traits: .mockData) {
    @Previewable @Query var notes: [RichTextNote]
    NavigationStack {
        NotesEditorView(note: notes.first!)
    }
}

// MARK: - Block Controls View

struct BlockControlsView: View {
    let block: NoteBlock
    @Binding var draggingBlock: NoteBlock?
    let copiedBlock: NoteBlock?
    let isHovered: Bool
    let onInsertTextBlockAfter: (NoteBlock) -> Void
    let onInsertTableAfter: (NoteBlock, Int, Int) -> Void
    let onInsertAccordionAfter: (NoteBlock, AccordionData.HeadingLevel) -> Void
    let onInsertImageAfter: (NoteBlock) -> Void
    let onInsertCodeBlockAfter: (NoteBlock) -> Void
    let onInsertQuoteAfter: (NoteBlock) -> Void
    let onInsertColumnsAfter: (NoteBlock, [Double]) -> Void
    let onInsertListAfter: (NoteBlock, ListData.ListType) -> Void
    let onInsertFilePathAfter: (NoteBlock) -> Void
    let onDuplicate: (NoteBlock) -> Void
    let onCopy: (NoteBlock) -> Void
    let onCut: (NoteBlock) -> Void
    let onPasteAfter: (NoteBlock) -> Void
    let onDelete: (NoteBlock) -> Void
    let onSelectContent: (NoteBlock) -> Void
    
    @State private var isPlusHovered = false
    @State private var isGridHovered = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Plus button with insert menu
            Menu {
                Button {
                    onInsertTextBlockAfter(block)
                } label: {
                    Label("Text Block", systemImage: "text.alignleft")
                }

                Button {
                    onInsertTableAfter(block, 3, 3)
                } label: {
                    Label("Table", systemImage: "tablecells")
                }

                Button {
                    onInsertAccordionAfter(block, .h2)
                } label: {
                    Label("Accordion", systemImage: "list.bullet.indent")
                }

                Button {
                    onInsertImageAfter(block)
                } label: {
                    Label("Image", systemImage: "photo")
                }

                Button {
                    onInsertCodeBlockAfter(block)
                } label: {
                    Label("Code Block", systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Button {
                    onInsertQuoteAfter(block)
                } label: {
                    Label("Quote", systemImage: "text.quote")
                }

                Menu {
                    Button {
                        onInsertColumnsAfter(block, [0.5, 0.5])
                    } label: {
                        Label("1/2 - 1/2", image: "half")
                    }
                    Button {
                        onInsertColumnsAfter(block, [0.75, 0.25])
                    } label: {
                        Label("3/4 - 1/4", image: "three-quarter")
                    }
                    Button {
                        onInsertColumnsAfter(block, [0.25, 0.75])
                    } label: {
                        Label("1/4 - 3/4", image: "one-quarter")
                    }
                    Button {
                        onInsertColumnsAfter(block, [0.66, 0.33])
                    } label: {
                        Label("2/3 - 1/3", image: "two-third")
                    }
                    Button {
                        onInsertColumnsAfter(block, [0.33, 0.66])
                    } label: {
                        Label("1/3 - 2/3", image: "one-third")
                    }
                    Button {
                        onInsertColumnsAfter(block, [0.33, 0.33, 0.33])
                    } label: {
                        Label("3 Columns", image: "three-column")
                    }
                } label: {
                    Label("Columns", systemImage: "rectangle.split.3x1")
                }

                Menu {
                    Button {
                        onInsertListAfter(block, .bullet)
                    } label: {
                        Label("Bullet List", systemImage: "list.bullet")
                    }
                    Button {
                        onInsertListAfter(block, .numbered)
                    } label: {
                        Label("Numbered List", systemImage: "list.number")
                    }
                    Button {
                        onInsertListAfter(block, .checkbox)
                    } label: {
                        Label("Checkbox List", systemImage: "checklist")
                    }
                } label: {
                    Label("Lists", systemImage: "list.bullet.indent")
                }

                Divider()

                Button {
                    onInsertFilePathAfter(block)
                } label: {
                    Label("File Link", systemImage: "doc.badge.arrow.up")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isHovered ? .primary : .tertiary)
                    .frame(width: 20, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? (isPlusHovered ? 0.7 : 0.5) : 0.01)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .animation(.easeInOut(duration: 0.15), value: isPlusHovered)
            .onHover { hovering in
                isPlusHovered = hovering
            }

            // Drag handle icon
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isHovered ? .primary : .tertiary)
                .frame(width: 20, height: 24)
                .contentShape(Rectangle())
                .opacity(isHovered ? (isGridHovered ? 0.7 : 0.5) : 0.01)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
                .animation(.easeInOut(duration: 0.15), value: isGridHovered)
                .onHover { hovering in
                    isGridHovered = hovering
                }
                .onDrag {
                    print("BlockControlsView: onDrag STARTED for block \(block.id)")
                    let provider = NSItemProvider(object: block.id.uuidString as NSString)
                    provider.suggestedName = "Note Block"
                    provider.registerDataRepresentation(forTypeIdentifier: UTType.noteBlock.identifier, visibility: .all) { completion in
                        let data = block.id.uuidString.data(using: .utf8)
                        completion(data, nil)
                        return nil
                    }
                    draggingBlock = block
                    return provider
                } preview: {
                    HStack {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 14))
                        Text(block.displayName)
                            .font(.caption)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .onTapGesture {
                    onSelectContent(block)
                }
                .contextMenu {
                    Button {
                        onDuplicate(block)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }

                    Button {
                        onCopy(block)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }

                    Button {
                        onCut(block)
                    } label: {
                        Label("Cut", systemImage: "scissors")
                    }

                    if copiedBlock != nil {
                        Button {
                            onPasteAfter(block)
                        } label: {
                            Label("Paste After", systemImage: "doc.on.clipboard")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        onDelete(block)
                    } label: {
                        Label("Delete \(block.displayName)", systemImage: "trash")
                    }
                }
        }
        .opacity(isHovered ? 1 : 0)
        .allowsHitTesting(true) // Keep controls interactive even when hidden
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// MARK: - Block Row Hover Container

struct BlockRowHoverContainer<Content: View>: View {
    let block: NoteBlock
    let content: (Bool) -> Content
    @State private var isHovered = false
    
    var body: some View {
        content(isHovered)
            .contentShape(Rectangle()) // Ensure entire area including controls is hoverable
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
    }
}

