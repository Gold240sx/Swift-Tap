//
//  ColumnData.swift
//  TextEditor
//
//  Created by Antigravity on 2026-01-21.
//

import Foundation
import SwiftData

@Model
class ColumnData {
    var id: UUID
    var columnCount: Int

    @Relationship(deleteRule: .cascade, inverse: \Column.parentColumnData)
    var columns: [Column]

    init(columnCount: Int = 2) {
        self.id = UUID()
        self.columnCount = columnCount
        self.columns = []
    }
}

@Model
class Column {
    var id: UUID
    var orderIndex: Int

    @Relationship(deleteRule: .cascade)
    var blocks: [NoteBlock]

    var parentColumnData: ColumnData?
    var widthRatio: Double

    init(orderIndex: Int, widthRatio: Double = 1.0) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.widthRatio = widthRatio
        self.blocks = []
    }
}
