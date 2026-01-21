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

    // Auto-save timer
    private let saveTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
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
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(note.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })) { block in
                        if block.type == .text {
                            TextBlockView(
                                block: block,
                                selection: Binding(
                                    get: { selections[block.id] ?? AttributedTextSelection() },
                                    set: { selections[block.id] = $0 }
                                ),
                                focusState: $focusedBlockID
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
                        }
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
    
    private func syncUndoManager() {
        if let undoManager {
            context.undoManager = undoManager
            context.undoManager?.levelsOfUndo = 100
        }
    }
    
    @State private var showTablePicker = false
    
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
        
        try? context.save()
    }
}

#Preview(traits: .mockData) {
    @Previewable @Query var notes: [RichTextNote]
    NavigationStack {
        NotesEditorView(note: notes.first!)
    }
}
