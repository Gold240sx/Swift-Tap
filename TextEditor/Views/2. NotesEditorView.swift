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

struct NotesEditorView: View {
    @Bindable var note: RichTextNote
    @State private var moreEditing = false
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var selectedCategory: String = Category.uncategorized
    @State private var editCategories = false
    @FocusState private var focusedBlockID: UUID?
    @State private var selections: [UUID: AttributedTextSelection] = [:]
    @State private var activeBlockID: UUID?
    @Environment(\.undoManager) var undoManager
    @State private var showJson = false
    @State private var dropState: DropState?
    @State private var blockHeights: [UUID: CGFloat] = [:]
    @State private var draggingBlock: NoteBlock?
    private let saveTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    // MARK: - Main Editor Content
    
    @ViewBuilder
    private var mainEditorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Document Title
                TextField("Page Title", text: $note.title, axis: .vertical)
                    .font(.system(size: 34, weight: .bold))
                    .textFieldStyle(.plain)
                    .padding(.bottom, 8)
                    .onChange(of: note.title) {
                        note.updatedOn = Date.now
                    }

                ForEach(note.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })) { block in
                    blockRowView(for: block)
                        .padding(4)
                        .background(
                             GeometryReader { geo in
                                 Color.clear.onAppear { blockHeights[block.id] = geo.size.height }
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
                            reorderBlock: handleBlockDrop
                        ))
                }
            }
            .padding(.bottom, 50) // Space at bottom to scroll
            .contentShape(Rectangle())
            .onTapGesture {
                // Clicking the empty area of the scroll view clears all table selections
                NotificationCenter.default.post(name: NSNotification.Name("DeselectAllTables"), object: nil)
                focusedBlockID = nil
            }
        }
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

    var body: some View {
        VStack(alignment: .leading){
            categorySelectionView

            mainEditorContent
        }
        .padding([.horizontal, .bottom])
            .navigationTitle("RichText Editor")
            #if os(iOS)
            .toolbarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if note.blocks.isEmpty || (note.blocks.count == 1 && note.blocks.first?.text?.characters.isEmpty == true) {
                        context.delete(note)
                    }
                    try? context.save()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
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

                Menu {
                    Button {
                        activeElementPopover = .table
                    } label: {
                        Label("Table", systemImage: "tablecells")
                    }
                    
                    Button {
                        activeElementPopover = .accordion
                    } label: {
                        Label("Accordion", systemImage: "list.bullet.indent")
                    }
                    
                    Button {
                        activeElementPopover = .image
                    } label: {
                        Label("Image", systemImage: "photo")
                    }
                    
                    Button {
                        insertCodeBlock()
                    } label: {
                        Label("Code Block", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    
                    Menu {
                        Button {
                            insertColumns(count: 2)
                        } label: {
                            Label("2 Columns", systemImage: "rectangle.split.2x1")
                        }
                        Button {
                            insertColumns(count: 3)
                        } label: {
                            Label("3 Columns", systemImage: "rectangle.split.3x1")
                        }
                    } label: {
                        Label("Columns", systemImage: "rectangle.split.3x1")
                    }

                } label: {
                    Image(systemName: "plus")
                }
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
                            activeElementPopover = nil
                        }
                    }
                }
            }

            ToolbarItemGroup(placement: .secondaryAction) {
                Button {
                    showJson.toggle()
                } label: {
                    Image(systemName: "curlybraces")
                }
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

            // Ensure trailing text block if note ends with a component
            ensureTrailingTextBlock()

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
        .onChange(of: undoManager) {
            syncUndoManager()
        }
        // Paste without cursor support
        .onPasteCommand(of: [.text, .plainText, UTType.utf8PlainText]) { providers in
             pasteAtEnd(providers)
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


    // MARK: - Category Selection View

    @ViewBuilder
    private var categorySelectionView: some View {
        HStack {
            Picker("Category", selection: $selectedCategory) {
                Text(Category.uncategorized).tag(Category.uncategorized)
                ForEach(categories) { category in
                    Text(category.name).tag(category.name)
                }
            }
            .buttonStyle(.bordered)
            .onChange(of: selectedCategory) {
                if let category = categories.first(where: {$0.name == selectedCategory}) {
                    note.category = category
                } else {
                    note.category = nil
                }
                try? context.save()
            }
            Button {
                editCategories.toggle()
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
            .clipShape(.circle)
            .tint(note.category != nil ? Color(hex: note.category!.hexColor)! : .accentColor)
            #if os(iOS)
            .sheet(isPresented: $editCategories, onDismiss: {
                selectedCategory = note.category?.name ?? Category.uncategorized
            }) {
                CategoriesView()
            }
            #else
            .popover(isPresented: $editCategories) {
                CategoriesView()
                    .frame(width: 400, height: 500)
                    .onDisappear {
                        selectedCategory = note.category?.name ?? Category.uncategorized
                    }
            }
            #endif
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
        HStack(alignment: .top, spacing: 6) {
            // Drag handle icon
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 16, height: 20)
                .offset(y: -2)
                .onDrag {
                    let provider = NSItemProvider(object: block.id.uuidString as NSString)
                    provider.suggestedName = "Note Block"
                    // Register the custom type identifier so it doesn't get treated as plain text by default editors
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
                            .font(.system(size: 10))
                        Text(block.type == .text ? "Text Block" : block.type == .table ? "Table" : block.type == .accordion ? "Accordion" : "Code Block")
                            .font(.caption)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .onTapGesture {
                    // Select block content
                    selectBlockContent(block)
                }

            // Block content
            Group {
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
                } else if let imageData = block.imageData {
                    ImageBlockView(
                        imageData: imageData,
                        onDelete: {
                            removeBlock(block)
                        }
                    )
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
                        onRemoveBlock: { nestedBlock in
                             removeBlockFromColumn(nestedBlock)
                        },
                        onMergeNestedBlock: { nestedBlock, column in
                             mergeNestedBlockInColumn(nestedBlock, in: column)
                        },
                        onDropAction: { dragged, target, edge in
                             handleBlockDrop(dragged: dragged, target: target, edge: edge)
                        },
                        draggingBlock: $draggingBlock
                    )
                }
            }
        }
    }

    private func syncUndoManager() {
        if let undoManager {
            context.undoManager = undoManager
            context.undoManager?.levelsOfUndo = 100
        }
    }

    @State private var activeElementPopover: ElementPopover?

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

        if let focusedID = focusedBlockID,
           let focusedBlock = sortedBlocks.first(where: { $0.id == focusedID }) {

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
        
        // Ensure trailing text block if at end
        if targetOrderIndex == note.blocks.count - 1 {
             let trailing = NoteBlock(orderIndex: targetOrderIndex + 1, text: "", type: .text)
             note.blocks.append(trailing)
             context.insert(trailing)
        }
        
        try? context.save()
    }

    private func insertCodeBlock() {
        if let focusedID = focusedBlockID,
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
 
    private func insertTable(rows: Int, cols: Int) {
        if let focusedID = focusedBlockID,
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
        if let focusedID = focusedBlockID,
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

        // Ensure trailing text block in accordion
        ensureTrailingTextBlockInAccordion(accordion)
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
        
        ensureTrailingTextBlockInAccordion(parentAccordion)
        try? context.save()
    }
    
    // MARK: - Column Operations
    
    private func insertColumns(count: Int) {
        let newColumnData = ColumnData(columnCount: count)
        context.insert(newColumnData)
        
        // Create columns
        for i in 0..<count {
            let col = Column(orderIndex: i)
            col.parentColumnData = newColumnData
            // Create initial empty text block in each column
            let textBlock = NoteBlock(orderIndex: 0, text: "", type: .text)
            textBlock.parentColumn = col
            col.blocks.append(textBlock)
            
            newColumnData.columns.append(col)
        }
        
        insertBlockAtRoot { index in
            let block = NoteBlock(orderIndex: index, columnData: newColumnData, type: .columns)
            // Focus first block of first column
            if let firstCol = newColumnData.columns.sorted(by: {$0.orderIndex < $1.orderIndex}).first,
               let firstBlock = firstCol.blocks.first {
                focusedBlockID = firstBlock.id
            }
            return block
        }
        
        // Add a blank text block AFTER the columns so the user can continue typing easily
        // We need to find where the columns were inserted and add a block after.
        // insertBlockAtRoot inserts at 'index'. We can just append another one? 
        // insertBlockAtRoot logic is complex (handling splits), so we should use it carefully.
        // Actually, insertBlockAtRoot puts the column block in. 
        // If we want a block AFTER it, we can call insertBlockAtRoot again? No, that would insert at current focus which is now INSIDE the column.
        // We should manually append the text block after the column block.
        
        // Wait, insertBlockAtRoot returns the block but it's used inside a closure.
        // Let's modify insertBlockAtRoot or just handle it here.
        // Since we know we just inserted the column block, we can find it or just assume we are at the insertion point.
        
        // Simpler: Just rely on ensureTrailingTextBlock? No, that's only for the very end.
        // If we inserted columns in the middle, we want a text block right after.
        
        // Let's manually insert the text block after the column block.
        // We need the ID or reference of the inserted column block. `insertBlockAtRoot` doesn't return it to us easily (it returns it to the caller of the closure).
        // Let's refactor slightly. 
        // Or better: The user wants a clean place to type below.
        // We can just find the column block we just created (focusedBlockID is inside it, so we can find parent) and insert after.
        
        // Actually, `insertBlockAtRoot` calculates the index.
        // Let's piggyback? No.
        
        // Let's just find the column block we just made (it's the only one with this newColumnData).
        // But we explicitly set focus to inside it.
        
        // We can do this:
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
             // Find the column block
             if let colBlock = self.note.blocks.first(where: { $0.columnData?.id == newColumnData.id }) {
                 let targetIndex = colBlock.orderIndex + 1
                 
                 // Shift subsequent blocks
                 for b in self.note.blocks where b.orderIndex >= targetIndex {
                     b.orderIndex += 1
                 }
                 
                 let textBlock = NoteBlock(orderIndex: targetIndex, text: "", type: .text)
                 self.note.blocks.append(textBlock)
                 self.context.insert(textBlock)
                 try? self.context.save()
             }
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
    
    private func removeBlockFromColumn(_ block: NoteBlock) {
        // If it's a text block and it's not the only one, or if it's empty, delete.
        // If it's the only block, we might want to keep it empty?
        // Actually, just delete.
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

        // Ensure trailing text block in accordion
        ensureTrailingTextBlockInAccordion(accordion)
        try? context.save()
    }

    /// Remove a block from its parent accordion
    private func removeBlockFromAccordion(_ block: NoteBlock) {
        guard let parentAccordion = block.parentAccordion else { return }

        let removedOrder = block.orderIndex
        context.delete(block)
        parentAccordion.contentBlocks.removeAll(where: { $0.id == block.id })

        // Re-index remaining blocks
        for b in parentAccordion.contentBlocks where b.orderIndex > removedOrder {
            b.orderIndex -= 1
        }

        // Ensure trailing text block in accordion
        ensureTrailingTextBlockInAccordion(parentAccordion)
        try? context.save()
    }

    /// Ensures there's always a text block at the end of an accordion
    private func ensureTrailingTextBlockInAccordion(_ accordion: AccordionData) {
        let sortedBlocks = accordion.contentBlocks.sorted(by: { $0.orderIndex < $1.orderIndex })

        // If empty or last block is not text, add a text block
        if sortedBlocks.isEmpty {
            let newTextBlock = NoteBlock(orderIndex: 0, text: "", type: .text)
            newTextBlock.parentAccordion = accordion
            accordion.contentBlocks.append(newTextBlock)
            context.insert(newTextBlock)
        } else if let lastBlock = sortedBlocks.last, lastBlock.type != .text {
            let newTextBlock = NoteBlock(orderIndex: lastBlock.orderIndex + 1, text: "", type: .text)
            newTextBlock.parentAccordion = accordion
            accordion.contentBlocks.append(newTextBlock)
            context.insert(newTextBlock)
        }
    }

    /// Ensures there's always a text block at the end if the note ends with a component
    private func ensureTrailingTextBlock() {
        let sortedBlocks = note.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })
        guard let lastBlock = sortedBlocks.last else { return }

        // If the last block is not a text block, add one
        if lastBlock.type != .text {
            let newTextBlock = NoteBlock(orderIndex: lastBlock.orderIndex + 1, text: "", type: .text)
            note.blocks.append(newTextBlock)
            context.insert(newTextBlock)
        }
    }

    private func removeBlock(_ block: NoteBlock) {
        // Capture surrounding blocks before deletion
        let prevBlock = note.blocks.first(where: { $0.orderIndex == block.orderIndex - 1 })
        let nextBlock = note.blocks.first(where: { $0.orderIndex == block.orderIndex + 1 })

        // Delete the target block
        let removedOrder = block.orderIndex
        context.delete(block)
        note.blocks.removeAll(where: { $0.id == block.id })

        // Re‑index remaining blocks
        for b in note.blocks where b.orderIndex > removedOrder {
            b.orderIndex -= 1
        }

        // If the removed block was NOT a text block, attempt to merge adjacent text blocks
        if block.type != .text {
            if let prev = prevBlock, let next = nextBlock,
               prev.type == .text, next.type == .text,
               let prevText = prev.text, let nextText = next.text {
                // Combine the attributed strings
                var combined = prevText
                combined.append(AttributedString("\n")) // optional newline between blocks
                combined.append(nextText)
                prev.text = combined

                // Remove the next block and shift indices
                context.delete(next)
                note.blocks.removeAll(where: { $0.id == next.id })
                for b in note.blocks where b.orderIndex > next.orderIndex {
                    b.orderIndex -= 1
                }
            }
        }

        ensureTrailingTextBlock()
        try? context.save()
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
        if let focusedID = focusedBlockID,
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
        
        ensureTrailingTextBlockInAccordion(accordion)
        try? context.save()
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
    let reorderBlock: (NoteBlock, NoteBlock, DropEdge) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [UTType.noteBlock])
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingBlock, dragging.id != block.id else { return }
        // Initial state, will be updated in dropUpdated
        dropState = DropState(targetID: block.id, edge: .bottom)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let dragging = draggingBlock, dragging.id != block.id else { return nil }
        
        let y = info.location.y
        let height = blockHeights[block.id] ?? 0
        let edge: DropEdge = y < height / 2 ? .top : .bottom
        
        if dropState?.targetID != block.id || dropState?.edge != edge {
            dropState = DropState(targetID: block.id, edge: edge)
        }
        
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let dragging = draggingBlock, let state = dropState else {
            draggingBlock = nil
            dropState = nil
            return false
        }
        
        if state.targetID == block.id {
             reorderBlock(dragging, block, state.edge)
        }
        
        draggingBlock = nil
        dropState = nil
        return true
    }
    
    func dropExited(info: DropInfo) {
        if dropState?.targetID == block.id {
            dropState = nil
        }
    }
}



#Preview(traits: .mockData) {
    @Previewable @Query var notes: [RichTextNote]
    NavigationStack {
        NotesEditorView(note: notes.first!)
    }
}
