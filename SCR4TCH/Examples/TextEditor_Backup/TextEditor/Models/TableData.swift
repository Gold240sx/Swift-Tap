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
    var id: UUID
    var title: String
    var rowCount: Int
    var columnCount: Int
    var hasHeaderRow: Bool
    var hasHeaderColumn: Bool
    var showAlternatingRowColors: Bool
    var showBorders: Bool
    var columnWidths: [Double]
    var rowHeights: [Double]
    var createdAt: Date
    var updatedAt: Date
    var showTitle: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \TableCell.table)
    var cells: [TableCell]
    
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
        if index < columnWidths.count {
            return columnWidths[index]
        }
        return 150.0
    }
    
    func setColumnWidth(at index: Int, width: Double) {
        let minWidth = 40.0
        
        // Ensure array is large enough (handles cases after migration or unexpected counts)
        if index >= columnWidths.count {
            let needed = index - columnWidths.count + 1
            columnWidths.append(contentsOf: Array(repeating: 150.0, count: needed))
        }
        
        columnWidths[index] = max(minWidth, width)
        updatedAt = Date.now
    }
    
    // MARK: - Row height management
    
    func getRowHeight(at index: Int) -> Double {
        if index < rowHeights.count {
            return rowHeights[index]
        }
        return 36.0
    }
    
    func setRowHeight(at index: Int, height: Double) {
        let minHeight = 20.0
        
        if index >= rowHeights.count {
            let needed = index - rowHeights.count + 1
            rowHeights.append(contentsOf: Array(repeating: 36.0, count: needed))
        }
        
        rowHeights[index] = max(minHeight, height)
        updatedAt = Date.now
    }
    
    // MARK: - Cell Management
    
    func getCell(row: Int, column: Int) -> TableCell? {
        return cells.first { $0.row == row && $0.column == column }
    }
    
    func setCell(row: Int, column: Int, content: String) {
        if let existingCell = getCell(row: row, column: column) {
            existingCell.content = content
        } else {
            let newCell = TableCell(row: row, column: column, content: content)
            newCell.table = self
            cells.append(newCell)
        }
        updatedAt = Date.now
    }
    
    func addRow() {
        insertRow(at: rowCount)
    }
    
    func addColumn() {
        insertColumn(at: columnCount)
    }
    
    func insertRow(at index: Int) {
        // Shift existing cells down
        for cell in cells where cell.row >= index {
            cell.row += 1
        }
        
        // Insert new height
        if index <= rowHeights.count {
            rowHeights.insert(36.0, at: index)
        } else {
            rowHeights.append(36.0)
        }
        
        rowCount += 1
        updatedAt = Date.now
    }
    
    func insertColumn(at index: Int) {
        // Shift existing cells right
        for cell in cells where cell.column >= index {
            cell.column += 1
        }
        
        // Insert new width
        if index <= columnWidths.count {
            columnWidths.insert(150.0, at: index)
        } else {
            columnWidths.append(150.0)
        }
        
        columnCount += 1
        updatedAt = Date.now
    }
    
    func removeRow(at index: Int? = nil) {
        guard rowCount > 1 else { return }
        let targetIndex = index ?? (rowCount - 1)
        
        // Remove cells in the target row
        cells.removeAll { $0.row == targetIndex }
        
        // Shift up remaining cells
        for cell in cells where cell.row > targetIndex {
            cell.row -= 1
        }
        
        // Remove height entry
        if targetIndex < rowHeights.count {
            rowHeights.remove(at: targetIndex)
        }
        
        rowCount -= 1
        updatedAt = Date.now
    }
    
    func removeColumn(at index: Int? = nil) {
        guard columnCount > 1 else { return }
        let targetIndex = index ?? (columnCount - 1)
        
        // Remove cells in the target column
        cells.removeAll { $0.column == targetIndex }
        
        // Shift left remaining cells
        for cell in cells where cell.column > targetIndex {
            cell.column -= 1
        }
        
        // Remove width entry
        if targetIndex < columnWidths.count {
            columnWidths.remove(at: targetIndex)
        }
        
        columnCount -= 1
        updatedAt = Date.now
    }
    
    // MARK: - Styling Helpers
    
    func isHeaderCell(row: Int, column: Int) -> Bool {
        return (hasHeaderRow && row == 0) || (hasHeaderColumn && column == 0)
    }
    
    func rowBackgroundColor(row: Int) -> Color {
        if hasHeaderRow && row == 0 {
            return Color.gray.opacity(0.3)
        }
        if showAlternatingRowColors {
            return row % 2 == 0 ? Color.gray.opacity(0.1) : Color.clear
        }
        return Color.clear
    }
    
    func columnBackgroundColor(column: Int) -> Color {
        if hasHeaderColumn && column == 0 {
            return Color.gray.opacity(0.2)
        }
        return Color.clear
    }
}

@Model
class TableCell {
    var id: UUID
    var row: Int
    var column: Int
    var content: String
    var table: TableData?
    
    init(row: Int, column: Int, content: String = "") {
        self.id = UUID()
        self.row = row
        self.column = column
        self.content = content
    }
}
