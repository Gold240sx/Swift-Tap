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
                for item in sourceList.items.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                    let newItem = ListItem(orderIndex: item.orderIndex, text: item.text, isChecked: item.isChecked)
                    newItem.parentList = newListData
                    newListData.items.append(newItem)
                }
                newBlock.listData = newListData
                context.insert(newListData)
            }

        case .table:
            if let sourceTable = source.table {
                let newTable = TableData(
                    title: sourceTable.title,
                    rowCount: sourceTable.rowCount,
                    columnCount: sourceTable.columnCount,
                    hasHeaderRow: sourceTable.hasHeaderRow,
                    hasHeaderColumn: sourceTable.hasHeaderColumn,
                    showAlternatingRowColors: sourceTable.showAlternatingRowColors,
                    showBorders: sourceTable.showBorders
                )
                newTable.columnWidths = sourceTable.columnWidths
                newTable.rowHeights = sourceTable.rowHeights
                newTable.showTitle = sourceTable.showTitle
                for cell in sourceTable.cells {
                    let newCell = TableCell(row: cell.row, column: cell.column, content: cell.content)
                    newCell.table = newTable
                    newTable.cells.append(newCell)
                }
                newBlock.table = newTable
                context.insert(newTable)
            }

        case .accordion:
            if let sourceAccordion = source.accordion {
                let newAccordion = AccordionData(heading: sourceAccordion.heading, level: sourceAccordion.level)
                newAccordion.isExpanded = sourceAccordion.isExpanded
                for nestedBlock in sourceAccordion.contentBlocks.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                    let copiedNested = createCopy(from: nestedBlock, context: context)
                    copiedNested.parentAccordion = newAccordion
                    newAccordion.contentBlocks.append(copiedNested)
                    context.insert(copiedNested)
                }
                newBlock.accordion = newAccordion
                context.insert(newAccordion)
            }

        case .code:
            if let sourceCode = source.codeBlock {
                let newCode = CodeBlockData(code: sourceCode.code, language: sourceCode.language, showLineNumbers: sourceCode.showLineNumbers)
                newBlock.codeBlock = newCode
                context.insert(newCode)
            }

        case .image:
            if let sourceImage = source.imageData {
                let newImage = ImageData(
                    urlString: sourceImage.urlString,
                    width: sourceImage.width,
                    height: sourceImage.height,
                    altText: sourceImage.altText,
                    isFullWidth: sourceImage.isFullWidth,
                    offsetX: sourceImage.offsetX,
                    offsetY: sourceImage.offsetY,
                    scale: sourceImage.scale
                )
                newBlock.imageData = newImage
                context.insert(newImage)
            }

        case .columns:
            if let sourceColumns = source.columnData {
                let newColumnData = ColumnData()
                for col in sourceColumns.columns.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                    let newCol = Column(orderIndex: col.orderIndex, widthRatio: col.widthRatio)
                    newCol.parentColumnData = newColumnData
                    for colBlock in col.blocks.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                        let copiedColBlock = createCopy(from: colBlock, context: context)
                        copiedColBlock.parentColumn = newCol
                        newCol.blocks.append(copiedColBlock)
                        context.insert(copiedColBlock)
                    }
                    newColumnData.columns.append(newCol)
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
                    urlString: sourceBookmark.urlString,
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
                    pathString: sourceFilePath.pathString,
                    displayName: sourceFilePath.displayName,
                    fileSize: sourceFilePath.fileSize,
                    modificationDate: sourceFilePath.modificationDate,
                    isDirectory: sourceFilePath.isDirectory,
                    fetchedAt: sourceFilePath.fetchedAt
                )
                newBlock.filePathData = newFilePath
                context.insert(newFilePath)
            }
        }

        return newBlock
    }
}
