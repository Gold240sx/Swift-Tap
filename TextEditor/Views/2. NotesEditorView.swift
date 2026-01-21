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
    static let noteBlock = UTType(exportedAs: "com.shippotracker.noteblock")
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

                Button {
                    showTablePicker.toggle()
                } label: {
                    Image(systemName: "tablecells")
                }
                .popover(isPresented: $showTablePicker) {
                    TableGridPicker(selectedRows: .constant(0), selectedCols: .constant(0)) { rows, cols in
                        insertTable(rows: rows, cols: cols)
                        showTablePicker = false
                    }
                }

                Button {
                    showAccordionPicker.toggle()
                } label: {
                    Image(systemName: "list.bullet.indent")
                }
                .popover(isPresented: $showAccordionPicker) {
                    AccordionPicker { level in
                        insertAccordion(level: level)
                        showAccordionPicker = false
                    }
                }

                Button {
                    insertCodeBlock()
                } label: {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                }
                .help("Insert code block")
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
    }


    // MARK: - Category Selection View

    @ViewBuilder
    private var categorySelectionView: some View {
        HStack {
            if categories.isEmpty {
                Text("No Categories")
            } else {
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
                    .onDisappear {
                        draggingBlock = nil
                    }
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

    @State private var showTablePicker = false
    @State private var showAccordionPicker = false

    private func insertCodeBlock() {
        let language = Language(rawValue: note.lastUsedCodeLanguage) ?? .swift
        let newCodeBlock = CodeBlockData(language: language)
        context.insert(newCodeBlock)

        let sortedBlocks = note.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })
        var targetOrderIndex = sortedBlocks.count

        if let focusedID = focusedBlockID,
           let focusedBlock = sortedBlocks.first(where: { $0.id == focusedID }) {
            targetOrderIndex = focusedBlock.orderIndex + 1
        }

        // Shift subsequent blocks
        for block in note.blocks where block.orderIndex >= targetOrderIndex {
            block.orderIndex += 1
        }

        let codeBlockItem = NoteBlock(orderIndex: targetOrderIndex, codeBlock: newCodeBlock, type: .code)
        note.blocks.append(codeBlockItem)
        context.insert(codeBlockItem)

        ensureTrailingTextBlock()
        try? context.save()
    }

    private func insertTable(rows: Int, cols: Int) {
        let newTable = TableData(rowCount: rows, columnCount: cols)
        context.insert(newTable)

        // Ensure blocks are sorted by orderIndex for correct target calculation
        let sortedBlocks = note.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })

        var targetOrderIndex = sortedBlocks.count

        if let focusedID = focusedBlockID,
           let focusedBlock = sortedBlocks.first(where: { $0.id == focusedID }) {

            // Default to inserting after the focused block
            targetOrderIndex = focusedBlock.orderIndex + 1

            // Attempt to split the text block
            if let selection = selections[focusedID],
               let text = focusedBlock.text,
               !text.characters.isEmpty {

                var splitIndex: AttributedString.Index?

                // Use the Indices enum to find the split point (checking for our custom indices method)
                switch selection.indices(in: text) {
                case .insertionPoint(let index):
                    splitIndex = index
                case .ranges(let rangeSet):
                    if let firstRange = rangeSet.ranges.first {
                        splitIndex = firstRange.lowerBound
                    }
                }

                if let index = splitIndex, index < text.endIndex {
                    // Split the text
                    let prefix = text[..<index]
                    let suffix = text[index...]

                    // 1. Update current block with prefix
                    focusedBlock.text = AttributedString(prefix)

                    // 2. Insert Table at targetOrderIndex (current + 1)
                    // (Handled below)

                    // 3. Create new block for suffix at targetOrderIndex + 1
                    let suffixBlock = NoteBlock(orderIndex: targetOrderIndex + 1, text: AttributedString(suffix), type: .text)
                    note.blocks.append(suffixBlock)
                    context.insert(suffixBlock)

                    // Shift all SUBSEQUENT blocks (start from one after insertion)
                    // The table will be at targetOrderIndex.
                    // The suffix block is at targetOrderIndex + 1.
                    // Existing blocks at >= targetOrderIndex must shift by 2.

                    for block in note.blocks where block.orderIndex >= targetOrderIndex && block.id != suffixBlock.id {
                        block.orderIndex += 2
                    }

                    let tableBlock = NoteBlock(orderIndex: targetOrderIndex, table: newTable, type: .table)
                    note.blocks.append(tableBlock)
                    context.insert(tableBlock)

                    try? context.save()
                    return
                }
            }
        }

        // Fallback: Insert at end or after focused block (no split)
        // Re-index subsequent blocks based on orderIndex
        for block in note.blocks where block.orderIndex >= targetOrderIndex {
            block.orderIndex += 1
        }

        let tableBlock = NoteBlock(orderIndex: targetOrderIndex, table: newTable, type: .table)
        note.blocks.append(tableBlock)
        context.insert(tableBlock)

        // Ensure a text block follows if we're at the end
        if targetOrderIndex == note.blocks.count - 1 {
            let followingTextBlock = NoteBlock(orderIndex: targetOrderIndex + 1, text: "", type: .text)
            note.blocks.append(followingTextBlock)
            context.insert(followingTextBlock)
        }

        try? context.save()
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
        let newAccordion = AccordionData(level: level)
        context.insert(newAccordion)

        // Create initial text block inside the accordion
        let initialTextBlock = NoteBlock(orderIndex: 0, text: "", type: .text)
        initialTextBlock.parentAccordion = newAccordion
        newAccordion.contentBlocks.append(initialTextBlock)
        context.insert(initialTextBlock)

        let sortedBlocks = note.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })
        var targetOrderIndex = sortedBlocks.count

        if let focusedID = focusedBlockID,
           let focusedBlock = sortedBlocks.first(where: { $0.id == focusedID }) {
            targetOrderIndex = focusedBlock.orderIndex + 1
        }

        // Shift subsequent blocks
        for block in note.blocks where block.orderIndex >= targetOrderIndex {
            block.orderIndex += 1
        }

        let accordionBlock = NoteBlock(orderIndex: targetOrderIndex, accordion: newAccordion, type: .accordion)
        note.blocks.append(accordionBlock)
        context.insert(accordionBlock)

        // Focus the new accordion's heading
        focusedBlockID = newAccordion.id

        ensureTrailingTextBlock()
        try? context.save()
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

        // Focus the new accordion's heading
        focusedBlockID = newAccordion.id

        // Ensure trailing text block in parent accordion
        ensureTrailingTextBlockInAccordion(parentAccordion)
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

    // MARK: - Drag and Drop Reordering

    private func handleBlockDrop(dragged: NoteBlock, target: NoteBlock, edge: DropEdge) {
        guard dragged.id != target.id else { return }

        // 1. Identify Source and Remove
        // We must remove the block from its current location first to simplify insertion logic
        // But we need to know WHERE it was to remove it.
        // It could be in note.blocks OR inside an accordion.
        
        // Remove from Root
        if dragged.parentAccordion == nil {
            if let index = note.blocks.firstIndex(where: { $0.id == dragged.id }) {
                note.blocks.remove(at: index)
                // Re-indexing old validation not strictly needed yet as we will re-index target list
            }
        } else if let oldParent = dragged.parentAccordion {
            // Remove from old Accordion
            if let index = oldParent.contentBlocks.firstIndex(where: { $0.id == dragged.id }) {
                oldParent.contentBlocks.remove(at: index)
            }
        }
        
        // 2. Identify Target Destination
        // If target block is in Root, we insert into Root.
        // If target block is in an Accordion, we insert into that Accordion.
        
        if let targetParent = target.parentAccordion {
            // Target is inside an accordion -> Insert there
            insertBlock(dragged, into: &targetParent.contentBlocks, relativeTo: target, edge: edge)
            // Update parent relationship
            dragged.parentAccordion = targetParent
             // Sync array back? SwifData relationships usually handle `parent = targetParent`.
             // But we manipulated the array `contentBlocks`.
             // We should ensure `dragged` is added to `targetParent.contentBlocks`.
             // My helper `insertBlock` does array manipulation.
             // We also need to set `dragged.parentAccordion = targetParent`.
        } else {
            // Target is in Root
            insertBlock(dragged, into: &note.blocks, relativeTo: target, edge: edge)
            dragged.parentAccordion = nil
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
