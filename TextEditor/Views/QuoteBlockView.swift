//
//  QuoteBlockView.swift
//  TextEditor
//
//  A quote block with a thick left border.
//

import SwiftUI

struct QuoteBlockView: View {
    @Bindable var block: NoteBlock
    @Binding var selection: AttributedTextSelection
    var focusState: FocusState<UUID?>.Binding
    var onDelete: () -> Void = {}
    var onMerge: () -> Void = {}

    @State private var eventMonitor: Any?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Thick left border
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 4)

            // Text content with left padding
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
                    set: { newValue in
                        // Normalize fonts - remove font family/styles but preserve bold/italic
                        let normalized = FontNormalizer.normalizeFonts(newValue)
                        block.text = normalized
                    }
                ), selection: $selection)
                .font(.body)
                .scrollDisabled(true)
                .focused(focusState, equals: block.id)
                .tint(Color(red: 0.0, green: 0.3, blue: 0.8))
            }
            .padding(.leading, 12)
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

    private func setupEventMonitor() {
        if eventMonitor != nil { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard focusState.wrappedValue == block.id else { return event }

            if event.keyCode == 51 { // Delete (Backspace)
                if let text = block.text {
                    if !isSelectionEmpty {
                        return event
                    }

                    if text.characters.isEmpty {
                        DispatchQueue.main.async {
                            onDelete()
                        }
                        return nil
                    } else {
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
                            DispatchQueue.main.async {
                                onMerge()
                            }
                            return nil
                        }
                    }
                }
            }

            return event
        }
    }
}
