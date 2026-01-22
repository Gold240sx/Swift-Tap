//
//  TableEditorView.swift
//  TextEditor
//
//  Numbers-style interactive table editor with grid layout, headers, and controls.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TableEditorView: View {
    @Bindable var table: TableData
    var note: RichTextNote? // Add note reference
    @Environment(\.modelContext) var context
    @State private var showSettings: Bool = false
    @State private var isEditing: Bool = false
    @State private var selectedColumns: Set<Int> = []
    @State private var selectedRows: Set<Int> = []
    @State private var selectedCells: Set<CellIndex> = []
    @State private var editingCellID: CellIndex?
    @State private var dragColumnWidths: [Int: Double] = [:]
    @State private var dragRowHeights: [Int: Double] = [:]
    @State private var startDragWidths: [Int: Double] = [:]
    @State private var startDragHeights: [Int: Double] = [:]
    @State private var lastSelectedColumn: Int?
    @State private var lastSelectedRow: Int?
    @State private var lastSelectedCell: CellIndex?
    @State private var isHovering: Bool = false
    @State private var showJSONPopover: Bool = false
    
    var onDelete: () -> Void = {}

    
    struct CellIndex: Hashable {
        let row: Int
        let col: Int
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let totalWidth = calculateTableWidth()
            
            headerSection
                .frame(maxWidth: totalWidth + (isEditing ? 28 : 0))
            
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    // Table scroll area – consume taps so outer clear‑selection gesture does not fire when interacting with the table
                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(spacing: 0) {
                            // Column Headers Row (Includes empty corner cell)
                            HStack(spacing: 0) {
                                if isEditing {
                                    cornerCell
                                }
                                ForEach(0..<table.columnCount, id: \.self) { col in
                                    columnHeaderCell(col)
                                }
                            }
                            
                            // Table Content Grid (Includes row numbers in each row)
                            VStack(spacing: 0) {
                                ForEach(0..<table.rowCount, id: \.self) { row in
                                    HStack(spacing: 0) {
                                        if isEditing {
                                            rowNumberCell(row)
                                        }
                                        ForEach(0..<table.columnCount, id: \.self) { col in
                                            contentCell(row: row, col: col)
                                        }
                                    }
                                    .frame(minHeight: 36)
                                    .frame(height: dragRowHeights[row] ?? table.getRowHeight(at: row))
                                }
                            }
                        }
                        .frame(width: totalWidth)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .frame(maxWidth: totalWidth)
                    
                    addRowButton
                }
                
                addColumnButton
            }
            .frame(maxWidth: totalWidth + (isEditing ? 28 : 0))
            // Clear selection when clicking anywhere outside the table content
            .contentShape(Rectangle())
            .onTapGesture {
                // Deselect everything when clicking the empty space around the table
                selectedRows.removeAll()
                selectedColumns.removeAll()
                selectedCells.removeAll()
                lastSelectedCell = nil
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
        #if os(macOS)
        .onCopyCommand {
            copySelectedContent()
            return []
        }
        .onPasteCommand(of: [UTType.text]) { items in
            pasteFromClipboard()
        }
        .onDeleteCommand {
            deleteSelectedColumns()
            deleteSelectedRows()
            for cell in selectedCells {
                table.setCell(row: cell.row, column: cell.col, content: "")
            }
            try? context.save()
        }
        #endif
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            // Signal other tables to deselect
            NotificationCenter.default.post(name: NSNotification.Name("DeselectAllTables"), object: nil)
            
            if !isEditing {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isEditing = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeselectAllTables"))) { notification in
            if let senderID = notification.object as? UUID, senderID == table.id {
                return
            }
            selectedRows.removeAll()
            selectedColumns.removeAll()
            selectedCells.removeAll()
            lastSelectedCell = nil
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        if !table.showTitle && !isHovering && !isEditing && !showSettings && !showJSONPopover {
            EmptyView()
        } else {
            HStack {
                if isEditing {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isEditing = false
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .green)
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isEditing = true
                        }
                    } label: {
                        Label("Edit", systemImage: "pencil.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovering ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isHovering)
                }
                
                if table.showTitle {
                    TextField("Table Name", text: $table.title)
                        .font(.headline)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                } else {
                    Spacer()
                }
                
                settingsButton
            }
            .padding(.horizontal, isEditing ? 0 : 4) // Adjust padding based on mode
            .padding(.bottom, 4)
            .contentShape(Rectangle()) // Ensure entire header area is hoverable
            .frame(minHeight: 32)
        }
    }
    
    @ViewBuilder
    private var settingsButton: some View {
        Button {
            showSettings.toggle()
        } label: {
            Image(systemName: "gearshape.fill")
                .foregroundStyle(.secondary)
                .font(.title3)
        }
        .buttonStyle(.plain)
        .opacity(isHovering || showSettings ? 1 : 0)
        .popover(isPresented: $showSettings) {
            TableSettingsView(table: table, onDelete: onDelete)
        }
        
        Button {
            showJSONPopover.toggle()
        } label: {
            Image(systemName: "curlybraces")
                .foregroundStyle(.secondary)
                .font(.title3)
        }
        .buttonStyle(.plain)
        .opacity(isHovering || showJSONPopover ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .popover(isPresented: $showJSONPopover) {
            if let note = note {
                JsonOutputView(note: note)
                    .frame(width: 400, height: 500)
            } else {
                Text("Note data unavailable")
                    .padding()
            }
        }
    }
            
    private var cornerCell: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.05))
            .frame(width: 36, height: 36)
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            )
            .onTapGesture {
                // Clear any selection when clicking the corner area
                selectedRows.removeAll()
                selectedColumns.removeAll()
                selectedCells.removeAll()
                lastSelectedCell = nil
            }
    }
    
    private func rowNumberCell(_ row: Int) -> some View {
        Text("\(row + 1)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(selectedRows.contains(row) ? .white : .secondary)
            .frame(width: 36)
            .frame(minHeight: 36)
            .frame(maxHeight: .infinity)
            .background(selectedRows.contains(row) ? Color.accentColor : Color.gray.opacity(0.05))
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            )
            .overlay(alignment: .bottom) {
                rowResizeHandle(row)
            }
            .onTapGesture {
                handleRowTap(row)
            }
            .contextMenu {
                Button("Add Header Column") {
                    table.hasHeaderColumn = true
                    try? context.save()
                }
                if !selectedRows.isEmpty {
                    Button("Delete Selected Rows", role: .destructive) {
                        deleteSelectedRows()
                    }
                }
            }
    }
    
    private func handleRowTap(_ row: Int) {
        // Signal other tables to deselect
        NotificationCenter.default.post(name: NSNotification.Name("DeselectAllTables"), object: table.id)
        
        #if os(macOS)
        let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCommandCheck = flags.contains(.command) || flags.contains(.control)
        let isShiftCheck = flags.contains(.shift)
        
        if isShiftCheck, let last = lastSelectedRow {
            // Range selection
            let start = min(last, row)
            let end = max(last, row)
            for r in start...end {
                selectedRows.insert(r)
            }
        } else if isCommandCheck {
            // Toggle selection
            if selectedRows.contains(row) {
                selectedRows.remove(row)
            } else {
                selectedRows.insert(row)
                lastSelectedRow = row
            }
        } else {
            // Single selection
            if selectedRows.contains(row) && selectedRows.count == 1 {
                selectedRows.remove(row)
                lastSelectedRow = nil
            } else {
                selectedRows = [row]
                selectedColumns.removeAll()
                selectedCells.removeAll()
                lastSelectedRow = row
            }
        }
        #else
        if selectedRows.contains(row) {
            selectedRows.remove(row)
        } else {
            selectedRows = [row]
            selectedColumns.removeAll()
            selectedCells.removeAll()
        }
        lastSelectedRow = row
        #endif
    }
    
    @ViewBuilder
    private var columnHeadersRow: some View {
        if isEditing {
            HStack(spacing: 0) {
                ForEach(0..<table.columnCount, id: \.self) { col in
                    columnHeaderCell(col)
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
        }
    }
    
    private func columnHeaderCell(_ col: Int) -> some View {
        Text(columnLabel(col))
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(selectedColumns.contains(col) ? .white : .secondary)
            .frame(width: CGFloat(dragColumnWidths[col] ?? table.getColumnWidth(at: col)))
            .frame(height: 36)
            .background(selectedColumns.contains(col) ? Color.accentColor : Color.gray.opacity(0.05))
            .overlay(
                columnResizeHandle(col)
            )
            .onTapGesture {
                handleColumnTap(col)
            }
            .contextMenu {
                // Corrected: Context menu on Column Header (Top Bar) controls the Header Row (Top Bar)
                Button("Add Header Row") {
                    table.hasHeaderRow = true
                    try? context.save()
                }
                if !selectedColumns.isEmpty {
                    Button("Delete Selected Columns", role: .destructive) {
                        deleteSelectedColumns()
                    }
                }
            }
    }
    
    private func handleColumnTap(_ col: Int) {
        // Signal other tables to deselect
        NotificationCenter.default.post(name: NSNotification.Name("DeselectAllTables"), object: table.id)
        
        #if os(macOS)
        let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCommandCheck = flags.contains(.command) || flags.contains(.control)
        let isShiftCheck = flags.contains(.shift)
        
        if isShiftCheck, let last = lastSelectedColumn {
            // Range selection
            let start = min(last, col)
            let end = max(last, col)
            for c in start...end {
                selectedColumns.insert(c)
            }
        } else if isCommandCheck {
            // Toggle selection
            if selectedColumns.contains(col) {
                selectedColumns.remove(col)
            } else {
                selectedColumns.insert(col)
                lastSelectedColumn = col
            }
        } else {
            // Single selection
            if selectedColumns.contains(col) && selectedColumns.count == 1 {
                // If clicking the only selected column, deselect it
                selectedColumns.remove(col)
                lastSelectedColumn = nil
            } else {
                selectedColumns = [col]
                selectedRows.removeAll()
                lastSelectedColumn = col
            }
        }
        #else
        // iOS Fallback (just basic toggle for now)
        if selectedColumns.contains(col) {
            selectedColumns.remove(col)
        } else {
            selectedColumns = [col]
            selectedRows.removeAll()
        }
        lastSelectedColumn = col
        #endif
    }
    
    private func columnResizeHandle(_ col: Int) -> some View {
        ZStack(alignment: .trailing) {
            Rectangle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: 6, height: 36)
                .contentShape(Rectangle())
                .onHover { isInside in
                    #if os(macOS)
                    if isInside {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                    #endif
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if startDragWidths[col] == nil {
                                startDragWidths[col] = table.getColumnWidth(at: col)
                            }
                            if let startWidth = startDragWidths[col] {
                                let newWidth = max(startWidth + Double(value.translation.width), 40)
                                dragColumnWidths[col] = newWidth
                            }
                        }
                        .onEnded { _ in
                            if let finalWidth = dragColumnWidths[col] {
                                table.setColumnWidth(at: col, width: finalWidth)
                            }
                            startDragWidths.removeValue(forKey: col)
                            dragColumnWidths.removeValue(forKey: col)
                            try? context.save()
                        }
                )
        }
    }

    private func rowResizeHandle(_ row: Int) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 6)
            Rectangle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        }
        .contentShape(Rectangle())
        .onHover { isInside in
            #if os(macOS)
            if isInside {
                NSCursor.resizeUpDown.push()
            } else {
                NSCursor.pop()
            }
            #endif
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if startDragHeights[row] == nil {
                        startDragHeights[row] = dragRowHeights[row] ?? table.getRowHeight(at: row)
                    }
                    if let startHeight = startDragHeights[row] {
                        let newHeight = max(startHeight + Double(value.translation.height), 36)
                        dragRowHeights[row] = newHeight
                    }
                }
                .onEnded { _ in
                    if let finalHeight = dragRowHeights[row] {
                        table.setRowHeight(at: row, height: finalHeight)
                    }
                    startDragHeights.removeValue(forKey: row)
                    dragRowHeights.removeValue(forKey: row)
                    try? context.save()
                }
        )
    }
    
    // tableContentGrid replaced by inline implementation in ScrollView
    
    private func contentCell(row: Int, col: Int) -> some View {
        TableCellView(
            table: table, 
            row: row, 
            column: col,
            isRowSelected: selectedRows.contains(row),
            isColumnSelected: selectedColumns.contains(col),
            isSelected: selectedCells.contains(CellIndex(row: row, col: col)),
            selectedEdges: getSelectionEdges(row: row, col: col),
            onCopy: { copySelectedContent() },
            onPaste: { pasteFromClipboard() },
            isEditingFromParent: editingCellID == CellIndex(row: row, col: col)
        )
        .frame(width: CGFloat(dragColumnWidths[col] ?? table.getColumnWidth(at: col)))
        .frame(maxHeight: .infinity)
        .onTapGesture(count: 2) {
            // Double click to edit immediately
            editingCellID = CellIndex(row: row, col: col)
            selectedCells.removeAll()
            selectedRows.removeAll()
            selectedColumns.removeAll()
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                // Single click to select
                handleCellTap(row: row, col: col)
            }
        )
    }
    
    @ViewBuilder
    private var addColumnButton: some View {
        if isEditing {
            Button {
                // Smart "Add Column Right" logic
                // 1. Determine target index based on selection
                var targetIndex = table.columnCount
                
                if let maxCol = selectedColumns.max() {
                    targetIndex = maxCol + 1
                } else if let maxCellCol = selectedCells.map({ $0.col }).max() {
                    targetIndex = maxCellCol + 1
                } else if let editingID = editingCellID {
                    targetIndex = editingID.col + 1
                }
                
                // 2. Insert at calculated index
                table.insertColumn(at: targetIndex)
                try? context.save()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.15))
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                }
                .frame(width: 16)
            }
            .buttonStyle(.plain)
            // Height matches header (36) + sum of all row heights
            .frame(height: 36 + calculateTableHeightFromRows())
            .padding(.leading, 8)
            .padding(.trailing, 4) // Add space on the right edge
        }
    }
    
    @ViewBuilder
    private var addRowButton: some View {
        if isEditing {
            Button {
                table.addRow()
                try? context.save()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.15))
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentColor)
                }
                .frame(height: 16)
            }
            .buttonStyle(.plain)
            // Match the width of the content columns (table width minus row numbers)
            .frame(maxWidth: calculateTableWidth() - (isEditing ? 36 : 0))
            .padding(.leading, isEditing ? 36 : 0)
            .padding(.top, 6)
        }
    }
    
    // MARK: - Selection & Clipboard
    
    // MARK: - Selection Logic
    
    private func isCellSelected(_ r: Int, _ c: Int) -> Bool {
        if selectedCells.contains(CellIndex(row: r, col: c)) { return true }
        if selectedRows.contains(r) { return true }
        if selectedColumns.contains(c) { return true }
        if editingCellID == CellIndex(row: r, col: c) { return true }
        return false
    }
    
    private func getSelectionEdges(row: Int, col: Int) -> Edge.Set {
        if !isCellSelected(row, col) { return [] }
        
        var edges: Edge.Set = []
        
        // Check neighbors
        if !isCellSelected(row - 1, col) { edges.insert(.top) }
        if !isCellSelected(row + 1, col) { edges.insert(.bottom) }
        if !isCellSelected(row, col - 1) { edges.insert(.leading) }
        if !isCellSelected(row, col + 1) { edges.insert(.trailing) }
        
        return edges
    }

    private func handleCellTap(row: Int, col: Int) {
        // Signal other tables to deselect
        NotificationCenter.default.post(name: NSNotification.Name("DeselectAllTables"), object: table.id)
        
        // When tapping a cell, we clear text editing from any other cell
        if editingCellID != CellIndex(row: row, col: col) {
            editingCellID = nil
        }
    
        let index = CellIndex(row: row, col: col)
        
        #if os(macOS)
        let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isControl = flags.contains(.control) || flags.contains(.command)
        let isShift = flags.contains(.shift)
        #else
        let isControl = false
        let isShift = false
        #endif
        
        // ----- No Modifiers -----
        if !isControl && !isShift {
            selectedCells = [index]
            selectedRows.removeAll()
            selectedColumns.removeAll()
            lastSelectedCell = index
            return
        }
        
        // ----- Control Modifier -----
        if isControl {
            if selectedCells.contains(index) {
                // If CTRL-clicked an already selected cell, remove it.
                selectedCells.remove(index)
            } else {
                // Add it to the selection group.
                selectedCells.insert(index)
                lastSelectedCell = index
            }
            // Preserve existing row/column selections.
            return
        }
        
        // ----- Shift Modifier -----
        if isShift {
            let anchor = lastSelectedCell ?? index
            // Clear previous cell selections (standard range behavior replaces prior range).
            selectedCells.removeAll()
            
            let minR = min(anchor.row, row)
            let maxR = max(anchor.row, row)
            let minC = min(anchor.col, col)
            let maxC = max(anchor.col, col)
            
            for r in minR...maxR {
                for c in minC...maxC {
                    selectedCells.insert(CellIndex(row: r, col: c))
                }
            }
            
            selectedRows.removeAll()
            selectedColumns.removeAll()
            // Anchor stays the same for further shift-dragging.
            lastSelectedCell = anchor
            return
        }
    }
    
    private func copySelectedContent() {
        var contentToCopy = ""
        
        // Determine which cells are actually selected (including via row/col selection)
        let cellsToCopy: [CellIndex]
        if !selectedRows.isEmpty {
            cellsToCopy = selectedRows.flatMap { r in (0..<table.columnCount).map { c in CellIndex(row: r, col: c) } }
        } else if !selectedColumns.isEmpty {
            cellsToCopy = selectedColumns.flatMap { c in (0..<table.rowCount).map { r in CellIndex(row: r, col: c) } }
        } else if !selectedCells.isEmpty {
            cellsToCopy = selectedCells.sorted { a, b in
                if a.row != b.row { return a.row < b.row }
                return a.col < b.col
            }
        } else {
            return
        }
        
        guard !cellsToCopy.isEmpty else { return }
        
        // Find grid boundaries
        let minRow = cellsToCopy.map(\.row).min() ?? 0
        let maxRow = cellsToCopy.map(\.row).max() ?? 0
        let minCol = cellsToCopy.map(\.col).min() ?? 0
        let maxCol = cellsToCopy.map(\.col).max() ?? 0
        
        // Build TSV string
        for r in minRow...maxRow {
            var rowText = ""
            for c in minCol...maxCol {
                if cellsToCopy.contains(CellIndex(row: r, col: c)) {
                    let content = table.getCell(row: r, column: c)?.content ?? ""
                    rowText += content
                }
                if c < maxCol { rowText += "\t" }
            }
            contentToCopy += rowText
            if r < maxRow { contentToCopy += "\n" }
        }
        
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(contentToCopy, forType: .string)
        #else
        UIPasteboard.general.string = contentToCopy
        #endif
    }
    
    private func pasteFromClipboard() {
        #if os(macOS)
        guard let content = NSPasteboard.general.string(forType: .string) else { return }
        #else
        guard let content = UIPasteboard.general.string else { return }
        #endif
        
        guard !content.isEmpty else { return }
        
        // Figure out start row/col
        let startRow: Int
        let startCol: Int
        
        if let firstSelected = selectedCells.first {
            startRow = firstSelected.row
            startCol = firstSelected.col
        } else if let firstRow = selectedRows.min() {
            startRow = firstRow
            startCol = 0
        } else if let firstCol = selectedColumns.min() {
            startRow = 0
            startCol = firstCol
        } else {
            // Default to 0,0 if nothing selected
            startRow = 0
            startCol = 0
        }
        
        let lines = content.components(separatedBy: .newlines)
        for (rOffset, line) in lines.enumerated() {
            let cells = line.components(separatedBy: "\t")
            for (cOffset, cellText) in cells.enumerated() {
                let r = startRow + rOffset
                let c = startCol + cOffset
                
                if r < table.rowCount && c < table.columnCount {
                    table.setCell(row: r, column: c, content: cellText)
                }
            }
        }
        try? context.save()
    }
    
    private func deleteSelectedColumns() {
        let sortedCols = selectedColumns.sorted(by: >)
        for col in sortedCols {
            table.removeColumn(at: col)
        }
        selectedColumns.removeAll()
        try? context.save()
    }
    
    private func deleteSelectedRows() {
        let sortedRows = selectedRows.sorted(by: >)
        for row in sortedRows {
            table.removeRow(at: row)
        }
        selectedRows.removeAll()
        try? context.save()
    }
    
    private func calculateTableWidth() -> CGFloat {
        var width: CGFloat = isEditing ? 36 : 0
        for col in 0..<table.columnCount {
            width += CGFloat(dragColumnWidths[col] ?? table.getColumnWidth(at: col))
        }
        return width
    }
    
    private func calculateTableHeightFromRows() -> CGFloat {
        var totalHeight: CGFloat = 0
        for row in 0..<table.rowCount {
            totalHeight += CGFloat(dragRowHeights[row] ?? table.getRowHeight(at: row))
        }
        return totalHeight
    }

    private func columnLabel(_ index: Int) -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        if index < 26 {
            return String(letters[letters.index(letters.startIndex, offsetBy: index)])
        } else {
            let first = index / 26 - 1
            let second = index % 26
            return String(letters[letters.index(letters.startIndex, offsetBy: first)]) +
                   String(letters[letters.index(letters.startIndex, offsetBy: second)])
        }
    }
}

// MARK: - Table Settings Popover

struct TableSettingsView: View {
    @Bindable var table: TableData
    var onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Table Settings")
                .font(.headline)
            
            Toggle("Header Row", isOn: $table.hasHeaderRow)
            Toggle("Header Column", isOn: $table.hasHeaderColumn)
            Toggle("Show Title", isOn: $table.showTitle)
            Toggle("Alternating Row Colors", isOn: $table.showAlternatingRowColors)
            Toggle("Show Borders", isOn: $table.showBorders)
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Table", systemImage: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(width: 220)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TableData.self, configurations: config)
    let table = TableData(rowCount: 4, columnCount: 3)
    container.mainContext.insert(table)
    
    return TableEditorView(table: table, onDelete: {})
        .modelContainer(container)
        .frame(width: 500, height: 400)
}
