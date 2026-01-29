//
//  BlockCopyHelper.swift
//  TextEditor
//
//  Helper for duplicating and copying blocks.
//

import Foundation
import SwiftData

struct BlockCopyHelper {

    /// Creates a deep copy of a NoteBlock and all its nested content
    static func createCopy(from source: NoteBlock, context: ModelContext) -> NoteBlock {
        let newBlock = NoteBlock(orderIndex: 0, type: source.type)

        switch source.type {
        case .text:
            newBlock.text = source.text

        case .list:
            if let sourceList = source.listData {
                let newListData = ListData(title: sourceList.title, listType: sourceList.listType)
                if newListData.items == nil { newListData.items = [] }
                for item in (sourceList.items ?? []).sorted(by: { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) }) {
                    let newItem = ListItem(orderIndex: item.orderIndex ?? 0, text: item.text, isChecked: item.isChecked ?? false)
                    newItem.parentList = newListData
                    newListData.items?.append(newItem)
                }
                newBlock.listData = newListData
                context.insert(newListData)
            }

        case .table:
            if let sourceTable = source.table {
                let newTable = TableData(
                    title: sourceTable.title ?? "",
                    rowCount: sourceTable.rowCount ?? 0,
                    columnCount: sourceTable.columnCount ?? 0,
                    hasHeaderRow: sourceTable.hasHeaderRow ?? false,
                    hasHeaderColumn: sourceTable.hasHeaderColumn ?? false,
                    showAlternatingRowColors: sourceTable.showAlternatingRowColors ?? false,
                    showBorders: sourceTable.showBorders ?? true
                )
                newTable.columnWidths = sourceTable.columnWidths
                newTable.rowHeights = sourceTable.rowHeights
                newTable.showTitle = sourceTable.showTitle
                if newTable.cells == nil { newTable.cells = [] }
                for cell in (sourceTable.cells ?? []) {
                    let newCell = TableCell(row: cell.row ?? 0, column: cell.column ?? 0, content: cell.content ?? "")
                    newCell.table = newTable
                    newTable.cells?.append(newCell)
                }
                newBlock.table = newTable
                context.insert(newTable)
            }

        case .accordion:
            if let sourceAccordion = source.accordion {
                let newAccordion = AccordionData(heading: sourceAccordion.heading, level: sourceAccordion.level)
                newAccordion.isExpanded = sourceAccordion.isExpanded ?? true
                if newAccordion.contentBlocks == nil { newAccordion.contentBlocks = [] }
                for nestedBlock in (sourceAccordion.contentBlocks ?? []).sorted(by: { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) }) {
                    let copiedNested = createCopy(from: nestedBlock, context: context)
                    copiedNested.parentAccordion = newAccordion
                    newAccordion.contentBlocks?.append(copiedNested)
                    context.insert(copiedNested)
                }
                newBlock.accordion = newAccordion
                context.insert(newAccordion)
            }

        case .code:
            if let sourceCode = source.codeBlock {
                let newCode = CodeBlockData(code: sourceCode.code ?? "", language: sourceCode.language, showLineNumbers: sourceCode.showLineNumbers ?? true)
                newBlock.codeBlock = newCode
                context.insert(newCode)
            }

        case .image:
            if let sourceImage = source.imageData {
                let newImage = ImageData(
                    urlString: sourceImage.urlString ?? "",
                    width: sourceImage.width,
                    height: sourceImage.height,
                    altText: sourceImage.altText,
                    isFullWidth: sourceImage.isFullWidth ?? false,
                    offsetX: sourceImage.offsetX ?? 0,
                    offsetY: sourceImage.offsetY ?? 0,
                    scale: sourceImage.scale ?? 1.0
                )
                newBlock.imageData = newImage
                context.insert(newImage)
            }

        case .columns:
            if let sourceColumns = source.columnData {
                let newColumnData = ColumnData()
                if newColumnData.columns == nil { newColumnData.columns = [] }
                for col in (sourceColumns.columns ?? []).sorted(by: { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) }) {
                    let newCol = Column(orderIndex: col.orderIndex ?? 0, widthRatio: col.widthRatio ?? 1.0)
                    newCol.parentColumnData = newColumnData
                    if newCol.blocks == nil { newCol.blocks = [] }
                    for colBlock in (col.blocks ?? []).sorted(by: { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) }) {
                        let copiedColBlock = createCopy(from: colBlock, context: context)
                        copiedColBlock.parentColumn = newCol
                        newCol.blocks?.append(copiedColBlock)
                        context.insert(copiedColBlock)
                    }
                    newColumnData.columns?.append(newCol)
                    context.insert(newCol)
                }
                newBlock.columnData = newColumnData
                context.insert(newColumnData)
            }

        case .quote:
            newBlock.text = source.text

        case .bookmark:
            if let sourceBookmark = source.bookmarkData {
                let newBookmark = BookmarkData(
                    urlString: sourceBookmark.urlString ?? "",
                    title: sourceBookmark.title,
                    descriptionText: sourceBookmark.descriptionText,
                    faviconURLString: sourceBookmark.faviconURLString,
                    ogImageURLString: sourceBookmark.ogImageURLString,
                    fetchedAt: sourceBookmark.fetchedAt
                )
                newBlock.bookmarkData = newBookmark
                context.insert(newBookmark)
            }

        case .filePath:
            if let sourceFilePath = source.filePathData {
                let newFilePath = FilePathData(
                    pathString: sourceFilePath.pathString ?? "",
                    displayName: sourceFilePath.displayName,
                    fileSize: sourceFilePath.fileSize,
                    modificationDate: sourceFilePath.modificationDate,
                    isDirectory: sourceFilePath.isDirectory ?? false,
                    fetchedAt: sourceFilePath.fetchedAt
                )
                newBlock.filePathData = newFilePath
                context.insert(newFilePath)
            }

        case .reminder:
            if let sourceReminder = source.reminderData {
                if let dueDate = sourceReminder.dueDate {
                    let newReminder = ReminderData(
                        title: sourceReminder.title ?? "Reminder",
                        dueDate: dueDate,
                        isCompleted: sourceReminder.isCompleted ?? false
                    )
                    newBlock.reminderData = newReminder
                    context.insert(newReminder)
                }
            }
        }

        return newBlock
    }
}
