//
//  TableCellView.swift
//  TextEditor
//
//  Individual cell component with inline editing support.
//

import SwiftUI
import SwiftData

struct TableCellView: View {
    let table: TableData
    let row: Int
    let column: Int
    var isRowSelected: Bool = false
    var isColumnSelected: Bool = false
    var isSelected: Bool = false
    var selectedEdges: Edge.Set = []
    var onCopy: () -> Void = {}
    var onPaste: () -> Void = {}
    var isEditingFromParent: Bool = false
    @State private var editText: String = ""
    @FocusState private var isFocused: Bool
    
    var cellContent: String {
        table.getCell(row: row, column: column)?.content ?? ""
    }
    
    var isHeader: Bool {
        table.isHeaderCell(row: row, column: column)
    }
    
    var backgroundColor: Color {
        if isSelected || isRowSelected || isColumnSelected {
            return Color.accentColor.opacity(isEditingFromParent ? 0.05 : 0.15)
        }
        if table.hasHeaderRow && row == 0 {
            return Color.gray.opacity(0.35)
        }
        if table.hasHeaderColumn && column == 0 {
            return Color.gray.opacity(0.2)
        }
        if table.showAlternatingRowColors && row % 2 == 1 {
            return Color.gray.opacity(0.08)
        }
        return Color.clear
    }
    
    var body: some View {
        ZStack {
            backgroundColor
            
            if isEditingFromParent {
                TextField("", text: $editText)
                    .textFieldStyle(.plain)
                    .font(isHeader ? .headline : .body)
                    .multilineTextAlignment(.leading)
                    .focused($isFocused)
                    .onSubmit {
                        commitEdit()
                    }
                    .onChange(of: isFocused) { _, newValue in
                        if !newValue {
                            commitEdit()
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity)
            } else {
                Text(cellContent.isEmpty ? " " : cellContent)
                    .font(isHeader ? .headline : .body)
                    .fontWeight(isHeader ? .semibold : .regular)
                    .foregroundColor(isHeader ? .primary : .secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .padding(.horizontal, 6)
                    .contextMenu {
                        Button {
                            table.insertRow(at: row)
                        } label: {
                            Label("Insert Row Above", systemImage: "arrow.up")
                        }
                        
                        Button {
                            table.insertRow(at: row + 1)
                        } label: {
                            Label("Insert Row Below", systemImage: "arrow.down")
                        }
                        
                        Divider()
                        
                        Button {
                            table.insertColumn(at: column)
                        } label: {
                            Label("Insert Column Left", systemImage: "arrow.left")
                        }
                        
                        Button {
                            table.insertColumn(at: column + 1)
                        } label: {
                            Label("Insert Column Right", systemImage: "arrow.right")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            table.removeRow(at: row)
                        } label: {
                            Label("Delete Row", systemImage: "trash")
                        }
                        
                        Button(role: .destructive) {
                            table.removeColumn(at: column)
                        } label: {
                            Label("Delete Column", systemImage: "trash")
                        }
                        
                        Divider()
                        
                        Button {
                            onCopy()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            onPaste()
                        } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                        }
                    }
            }
        }
        .frame(minHeight: 0) // allow dynamic height based on content
        .overlay(
            Rectangle()
                .stroke(table.showBorders ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 0.5)
        )
        .overlay(
            CellSelectionBorder(edges: selectedEdges, color: .accentColor, width: 2)
                .padding(-1) // Overlap slightly to ensure continuous look
        )
        .onChange(of: isEditingFromParent) {
            if isEditingFromParent {
                startEditing()
            } else {
                commitEdit()
            }
        }
        .onAppear {
            if isEditingFromParent {
                startEditing()
            }
        }
    }
    
    // MARK: - Internal Views
    
    struct CellSelectionBorder: View {
        var edges: Edge.Set
        var color: Color
        var width: CGFloat
        
        var body: some View {
            GeometryReader { geo in
                Path { path in
                    let rect = geo.frame(in: .local)
                    // Inset half width to keep stroke centered on edge? 
                    // Or just draw on bounds. Since we overlay with padding -1, pure bounds is fine.
                    
                    if edges.contains(.top) {
                        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                    }
                    if edges.contains(.bottom) {
                        // Fix for bottom edge line width visual
                        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    }
                    if edges.contains(.leading) {
                        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                    }
                    if edges.contains(.trailing) {
                        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    }
                }
                .stroke(color, lineWidth: width)
            }
            .allowsHitTesting(false)
        }
    }
    
    private func startEditing() {
        editText = cellContent
        isFocused = true
    }
    
    private func commitEdit() {
        table.setCell(row: row, column: column, content: editText)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TableData.self, configurations: config)
    let table = TableData(rowCount: 3, columnCount: 3)
    container.mainContext.insert(table)
    
    return TableCellView(table: table, row: 0, column: 0)
        .modelContainer(container)
}
