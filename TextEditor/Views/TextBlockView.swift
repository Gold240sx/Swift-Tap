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
    
    @State private var eventMonitor: Any?

    var body: some View {
        TextEditor(text: Binding(
            get: { block.text ?? "" },
            set: { block.text = $0 }
        ), selection: $selection)
        .focused(focusState, equals: block.id)
        .frame(minHeight: 30)
        .scrollDisabled(true)
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
            // Actually simpler: just ensure monitor is active and checks focus inside
        }
        .contextMenu {
            Button {
                onExtractSelection()
            } label: {
                Label("Extract to Block", systemImage: "rectangle.badge.plus")
            }
            .disabled(isSelectionEmpty)

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
