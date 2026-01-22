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
    var onRemoveBlock: (NoteBlock) -> Void = { _ in }
    var onMergeNestedBlock: (NoteBlock, Column) -> Void = { _, _ in }
    var onDropAction: (NoteBlock, NoteBlock, DropEdge) -> Void = { _, _, _ in }
    
    @Environment(\.modelContext) var context
    @State private var isHovering = false
    @Binding var draggingBlock: NoteBlock?
    @State private var dropState: DropState?
    @State private var blockHeights: [UUID: CGFloat] = [:]
    @State private var isTrashHovered = false

    @State private var viewWidth: CGFloat = 0

    var body: some View {
        let sortedColumns = columnData.columns.sorted(by: { $0.orderIndex < $1.orderIndex })
        let totalRatio = sortedColumns.reduce(0.0) { $0 + $1.widthRatio }
        
        let numberOfColumns = CGFloat(columnData.columns.count)
        let totalPadding = numberOfColumns * 16 // 8 leading + 8 trailing per column
        let availableWidth = max(0, viewWidth - totalPadding)
        
        // Debug width calculations
        let _ = print("ColumnBlockView rendering \(columnData.columns.count) columns. ViewWidth: \(viewWidth), AvailableWidth: \(availableWidth), TotalRatio: \(totalRatio)")
        
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
                    draggingBlock: $draggingBlock,
                    dropState: $dropState,
                    blockHeights: $blockHeights,
                    note: note
                )
            }
        }
        // Force equal height for all columns in the HStack
        .fixedSize(horizontal: false, vertical: true)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.5), lineWidth: isTrashHovered ? 2 : 0)
                .padding(-4)
        )
        // Main block overlay
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
        .frame(maxWidth: .infinity, minHeight: 100) // Ensure it has some minimum height
        .measureWidth { width in
            viewWidth = width
            print("ColumnBlockView measured width: \(width)")
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
    
    @Binding var draggingBlock: NoteBlock?
    @Binding var dropState: DropState?
    @Binding var blockHeights: [UUID: CGFloat]
    
    var note: RichTextNote?
    
    @Environment(\.modelContext) var context
    @State private var isHovering = false

    var body: some View {
        let columnWidth = max(0, (column.widthRatio / totalRatio) * availableWidth)
        
        // Debug print to track width changes
        let _ = print("Column \(column.id) - Ratio: \(column.widthRatio), AvailableWidth: \(availableWidth), Calculated Width: \(columnWidth)")
        
        VStack(alignment: .leading, spacing: 8) {
            ForEach(column.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })) { block in
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
        let sorted = column.blocks.sorted(by: { $0.orderIndex < $1.orderIndex })
        let newIndex = (sorted.last?.orderIndex ?? -1) + 1
        let newBlock = NoteBlock(orderIndex: newIndex, text: "", type: .text)
        newBlock.parentColumn = column
        column.blocks.append(newBlock)
        context.insert(newBlock)
        
        // Focus new block
        focusState.wrappedValue = newBlock.id
        try? context.save()
    }
    
    @ViewBuilder
    private func nestedBlockView(for block: NoteBlock, in column: Column) -> some View {
        HStack(alignment: .top, spacing: 6) {
            // Drag Handle
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 16, height: 20)
                .padding(.top, block.type == .text ? 8 : 4) // Align with text content (approx 8px inset) or standard blocks
                .contentShape(Rectangle()) // Ensure the entire frame is interactive
                .onDrag {
                    let provider = NSItemProvider(object: block.id.uuidString as NSString)
                    provider.suggestedName = "Nested Block"
                    provider.registerDataRepresentation(forTypeIdentifier: UTType.noteBlock.identifier, visibility: .all) { completion in
                         let data = block.id.uuidString.data(using: .utf8)
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
                            get: { selections[block.id] ?? AttributedTextSelection() },
                            set: { selections[block.id] = $0 }
                        ),
                        focusState: focusState,
                        onDelete: { onRemoveBlock(block) },
                        onMerge: { onMergeNestedBlock(block, column) },
                        isNested: true
                    )
                } else if let listData = block.listData {
                    ListBlockView(
                        listData: listData,
                        selections: $selections,
                        focusState: focusState,
                        onDelete: { onRemoveBlock(block) }
                    )
                } else if let table = block.table {
                    TableEditorView(table: table, note: nil, onDelete: { onRemoveBlock(block) })
                        .contextMenu {
                            Button(role: .destructive) { onRemoveBlock(block) } label: { Label("Delete Table", systemImage: "trash") }
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
                        focusState: focusState,
                        note: note,
                        onDelete: { onRemoveBlock(block) },
                        draggingBlock: $draggingBlock
                     )
                } else if let codeBlock = block.codeBlock {
                    CodeBlockView(codeBlock: codeBlock, note: note, onDelete: { onRemoveBlock(block) })
                } else if let imageData = block.imageData {
                    ImageBlockView(imageData: imageData, onDelete: { onRemoveBlock(block) })
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
                        .onAppear { blockHeights[block.id] = geo.size.height }
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
            .onDrop(of: [UTType.noteBlock], delegate: NestedBlockDropDelegate(
                block: block,
                draggingBlock: $draggingBlock,
                dropState: $dropState,
                blockHeights: blockHeights,
                reorderAction: onDropAction
            ))
    }
}


