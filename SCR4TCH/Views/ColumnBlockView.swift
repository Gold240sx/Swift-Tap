//
//  ColumnBlockView.swift
//  TextEditor
//
//  Created by Antigravity on 2026-01-21.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ColumnBlockView: View {
    @Bindable var columnData: ColumnData
    @Binding var selections: [UUID: AttributedTextSelection]
    var focusState: FocusState<UUID?>.Binding
    var note: RichTextNote?
    var onDelete: () -> Void = {}

    // Callbacks for nested interactions
    var onInsertTable: (Column, Int, Int) -> Void = { _, _, _ in }
    var onInsertAccordion: (Column, AccordionData.HeadingLevel) -> Void = { _, _ in }
    var onInsertCodeBlock: (Column) -> Void = { _ in }
    var onInsertFilePath: (Column) -> Void = { _ in }
    var onRemoveBlock: (NoteBlock) -> Void = { _ in }
    var onMergeNestedBlock: (NoteBlock, Column) -> Void = { _, _ in }
    var onDropAction: (NoteBlock, NoteBlock, DropEdge) -> Void = { _, _, _ in }
    var onInsertTextBlockAfter: (NoteBlock, Column) -> Void = { _, _ in }
    var onInsertTableAfter: (NoteBlock, Column, Int, Int) -> Void = { _, _, _, _ in }
    var onInsertAccordionAfter: (NoteBlock, Column, AccordionData.HeadingLevel) -> Void = { _, _, _ in }
    var onInsertCodeBlockAfter: (NoteBlock, Column) -> Void = { _, _ in }
    var onInsertListAfter: (NoteBlock, Column, ListData.ListType) -> Void = { _, _, _ in }
    var onInsertFilePathAfter: (NoteBlock, Column) -> Void = { _, _ in }
    var onCopyBlock: (NoteBlock) -> Void = { _ in }
    var onCutBlock: (NoteBlock) -> Void = { _ in }
    var onPasteBlockAfter: (NoteBlock, Column) -> Void = { _, _ in }
    var copiedBlock: NoteBlock? = nil
    // Accordion-specific callbacks (for accordions nested inside columns)
    var onInsertTableInAccordion: (AccordionData, Int, Int) -> Void = { _, _, _ in }
    var onInsertAccordionInAccordion: (AccordionData, AccordionData.HeadingLevel) -> Void = { _, _ in }
    var onInsertCodeBlockInAccordion: (AccordionData) -> Void = { _ in }
    var onRemoveBlockFromAccordion: (NoteBlock) -> Void = { _ in }
    var onMergeNestedBlockInAccordion: (NoteBlock, AccordionData) -> Void = { _, _ in }
    var onDropActionInAccordion: (NoteBlock, NoteBlock, DropEdge) -> Void = { _, _, _ in }
    var onInsertTextBlockAfterInAccordion: (NoteBlock, AccordionData) -> Void = { _, _ in }
    var onInsertTableAfterInAccordion: (NoteBlock, AccordionData, Int, Int) -> Void = { _, _, _, _ in }
    var onInsertAccordionAfterInAccordion: (NoteBlock, AccordionData, AccordionData.HeadingLevel) -> Void = { _, _, _ in }
    var onInsertCodeBlockAfterInAccordion: (NoteBlock, AccordionData) -> Void = { _, _ in }
    var onInsertListAfterInAccordion: (NoteBlock, AccordionData, ListData.ListType) -> Void = { _, _, _ in }
    var onInsertFilePathAfterInAccordion: (NoteBlock, AccordionData) -> Void = { _, _ in }
    var onCopyBlockInAccordion: (NoteBlock) -> Void = { _ in }
    var onCutBlockInAccordion: (NoteBlock) -> Void = { _ in }
    var onPasteBlockAfterInAccordion: (NoteBlock, AccordionData) -> Void = { _, _ in }

    @Environment(\.modelContext) var context
    @State private var isHovering = false
    @Binding var draggingBlock: NoteBlock?
    @State private var dropState: DropState?
    @State private var blockHeights: [UUID: CGFloat] = [:]
    @State private var isTrashHovered = false
    @State private var isDraggingDivider = false

    @State private var viewWidth: CGFloat = 0

    var body: some View {
        let sortedColumns = (columnData.columns ?? []).sorted(by: { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) })
        let totalRatio = max(0.001, sortedColumns.reduce(0.0) { $0 + ($1.widthRatio ?? 1.0) })
        let numberOfColumns = CGFloat((columnData.columns ?? []).count)
        let totalPadding = numberOfColumns * 16
        let dividerWidth: CGFloat = 13 // Widened gap
        let totalDividers = max(0, numberOfColumns - 1) * dividerWidth
        let availableWidth = max(1, viewWidth - totalPadding - totalDividers)

        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(sortedColumns.enumerated()), id: \.element.id) { index, column in
                ColumnContentView(
                    column: column,
                    totalRatio: totalRatio,
                    availableWidth: availableWidth,
                    viewWidth: viewWidth,
                    selections: $selections,
                    focusState: focusState,
                    onRemoveBlock: onRemoveBlock,
                    onMergeNestedBlock: onMergeNestedBlock,
                    onDropAction: onDropAction,
                    onInsertFilePath: onInsertFilePath,
                    onInsertTextBlockAfter: onInsertTextBlockAfter,
                    onInsertTableAfter: onInsertTableAfter,
                    onInsertAccordionAfter: onInsertAccordionAfter,
                    onInsertCodeBlockAfter: onInsertCodeBlockAfter,
                    onInsertListAfter: onInsertListAfter,
                    onInsertFilePathAfter: onInsertFilePathAfter,
                    onCopyBlock: onCopyBlock,
                    onCutBlock: onCutBlock,
                    onPasteBlockAfter: onPasteBlockAfter,
                    copiedBlock: copiedBlock,
                    onInsertTableInAccordion: onInsertTableInAccordion,
                    onInsertAccordionInAccordion: onInsertAccordionInAccordion,
                    onInsertCodeBlockInAccordion: onInsertCodeBlockInAccordion,
                    onRemoveBlockFromAccordion: onRemoveBlockFromAccordion,
                    onMergeNestedBlockInAccordion: onMergeNestedBlockInAccordion,
                    onDropActionInAccordion: onDropActionInAccordion,
                    onInsertTextBlockAfterInAccordion: onInsertTextBlockAfterInAccordion,
                    onInsertTableAfterInAccordion: onInsertTableAfterInAccordion,
                    onInsertAccordionAfterInAccordion: onInsertAccordionAfterInAccordion,
                    onInsertCodeBlockAfterInAccordion: onInsertCodeBlockAfterInAccordion,
                    onInsertListAfterInAccordion: onInsertListAfterInAccordion,
                    onInsertFilePathAfterInAccordion: onInsertFilePathAfterInAccordion,
                    onCopyBlockInAccordion: onCopyBlockInAccordion,
                    onCutBlockInAccordion: onCutBlockInAccordion,
                    onPasteBlockAfterInAccordion: onPasteBlockAfterInAccordion,
                    draggingBlock: $draggingBlock,
                    dropState: $dropState,
                    blockHeights: $blockHeights,
                    note: note
                )

                // Resize divider between columns (not after the last one)
                if index < sortedColumns.count - 1 {
                    ColumnResizeDivider(
                        leftColumn: column,
                        rightColumn: sortedColumns[index + 1],
                        totalRatio: totalRatio,
                        availableWidth: availableWidth,
                        isDragging: $isDraggingDivider,
                        context: context
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { viewWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newWidth in
                        viewWidth = newWidth
                    }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.5), lineWidth: isTrashHovered ? 2 : 0)
                .padding(-4)
        )
        .overlay(alignment: .topTrailing) {
             if isHovering {
                 Button {
                     onDelete()
                 } label: {
                     Image(systemName: "trash")
                     .font(.system(size: 12, weight: .medium))
                     .foregroundStyle(.red.opacity(0.8))
                     .padding(6)
                     .background(Color.red.opacity(0.1))
                     .clipShape(Circle())
                 }
                 .buttonStyle(.plain)
                 .padding(8)
                 .offset(x: 12, y: -12)
                 .onHover { hovering in
                     withAnimation(.easeInOut(duration: 0.15)) {
                         isTrashHovered = hovering
                     }
                 }
             }
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}


// MARK: - Column Content View
struct ColumnContentView: View {
    @Bindable var column: Column
    let totalRatio: Double
    let availableWidth: CGFloat
    let viewWidth: CGFloat
    @Binding var selections: [UUID: AttributedTextSelection]
    var focusState: FocusState<UUID?>.Binding
    
    // Callbacks
    var onRemoveBlock: (NoteBlock) -> Void
    var onMergeNestedBlock: (NoteBlock, Column) -> Void
    var onDropAction: (NoteBlock, NoteBlock, DropEdge) -> Void
    var onInsertFilePath: (Column) -> Void = { _ in }
    var onInsertTextBlockAfter: (NoteBlock, Column) -> Void = { _, _ in }
    var onInsertTableAfter: (NoteBlock, Column, Int, Int) -> Void = { _, _, _, _ in }
    var onInsertAccordionAfter: (NoteBlock, Column, AccordionData.HeadingLevel) -> Void = { _, _, _ in }
    var onInsertCodeBlockAfter: (NoteBlock, Column) -> Void = { _, _ in }
    var onInsertListAfter: (NoteBlock, Column, ListData.ListType) -> Void = { _, _, _ in }
    var onInsertFilePathAfter: (NoteBlock, Column) -> Void = { _, _ in }
    var onCopyBlock: (NoteBlock) -> Void = { _ in }
    var onCutBlock: (NoteBlock) -> Void = { _ in }
    var onPasteBlockAfter: (NoteBlock, Column) -> Void = { _, _ in }
    var copiedBlock: NoteBlock? = nil
    // Accordion-specific callbacks (for accordions nested inside columns)
    var onInsertTableInAccordion: (AccordionData, Int, Int) -> Void = { _, _, _ in }
    var onInsertAccordionInAccordion: (AccordionData, AccordionData.HeadingLevel) -> Void = { _, _ in }
    var onInsertCodeBlockInAccordion: (AccordionData) -> Void = { _ in }
    var onRemoveBlockFromAccordion: (NoteBlock) -> Void = { _ in }
    var onMergeNestedBlockInAccordion: (NoteBlock, AccordionData) -> Void = { _, _ in }
    var onDropActionInAccordion: (NoteBlock, NoteBlock, DropEdge) -> Void = { _, _, _ in }
    var onInsertTextBlockAfterInAccordion: (NoteBlock, AccordionData) -> Void = { _, _ in }
    var onInsertTableAfterInAccordion: (NoteBlock, AccordionData, Int, Int) -> Void = { _, _, _, _ in }
    var onInsertAccordionAfterInAccordion: (NoteBlock, AccordionData, AccordionData.HeadingLevel) -> Void = { _, _, _ in }
    var onInsertCodeBlockAfterInAccordion: (NoteBlock, AccordionData) -> Void = { _, _ in }
    var onInsertListAfterInAccordion: (NoteBlock, AccordionData, ListData.ListType) -> Void = { _, _, _ in }
    var onInsertFilePathAfterInAccordion: (NoteBlock, AccordionData) -> Void = { _, _ in }
    var onCopyBlockInAccordion: (NoteBlock) -> Void = { _ in }
    var onCutBlockInAccordion: (NoteBlock) -> Void = { _ in }
    var onPasteBlockAfterInAccordion: (NoteBlock, AccordionData) -> Void = { _, _ in }

    @Binding var draggingBlock: NoteBlock?
    @Binding var dropState: DropState?
    @Binding var blockHeights: [UUID: CGFloat]
    
    var note: RichTextNote?
    
    @Environment(\.modelContext) var context
    @State private var isHovering = false

    var body: some View {
        let columnWidth = max(0, ((column.widthRatio ?? 1.0) / totalRatio) * availableWidth)
        
        VStack(alignment: .leading, spacing: 8) {
            ForEach((column.blocks ?? []).sorted(by: { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) })) { block in
                 NestedBlockContainer(
                    block: block,
                    column: column,
                    selections: $selections,
                    focusState: focusState,
                    draggingBlock: $draggingBlock,
                    dropState: $dropState,
                    blockHeights: $blockHeights,
                    onRemoveBlock: onRemoveBlock,
                    onMergeNestedBlock: onMergeNestedBlock,
                    onDropAction: onDropAction,
                    note: note,
                    contentView: { b, c in
                        nestedBlockView(for: b, in: c)
                    }
                 )
            }
            
            // Empty state / Append area
            Color.clear
                .contentShape(Rectangle())
                .frame(minHeight: 20)
                .onTapGesture {
                     appendTextBlock(to: column)
                }
            
            Spacer()
        }
        .frame(maxWidth: .infinity) // Fill available space
        .frame(width: viewWidth > 0 ? columnWidth : nil) // Apply fixed width if calculated (not nil)
        .padding(8)
        .frame(maxHeight: .infinity) // Then expand height to fill container
        .background(Color.gray.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func appendTextBlock(to column: Column) {
        let sorted = (column.blocks ?? []).sorted(by: { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) })

        // If last block is an empty text block, just focus it instead of creating new one
        if let lastBlock = sorted.last,
           lastBlock.type == .text,
           lastBlock.text?.characters.isEmpty ?? true {
            focusState.wrappedValue = lastBlock.id
            return
        }

        let newIndex = (sorted.last?.orderIndex ?? -1) + 1
        let newBlock = NoteBlock(orderIndex: newIndex, text: "", type: .text)
        newBlock.parentColumn = column
        if column.blocks == nil { column.blocks = [] }
        column.blocks?.append(newBlock)
        context.insert(newBlock)

        // Focus new block
        focusState.wrappedValue = newBlock.id
        try? context.save()
    }
    
    @ViewBuilder
    private func nestedBlockView(for block: NoteBlock, in column: Column) -> some View {
        NestedBlockControlsContainer(block: block) { blockHovered in
            ColumnNestedBlockControlsContent(
                block: block,
                column: column,
                blockHovered: blockHovered,
                draggingBlock: $draggingBlock,
                copiedBlock: copiedBlock,
                selections: $selections,
                focusState: focusState,
                note: note,
                onInsertTextBlockAfter: onInsertTextBlockAfter,
                onInsertTableAfter: onInsertTableAfter,
                onInsertAccordionAfter: onInsertAccordionAfter,
                onInsertCodeBlockAfter: onInsertCodeBlockAfter,
                onInsertListAfter: onInsertListAfter,
                onInsertFilePathAfter: onInsertFilePathAfter,
                onCopyBlock: onCopyBlock,
                onCutBlock: onCutBlock,
                onPasteBlockAfter: onPasteBlockAfter,
                onRemoveBlock: onRemoveBlock,
                onMergeNestedBlock: onMergeNestedBlock,
                onDropAction: onDropAction,
                onInsertTableInAccordion: onInsertTableInAccordion,
                onInsertAccordionInAccordion: onInsertAccordionInAccordion,
                onInsertCodeBlockInAccordion: onInsertCodeBlockInAccordion,
                onRemoveBlockFromAccordion: onRemoveBlockFromAccordion,
                onMergeNestedBlockInAccordion: onMergeNestedBlockInAccordion,
                onDropActionInAccordion: onDropActionInAccordion,
                onInsertTextBlockAfterInAccordion: onInsertTextBlockAfterInAccordion,
                onInsertTableAfterInAccordion: onInsertTableAfterInAccordion,
                onInsertAccordionAfterInAccordion: onInsertAccordionAfterInAccordion,
                onInsertCodeBlockAfterInAccordion: onInsertCodeBlockAfterInAccordion,
                onInsertListAfterInAccordion: onInsertListAfterInAccordion,
                onInsertFilePathAfterInAccordion: onInsertFilePathAfterInAccordion,
                onCopyBlockInAccordion: onCopyBlockInAccordion,
                onCutBlockInAccordion: onCutBlockInAccordion,
                onPasteBlockAfterInAccordion: onPasteBlockAfterInAccordion
            )
        }
    }
}

// MARK: - Column Nested Block Controls Content

struct ColumnNestedBlockControlsContent: View {
    let block: NoteBlock
    let column: Column
    let blockHovered: Bool
    @Binding var draggingBlock: NoteBlock?
    let copiedBlock: NoteBlock?
    @Binding var selections: [UUID: AttributedTextSelection]
    var focusState: FocusState<UUID?>.Binding
    let note: RichTextNote?
    let onInsertTextBlockAfter: (NoteBlock, Column) -> Void
    let onInsertTableAfter: (NoteBlock, Column, Int, Int) -> Void
    let onInsertAccordionAfter: (NoteBlock, Column, AccordionData.HeadingLevel) -> Void
    let onInsertCodeBlockAfter: (NoteBlock, Column) -> Void
    let onInsertListAfter: (NoteBlock, Column, ListData.ListType) -> Void
    let onInsertFilePathAfter: (NoteBlock, Column) -> Void
    let onCopyBlock: (NoteBlock) -> Void
    let onCutBlock: (NoteBlock) -> Void
    let onPasteBlockAfter: (NoteBlock, Column) -> Void
    let onRemoveBlock: (NoteBlock) -> Void
    let onMergeNestedBlock: (NoteBlock, Column) -> Void
    let onDropAction: (NoteBlock, NoteBlock, DropEdge) -> Void
    // Accordion-specific callbacks (for accordions nested inside columns)
    let onInsertTableInAccordion: (AccordionData, Int, Int) -> Void
    let onInsertAccordionInAccordion: (AccordionData, AccordionData.HeadingLevel) -> Void
    let onInsertCodeBlockInAccordion: (AccordionData) -> Void
    let onRemoveBlockFromAccordion: (NoteBlock) -> Void
    let onMergeNestedBlockInAccordion: (NoteBlock, AccordionData) -> Void
    let onDropActionInAccordion: (NoteBlock, NoteBlock, DropEdge) -> Void
    let onInsertTextBlockAfterInAccordion: (NoteBlock, AccordionData) -> Void
    let onInsertTableAfterInAccordion: (NoteBlock, AccordionData, Int, Int) -> Void
    let onInsertAccordionAfterInAccordion: (NoteBlock, AccordionData, AccordionData.HeadingLevel) -> Void
    let onInsertCodeBlockAfterInAccordion: (NoteBlock, AccordionData) -> Void
    let onInsertListAfterInAccordion: (NoteBlock, AccordionData, ListData.ListType) -> Void
    let onInsertFilePathAfterInAccordion: (NoteBlock, AccordionData) -> Void
    let onCopyBlockInAccordion: (NoteBlock) -> Void
    let onCutBlockInAccordion: (NoteBlock) -> Void
    let onPasteBlockAfterInAccordion: (NoteBlock, AccordionData) -> Void
    
    @State private var isPlusHovered = false
    @State private var isGridHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // Plus button with insert menu
            Menu {
                Button {
                    onInsertTextBlockAfter(block, column)
                } label: {
                    Label("Text Block", systemImage: "text.alignleft")
                }

                Button {
                    onInsertTableAfter(block, column, 3, 3)
                } label: {
                    Label("Table", systemImage: "tablecells")
                }

                Button {
                    onInsertAccordionAfter(block, column, .h2)
                } label: {
                    Label("Accordion", systemImage: "list.bullet.indent")
                }

                Button {
                    onInsertCodeBlockAfter(block, column)
                } label: {
                    Label("Code Block", systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Menu {
                    Button {
                        onInsertListAfter(block, column, .bullet)
                    } label: {
                        Label("Bullet List", systemImage: "list.bullet")
                    }
                    Button {
                        onInsertListAfter(block, column, .numbered)
                    } label: {
                        Label("Numbered List", systemImage: "list.number")
                    }
                    Button {
                        onInsertListAfter(block, column, .checkbox)
                    } label: {
                        Label("Checkbox List", systemImage: "checklist")
                    }
                } label: {
                    Label("Lists", systemImage: "list.bullet.indent")
                }

                Divider()

                Button {
                    onInsertFilePathAfter(block, column)
                } label: {
                    Label("File Link", systemImage: "doc.badge.arrow.up")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(blockHovered ? .primary : .tertiary)
                    .frame(width: 20, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(blockHovered ? (isPlusHovered ? 0.7 : 0.5) : 0.01)
            .animation(.easeInOut(duration: 0.2), value: blockHovered)
            .animation(.easeInOut(duration: 0.15), value: isPlusHovered)
            .onHover { hovering in
                isPlusHovered = hovering
            }

            // Drag Handle
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(blockHovered ? .primary : .tertiary)
                .frame(width: 20, height: 24)
                .contentShape(Rectangle())
                .opacity(blockHovered ? (isGridHovered ? 0.7 : 0.5) : 0.01)
                .animation(.easeInOut(duration: 0.2), value: blockHovered)
                .animation(.easeInOut(duration: 0.15), value: isGridHovered)
                .onHover { hovering in
                    isGridHovered = hovering
                }
                .contentShape(Rectangle()) // Ensure the entire frame is interactive
                .contextMenu {
                    Button {
                        onCopyBlock(block)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }

                    Button {
                        onCutBlock(block)
                    } label: {
                        Label("Cut", systemImage: "scissors")
                    }

                    if copiedBlock != nil {
                        Button {
                            onPasteBlockAfter(block, column)
                        } label: {
                            Label("Paste After", systemImage: "doc.on.clipboard")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        onRemoveBlock(block)
                    } label: {
                        Label("Delete \(block.displayName)", systemImage: "trash")
                    }
                }
                .onDrag {
                    let provider = NSItemProvider(object: (block.id?.uuidString ?? "") as NSString)
                    provider.suggestedName = "Nested Block"
                    provider.registerDataRepresentation(forTypeIdentifier: UTType.noteBlock.identifier, visibility: .all) { completion in
                         let data = (block.id?.uuidString ?? "").data(using: .utf8)
                         completion(data, nil)
                         return nil
                    }
                    draggingBlock = block
                    return provider
                } preview: {
                    if block.type == .table {
                        HStack {
                            Image(systemName: "tablecells")
                            Text("Table")
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
                    } else if block.type == .accordion {
                        HStack {
                            Image(systemName: "chevron.down.circle")
                            Text(block.accordion?.heading ?? "Accordion")
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
                    } else {
                        HStack {
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 10))
                            Text(block.type == .text ? "Text Block" : block.type == .list ? "List" : block.type == .code ? "Code Block" : "Block")
                                .font(.caption)
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
                .onTapGesture {
                    // Focus the block when drag handle is tapped
                    focusState.wrappedValue = block.id
                }
            
            Group {
                if block.type == .text {
                    TextBlockView(
                        block: block,
                        selection: Binding(
                            get: {
                                if let id = block.id {
                                    return selections[id] ?? AttributedTextSelection()
                                }
                                return AttributedTextSelection()
                            },
                            set: {
                                if let id = block.id {
                                    selections[id] = $0
                                }
                            }
                        ),
                        focusState: focusState,
                        onDelete: { onRemoveBlock(block) },
                        onMerge: { onMergeNestedBlock(block, column) },
                        isNested: false
                    )
                    .padding(.top, 5) // Align text with icon 5 is correct
                } else if let listData = block.listData {
                    ListBlockView(
                        listData: listData,
                        selections: $selections,
                        focusState: focusState,
                        onDelete: { onRemoveBlock(block) }
                    )
                    .padding(.top, 5) // Push list down to align with icon
                } else if let table = block.table {
                    TableEditorView(table: table, note: nil, onDelete: { onRemoveBlock(block) })
                        .contextMenu {
                            Button(role: .destructive) { onRemoveBlock(block) } label: { Label("Delete Table", systemImage: "trash") }
                        }
                        .padding(.top, 4) // Keep this... it is the proper adjustment.
                } else if let accordion = block.accordion {
                     AccordionBlockView(
                        accordion: accordion,
                        headingSelection: Binding(
                            get: {
                                if let id = accordion.id {
                                    return selections[id] ?? AttributedTextSelection()
                                }
                                return AttributedTextSelection()
                            },
                            set: {
                                if let id = accordion.id {
                                    selections[id] = $0
                                }
                            }
                        ),
                        selections: $selections,
                        headingFocusID: accordion.id ?? UUID(),
                        focusState: focusState,
                        note: note,
                        onDelete: { onRemoveBlock(block) },
                        onInsertTable: onInsertTableInAccordion,
                        onInsertAccordion: onInsertAccordionInAccordion,
                        onInsertCodeBlock: onInsertCodeBlockInAccordion,
                        onRemoveBlock: onRemoveBlockFromAccordion,
                        onMergeNestedBlock: onMergeNestedBlockInAccordion,
                        onDropAction: onDropActionInAccordion,
                        onInsertTextBlockAfter: onInsertTextBlockAfterInAccordion,
                        onInsertTableAfter: onInsertTableAfterInAccordion,
                        onInsertAccordionAfter: onInsertAccordionAfterInAccordion,
                        onInsertCodeBlockAfter: onInsertCodeBlockAfterInAccordion,
                        onInsertListAfter: onInsertListAfterInAccordion,
                        onInsertFilePathAfter: onInsertFilePathAfterInAccordion,
                        onCopyBlock: onCopyBlockInAccordion,
                        onCutBlock: onCutBlockInAccordion,
                        onPasteBlockAfter: { block, accordion in
                            onPasteBlockAfterInAccordion(block, accordion)
                        },
                        copiedBlock: copiedBlock,
                        draggingBlock: $draggingBlock
                     )
                } else if let codeBlock = block.codeBlock {
                    CodeBlockView(codeBlock: codeBlock, note: note, onDelete: { onRemoveBlock(block) })
                } else if let imageData = block.imageData {
                    ImageBlockView(imageData: imageData, onDelete: { onRemoveBlock(block) })
                } else if let bookmarkData = block.bookmarkData {
                    BookmarkBlockView(bookmarkData: bookmarkData, onDelete: { onRemoveBlock(block) })
                } else if let filePathData = block.filePathData {
                    FilePathBlockView(filePathData: filePathData, onDelete: { onRemoveBlock(block) })
                }
            }
        }
    }
}

// MARK: - Nested Block Container
struct NestedBlockContainer<Content: View>: View {
    let block: NoteBlock
    let column: Column
    @Binding var selections: [UUID: AttributedTextSelection]
    var focusState: FocusState<UUID?>.Binding
    @Binding var draggingBlock: NoteBlock?
    @Binding var dropState: DropState?
    @Binding var blockHeights: [UUID: CGFloat]
    
    var onRemoveBlock: (NoteBlock) -> Void
    var onMergeNestedBlock: (NoteBlock, Column) -> Void
    var onDropAction: (NoteBlock, NoteBlock, DropEdge) -> Void
    
    var note: RichTextNote?
    let contentView: (NoteBlock, Column) -> Content
    
    var body: some View {
        contentView(block, column)
            .padding(4)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            if let id = block.id {
                                blockHeights[id] = geo.size.height
                            }
                        }
                        .onChange(of: geo.size.height) { _, newHeight in
                            if let id = block.id {
                                blockHeights[id] = newHeight
                            }
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
            .onDrop(of: [UTType.noteBlock], delegate: NestedBlockDropDelegate(
                block: block,
                draggingBlock: $draggingBlock,
                dropState: $dropState,
                blockHeights: blockHeights,
                reorderAction: onDropAction
            ))
    }
}

// MARK: - Column Resize Divider
struct ColumnResizeDivider: View {
    @Bindable var leftColumn: Column
    @Bindable var rightColumn: Column
    let totalRatio: Double
    let availableWidth: CGFloat
    @Binding var isDragging: Bool
    var context: ModelContext

    @State private var isHovering = false
    @State private var startLeftRatio: Double = 0
    @State private var startRightRatio: Double = 0

    // Snap positions as fractions of the combined width (left column ratio)
    private let snapPositions: [Double] = [0.25, 1.0/3.0, 0.5, 2.0/3.0, 0.75]
    private let snapThreshold: Double = 0.05 // How close to snap (5% of total)

    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(isDragging || isHovering ? Color.accentColor.opacity(0.15) : Color.clear)

            // Visual handle bar
            RoundedRectangle(cornerRadius: 2)
                .fill(isDragging || isHovering ? Color.accentColor : Color.gray.opacity(0.3))
                .frame(width: 4, height: 40)
        }
        .frame(width: 13)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            #if os(macOS)
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else if !isDragging {
                NSCursor.pop()
            }
            #endif
        }
        .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        // Guard against division by zero
                        guard availableWidth > 0, totalRatio > 0 else { return }

                        if !isDragging {
                            isDragging = true
                            startLeftRatio = leftColumn.widthRatio ?? 1.0
                            startRightRatio = rightColumn.widthRatio ?? 1.0
                        }

                        // Calculate ratio change based on drag distance
                        let combinedRatio = max(0.001, startLeftRatio + startRightRatio) // Prevent division by zero
                        let dragDistance = value.translation.width
                        let ratioChange = (dragDistance / availableWidth) * totalRatio

                        // Calculate the new left ratio as a fraction of combined
                        var newLeftRatio = startLeftRatio + ratioChange
                        let leftFraction = newLeftRatio / combinedRatio

                        // Snap to nearest position if close enough
                        for snapPos in snapPositions {
                            if abs(leftFraction - snapPos) < snapThreshold {
                                newLeftRatio = snapPos * combinedRatio
                                break
                            }
                        }

                        // Apply constraints (minimum 10% of combined ratio per column)
                        let minRatio = combinedRatio * 0.1
                        newLeftRatio = max(minRatio, min(combinedRatio - minRatio, newLeftRatio))
                        let newRightRatio = combinedRatio - newLeftRatio

                        leftColumn.widthRatio = newLeftRatio
                        rightColumn.widthRatio = newRightRatio
                    }
                    .onEnded { _ in
                        isDragging = false
                        #if os(macOS)
                        NSCursor.pop()
                        #endif
                        try? context.save()
                    }
            )
    }
}

