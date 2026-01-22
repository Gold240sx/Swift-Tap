//
//  TextBlockView.swift
//  TextEditor
//
//  A wrapper view for NoteBlock text content.
//

import SwiftUI

struct TextBlockView: View {
    @Bindable var block: NoteBlock
    @Binding var selection: AttributedTextSelection
    var focusState: FocusState<UUID?>.Binding
    var onDelete: () -> Void = {}
    var onMerge: () -> Void = {}
    var onExtractSelection: () -> Void = {}
    
    var isNested: Bool = false // Default to standard behavior
    
    @State private var eventMonitor: Any?

    var body: some View {
        Group {
            if isNested {
                MacEditorView(
                    text: Binding(
                        get: { block.text ?? AttributedString("") },
                        set: { block.text = $0 }
                    ),
                    selection: $selection,
                    font: .systemFont(ofSize: 13)
                )
            } else {
                // Legacy implementation for main editor consistency
                ZStack(alignment: .topLeading) {
                    // Hidden text for height calculation
                    Text((block.text ?? "") + "\n")
                        .font(.body)
                        .foregroundStyle(.clear)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextEditor(text: Binding(
                        get: { block.text ?? "" },
                        set: { block.text = $0 }
                    ), selection: $selection)
                    .font(.body)
                    .scrollDisabled(true)
                    .focused(focusState, equals: block.id)
                    .tint(Color(red: 0.0, green: 0.3, blue: 0.8))
                    .accentColor(Color(red: 0.0, green: 0.3, blue: 0.8))
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            setupEventMonitor()
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
        .onChange(of: focusState.wrappedValue) {
            // Re-setup monitor to be sure updates capture correct context if needed
        }
        .contextMenu {
            if !isSelectionEmpty && !isFullSelection {
                Button {
                    onExtractSelection()
                } label: {
                    Label("Make Text Block", systemImage: "rectangle.badge.plus")
                }
            }

            Button {
                selectAll()
            } label: {
                Label("Select All in Block", systemImage: "checkmark.circle")
            }
        }
    }
    
    private var isSelectionEmpty: Bool {
        guard let text = block.text else { return true }
        switch selection.indices(in: text) {
        case .ranges(let ranges):
            return ranges.ranges.isEmpty
        default:
            return true
        }
    }
    
    private var isFullSelection: Bool {
        guard let text = block.text else { return false }
        switch selection.indices(in: text) {
        case .ranges(let ranges):
            guard let first = ranges.ranges.first else { return false }
            return first.lowerBound == text.startIndex && first.upperBound == text.endIndex
        default:
            return false
        }
    }
    
    private func selectAll() {
        // Send format independent select all
        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
    }
    
    private func setupEventMonitor() {
        if eventMonitor != nil { return }
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Check if this block is focused
            guard focusState.wrappedValue == block.id else { return event }
            
            if event.keyCode == 51 { // Delete (Backspace)
                if let text = block.text {
                    // If text is selected, let the system handle standard deletion
                    if !isSelectionEmpty {
                        return event
                    }
                    
                    if text.characters.isEmpty {
                        // Empty block: delete it
                        DispatchQueue.main.async {
                            onDelete()
                        }
                        return nil // Consume event
                    } else {
                        // Check if cursor is at start
                        let indices = selection.indices(in: text)
                        var isAtStart = false
                        
                        switch indices {
                        case .insertionPoint(let index):
                            if index == text.startIndex { isAtStart = true }
                        case .ranges(let ranges):
                            if let first = ranges.ranges.first, first.lowerBound == text.startIndex {
                                isAtStart = true
                            }
                        @unknown default:
                             break
                        }
                        
                        if isAtStart {
                            // At start of non-empty block: merge with previous
                            DispatchQueue.main.async {
                                onMerge()
                            }
                            return nil // Consume event
                        }
                    }
                }
            }
            return event
        }
    }
}
