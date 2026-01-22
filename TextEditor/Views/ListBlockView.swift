//
//  ListBlockView.swift
//  TextEditor
//
//  Renders a complete list block with title and items.
//

import SwiftUI
import SwiftData

struct ListBlockView: View {
    @Bindable var listData: ListData
    @Binding var selections: [UUID: AttributedTextSelection]
    var focusState: FocusState<UUID?>.Binding
    var onDelete: () -> Void = {}

    @Environment(\.modelContext) private var context
    @FocusState private var focusedItemID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // List title
            TextField("List Title", text: Binding(
                get: { listData.title ?? "" },
                set: { listData.title = $0.isEmpty ? nil : $0 }
            ))
            .font(.system(size: 16, weight: .semibold))
            .textFieldStyle(.plain)
            .padding(.leading, 20)
            .padding(.bottom, 15)

            // List items
            ForEach(listData.items.sorted(by: { $0.orderIndex < $1.orderIndex })) { item in
                ListItemView(
                    item: item,
                    listType: listData.listType,
                    number: getItemNumber(for: item),
                    selection: Binding(
                        get: { selections[item.id] ?? AttributedTextSelection() },
                        set: { selections[item.id] = $0 }
                    ),
                    focusState: focusState,
                    onEnter: {
                        insertItemAfter(item)
                    },
                    onBackspaceAtStart: {
                        handleBackspaceAtStart(for: item)
                    }
                )
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete List", systemImage: "trash")
            }
        }
    }

    private func getItemNumber(for item: ListItem) -> Int {
        let sorted = listData.items.sorted(by: { $0.orderIndex < $1.orderIndex })
        if let index = sorted.firstIndex(where: { $0.id == item.id }) {
            return index + 1
        }
        return 1
    }

    private func insertItemAfter(_ item: ListItem) {
        let sorted = listData.items.sorted(by: { $0.orderIndex < $1.orderIndex })
        let targetIndex = item.orderIndex + 1

        // Check if current item is empty - if so, convert to text block behavior
        if item.text?.characters.isEmpty ?? true {
            // If this is the only item, delete the list
            if sorted.count == 1 {
                onDelete()
                return
            }
            // Otherwise just remove this empty item
            removeItem(item)
            return
        }

        // Get cursor position and split text
        var suffixText: AttributedString = ""
        if let text = item.text,
           let selection = selections[item.id] {
            var cursorIndex: AttributedString.Index?
            switch selection.indices(in: text) {
            case .insertionPoint(let index):
                cursorIndex = index
            case .ranges(let rangeSet):
                if let lastRange = rangeSet.ranges.last {
                    cursorIndex = lastRange.upperBound
                }
            @unknown default:
                break
            }

            if let index = cursorIndex, index < text.endIndex {
                let prefix = AttributedString(text[..<index])
                suffixText = AttributedString(text[index...])
                item.text = prefix
            }
        }

        // Shift subsequent items
        for i in listData.items where i.orderIndex >= targetIndex {
            i.orderIndex += 1
        }

        // Create new item
        let newItem = ListItem(orderIndex: targetIndex, text: suffixText)
        newItem.parentList = listData
        listData.items.append(newItem)
        context.insert(newItem)

        try? context.save()

        // Focus new item
        DispatchQueue.main.async {
            focusState.wrappedValue = newItem.id
        }
    }

    private func handleBackspaceAtStart(for item: ListItem) {
        let sorted = listData.items.sorted(by: { $0.orderIndex < $1.orderIndex })
        guard let index = sorted.firstIndex(where: { $0.id == item.id }) else { return }

        if index == 0 {
            // First item - if empty, could delete list or convert
            if item.text?.characters.isEmpty ?? true {
                if sorted.count == 1 {
                    onDelete()
                }
            }
            return
        }

        // Merge with previous item
        let prevItem = sorted[index - 1]
        if let currentText = item.text {
            var combined = prevItem.text ?? AttributedString("")
            combined.append(currentText)
            prevItem.text = combined
        }

        // Remove current item
        removeItem(item)

        // Focus previous item
        focusState.wrappedValue = prevItem.id
    }

    private func removeItem(_ item: ListItem) {
        let removedIndex = item.orderIndex
        listData.items.removeAll { $0.id == item.id }
        context.delete(item)

        // Re-index
        for i in listData.items where i.orderIndex > removedIndex {
            i.orderIndex -= 1
        }

        try? context.save()
    }
}

// MARK: - List Item View

struct ListItemView: View {
    @Bindable var item: ListItem
    let listType: ListData.ListType
    let number: Int
    @Binding var selection: AttributedTextSelection
    var focusState: FocusState<UUID?>.Binding
    var onEnter: () -> Void
    var onBackspaceAtStart: () -> Void

    @State private var eventMonitor: Any?

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // List prefix
            listPrefix
                .frame(width: 24, alignment: listType == .numbered ? .trailing : .center)

            // Text content
            ZStack(alignment: .topLeading) {
                // Hidden text for height calculation
                Text((item.text ?? "") + "\n")
                    .font(.body)
                    .foregroundStyle(.clear)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 0)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextEditor(text: Binding(
                    get: { item.text ?? "" },
                    set: { item.text = $0 }
                ), selection: $selection)
                .font(.body)
                .scrollDisabled(true)
                .focused(focusState, equals: item.id)
                .tint(Color(red: 0.0, green: 0.3, blue: 0.8))
            }
            .padding(.vertical, -4)
        }
        .padding(.leading, 16)
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

    @ViewBuilder
    private var listPrefix: some View {
        switch listType {
        case .bullet:
            Text("\u{2022}")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .offset(y: -5)
        case .numbered:
            Text("\(number).")
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .offset(y: -3)
        case .checkbox:
            Toggle("", isOn: $item.isChecked)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .offset(y: -4)
        }
    }

    private func setupEventMonitor() {
        if eventMonitor != nil { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard focusState.wrappedValue == item.id else { return event }

            // Enter key
            if event.keyCode == 36 {
                DispatchQueue.main.async {
                    onEnter()
                }
                return nil
            }

            // Backspace key
            if event.keyCode == 51 {
                if let text = item.text {
                    if text.characters.isEmpty {
                        DispatchQueue.main.async {
                            onBackspaceAtStart()
                        }
                        return nil
                    }

                    // Check if cursor at start
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
                            onBackspaceAtStart()
                        }
                        return nil
                    }
                }
            }

            return event
        }
    }
}
