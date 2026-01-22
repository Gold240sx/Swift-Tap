//
//  AccordionBlockView.swift
//  TextEditor
//
//  Expandable/collapsible accordion block view (like Notion toggles).
//  Supports nested blocks (text, tables, accordions) within its content.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AccordionBlockView: View {
    @Bindable var accordion: AccordionData
    @Binding var headingSelection: AttributedTextSelection
    @Binding var selections: [UUID: AttributedTextSelection]
    var headingFocusID: UUID
    var focusState: FocusState<UUID?>.Binding
    var note: RichTextNote?
    var onDelete: () -> Void = {}
    var onInsertTable: (AccordionData, Int, Int) -> Void = { _, _, _ in }
    var onInsertAccordion: (AccordionData, AccordionData.HeadingLevel) -> Void = { _, _ in }
    var onInsertCodeBlock: (AccordionData) -> Void = { _ in }
    var onRemoveBlock: (NoteBlock) -> Void = { _ in }
    var onMergeNestedBlock: (NoteBlock, AccordionData) -> Void = { _, _ in }
    var onDropAction: (NoteBlock, NoteBlock, DropEdge) -> Void = { _, _, _ in }
    @Environment(\.modelContext) var context
    @State private var isHovering = false
    @State private var showTablePicker = false
    @State private var showAccordionPicker = false
    @Binding var draggingBlock: NoteBlock?
    @State private var dropState: DropState?
    @State private var blockHeights: [UUID: CGFloat] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            .padding(.vertical, 4) // More vertical padding when collapsed for centering
            .padding(.horizontal, 12)

            // Expandable content with nested blocks
            expandedContentView
        }
        .background(Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    // MARK: - Subviews
    
    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .top, spacing: 8) {
            // Editable heading
            TextEditor(text: headingBinding, selection: $headingSelection)
                .focused(focusState, equals: headingFocusID)
                .font(headingFont)
                .fontWeight(.semibold)
                .scrollDisabled(true)
                .frame(minHeight: headingFontSize + 4)

            // Delete button (shows on hover)
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(width: 24, height: 24)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
            .padding(.top, 4)


            // Expand/collapse button on right
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    accordion.isExpanded.toggle()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(accordion.isExpanded ? 90 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: accordion.isExpanded)
                    .frame(width: 24, height: 24)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var expandedContentView: some View {
        if accordion.isExpanded {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(accordion.contentBlocks.sorted(by: { $0.orderIndex < $1.orderIndex })) { block in
                    nestedBlockView(for: block)
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
                        .onDrop(of: [UTType.noteBlock], delegate: NestedBlockDropDelegate(
                            block: block,
                            draggingBlock: $draggingBlock,
                            dropState: $dropState,
                            blockHeights: blockHeights,
                            reorderAction: onDropAction
                        ))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5) // 5px padding in accordion content
            .padding(.bottom, 3)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal: .opacity
            ))
        }
    }

    // MARK: - Nested Block Rendering

    @ViewBuilder
    private func nestedBlockView(for block: NoteBlock) -> some View {
        HStack(alignment: .top, spacing: 6) {
            // Drag handle icon
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 16, height: 20)
                .padding(.bottom, 2)
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
                    // Drag preview
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
                // Also allowing drop on the entire row for better target area
                .onDrop(of: [UTType.noteBlock], delegate: NestedBlockDropDelegate(
                    block: block,
                    draggingBlock: $draggingBlock,
                    dropState: $dropState,
                    blockHeights: blockHeights,
                    reorderAction: onDropAction
                ))

            // Block content
            Group {
                if block.type == .text {
                    TextBlockView(
                        block: block,
                        selection: Binding(
                            get: { selections[block.id] ?? AttributedTextSelection() },
                            set: { selections[block.id] = $0 }
                        ),
                        focusState: focusState,
                        onDelete: {
                            onRemoveBlock(block)
                        },
                        onMerge: {
                            onMergeNestedBlock(block, accordion)
                        }
                    )
                } else if let table = block.table {
                    TableEditorView(table: table, note: nil, onDelete: {
                        onRemoveBlock(block)
                    })
                    .contextMenu {
                        Button(role: .destructive) {
                            onRemoveBlock(block)
                        } label: {
                            Label("Delete Table", systemImage: "trash")
                        }
                    }
                } else if let nestedAccordion = block.accordion {
                    //Recursive rendering for nested accordions
                    AccordionBlockView(
                        accordion: nestedAccordion,
                        headingSelection: Binding(
                            get: { selections[nestedAccordion.id] ?? AttributedTextSelection() },
                            set: { selections[nestedAccordion.id] = $0 }
                        ),
                        selections: $selections,
                        headingFocusID: nestedAccordion.id,
                        focusState: focusState,
                        note: note,
                        onDelete: {
                            onRemoveBlock(block)
                        },
                        onInsertTable: onInsertTable,
                        onInsertAccordion: onInsertAccordion,
                        onInsertCodeBlock: onInsertCodeBlock,
                        onRemoveBlock: onRemoveBlock,
                        onMergeNestedBlock: onMergeNestedBlock,
                        onDropAction: onDropAction,
                        draggingBlock: $draggingBlock
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            onRemoveBlock(block)
                        } label: {
                            Label("Delete Accordion", systemImage: "trash")
                        }
                    }
                } else if let codeBlock = block.codeBlock {
                    CodeBlockView(
                        codeBlock: codeBlock,
                        note: note,
                        onDelete: {
                            onRemoveBlock(block)
                        }
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            onRemoveBlock(block)
                        } label: {
                            Label("Delete Code Block", systemImage: "trash")
                        }
                    }
                } else if let imageData = block.imageData {
                    ImageBlockView(
                        imageData: imageData,
                        onDelete: {
                            onRemoveBlock(block)
                        }
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            onRemoveBlock(block)
                        } label: {
                            Label("Delete Image", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bindings

    private var headingBinding: Binding<AttributedString> {
        Binding(
            get: { accordion.heading },
            set: { accordion.heading = $0 }
        )
    }

    // MARK: - Heading Level Styling

    private var headingFont: Font {
        switch accordion.level {
        case .h1: return .title
        case .h2: return .title2
        case .h3: return .title3
        }
    }

    private var headingFontSize: CGFloat {
        switch accordion.level {
        case .h1: return 28
        case .h2: return 22
        case .h3: return 18
        }
    }
}

// MARK: - Nested Block Drop Delegate

struct NestedBlockDropDelegate: DropDelegate {
    let block: NoteBlock
    @Binding var draggingBlock: NoteBlock?
    @Binding var dropState: DropState?
    let blockHeights: [UUID: CGFloat]
    let reorderAction: (NoteBlock, NoteBlock, DropEdge) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [UTType.noteBlock])
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingBlock, dragging.id != block.id else { return }
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
             reorderAction(dragging, block, state.edge)
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

// Preview requires running app due to SwiftData model dependencies
