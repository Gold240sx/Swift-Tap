//
//  TableData.swift
//  TextEditor
//
//  Numbers-style table data model for SwiftData persistence.
//

import Foundation
import SwiftData
import SwiftUI

@Model
class TableData {
    var id: UUID?
    var title: String?
    var rowCount: Int?
    var columnCount: Int?
    var hasHeaderRow: Bool?
    var hasHeaderColumn: Bool?
    var showAlternatingRowColors: Bool?
    var showBorders: Bool?
    var columnWidths: [Double]?
    var rowHeights: [Double]?
    var createdAt: Date?
    var updatedAt: Date?
    var showTitle: Bool?
    
    var noteBlock: NoteBlock?
    var note: RichTextNote?
    
    @Relationship(deleteRule: .cascade, inverse: \TableCell.table)
    var cells: [TableCell]?
    
    init(
        title: String = "Table",
        rowCount: Int = 3,
        columnCount: Int = 3,
        hasHeaderRow: Bool = true,
        hasHeaderColumn: Bool = true,
        showAlternatingRowColors: Bool = true,
        showBorders: Bool = true
    ) {
        self.id = UUID()
        self.title = title
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.hasHeaderRow = hasHeaderRow
        self.hasHeaderColumn = hasHeaderColumn
        self.showAlternatingRowColors = showAlternatingRowColors
        self.showBorders = showBorders
        self.showTitle = true
        self.createdAt = Date.now
        self.updatedAt = Date.now
        self.cells = []
        self.columnWidths = Array(repeating: 150.0, count: columnCount)
        self.rowHeights = Array(repeating: 36.0, count: rowCount)
    }
    
    // MARK: - Column width management
    
    func getColumnWidth(at index: Int) -> Double {
        let widths = columnWidths ?? []
        if index < widths.count {
            return widths[index]
        }
        return 150.0
    }
    
    func setColumnWidth(at index: Int, width: Double) {
        let minWidth = 40.0
        var widths = columnWidths ?? []
        
        // Ensure array is large enough (handles cases after migration or unexpected counts)
        if index >= widths.count {
            let needed = index - widths.count + 1
            widths.append(contentsOf: Array(repeating: 150.0, count: needed))
        }
        
        widths[index] = max(minWidth, width)
        columnWidths = widths
        updatedAt = Date.now
    }
    
    // MARK: - Row height management
    
    func getRowHeight(at index: Int) -> Double {
        let heights = rowHeights ?? []
        if index < heights.count {
            return heights[index]
        }
        return 36.0
    }
    
    func setRowHeight(at index: Int, height: Double) {
        let minHeight = 20.0
        var heights = rowHeights ?? []
        
        if index >= heights.count {
            let needed = index - heights.count + 1
            heights.append(contentsOf: Array(repeating: 36.0, count: needed))
        }
        
        heights[index] = max(minHeight, height)
        rowHeights = heights
        updatedAt = Date.now
    }
    
    // MARK: - Cell Management
    
    func getCell(row: Int, column: Int) -> TableCell? {
        return (cells ?? []).first { $0.row == row && $0.column == column }
    }
    
    func setCell(row: Int, column: Int, content: String) {
        if let existingCell = getCell(row: row, column: column) {
            existingCell.content = content
        } else {
            let newCell = TableCell(row: row, column: column, content: content)
            newCell.table = self
            if cells == nil { cells = [] }
            cells?.append(newCell)
        }
        updatedAt = Date.now
    }
    
    func addRow() {
        insertRow(at: rowCount ?? 0)
    }
    
    func addColumn() {
        insertColumn(at: columnCount ?? 0)
    }
    
    func insertRow(at index: Int) {
        // Shift existing cells down
        for cell in (cells ?? []) where (cell.row ?? 0) >= index {
            cell.row = (cell.row ?? 0) + 1
        }
        
        var heights = rowHeights ?? []
        // Insert new height
        if index <= heights.count {
            heights.insert(36.0, at: index)
        } else {
            heights.append(36.0)
        }
        rowHeights = heights
        
        rowCount = (rowCount ?? 0) + 1
        updatedAt = Date.now
    }
    
    func insertColumn(at index: Int) {
        // Shift existing cells right
        for cell in (cells ?? []) where (cell.column ?? 0) >= index {
            cell.column = (cell.column ?? 0) + 1
        }
        
        var widths = columnWidths ?? []
        // Insert new width
        if index <= widths.count {
            widths.insert(150.0, at: index)
        } else {
            widths.append(150.0)
        }
        columnWidths = widths
        
        columnCount = (columnCount ?? 0) + 1
        updatedAt = Date.now
    }
    
    func removeRow(at index: Int? = nil) {
        let currentRows = rowCount ?? 0
        guard currentRows > 1 else { return }
        let targetIndex = index ?? (currentRows - 1)
        
        // Remove cells in the target row
        if var currentCells = cells {
            currentCells.removeAll { $0.row == targetIndex }
            
            // Shift up remaining cells
            for cell in currentCells where (cell.row ?? 0) > targetIndex {
                cell.row = (cell.row ?? 0) - 1
            }
            cells = currentCells
        }
        
        // Remove height entry
        var heights = rowHeights ?? []
        if targetIndex < heights.count {
            heights.remove(at: targetIndex)
        }
        rowHeights = heights
        
        rowCount = currentRows - 1
        updatedAt = Date.now
    }
    
    func removeColumn(at index: Int? = nil) {
        let currentCols = columnCount ?? 0
        guard currentCols > 1 else { return }
        let targetIndex = index ?? (currentCols - 1)
        
        // Remove cells in the target column
        if var currentCells = cells {
            currentCells.removeAll { $0.column == targetIndex }
            
            // Shift left remaining cells
            for cell in currentCells where (cell.column ?? 0) > targetIndex {
                cell.column = (cell.column ?? 0) - 1
            }
            cells = currentCells
        }
        
        // Remove width entry
        var widths = columnWidths ?? []
        if targetIndex < widths.count {
            widths.remove(at: targetIndex)
        }
        columnWidths = widths
        
        columnCount = currentCols - 1
        updatedAt = Date.now
    }
    
    // MARK: - Styling Helpers
    
    func isHeaderCell(row: Int, column: Int) -> Bool {
        return ((hasHeaderRow ?? false) && row == 0) || ((hasHeaderColumn ?? false) && column == 0)
    }
    
    func rowBackgroundColor(row: Int) -> Color {
        if (hasHeaderRow ?? false) && row == 0 {
            return Color.gray.opacity(0.3)
        }
        if (showAlternatingRowColors ?? false) {
            return row % 2 == 0 ? Color.gray.opacity(0.1) : Color.clear
        }
        return Color.clear
    }
    
    func columnBackgroundColor(column: Int) -> Color {
        if (hasHeaderColumn ?? false) && column == 0 {
            return Color.gray.opacity(0.2)
        }
        return Color.clear
    }
}

@Model
class TableCell {
    var id: UUID?
    var row: Int?
    var column: Int?
    var content: String?
    var table: TableData?
    
    init(row: Int, column: Int, content: String = "") {
        self.id = UUID()
        self.row = row
        self.column = column
        self.content = content
    }
}
