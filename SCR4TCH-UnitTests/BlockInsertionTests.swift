//
//  BlockInsertionTests.swift
//  TextEditor-UnitTests
//
//  Tests for block insertion and replacement logic.
//

import Testing
import Foundation
import SwiftData
@testable import TextEditor

// MARK: - isTextBlockEmpty Tests

@Suite("Text Block Empty Detection")
struct TextBlockEmptyTests {

    /// Helper function that mirrors the one in NotesEditorView
    private func isTextBlockEmpty(_ block: NoteBlock) -> Bool {
        guard block.type == .text else { return false }
        guard let text = block.text else { return true }
        let plainText = String(text.characters)
        return plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @Test("Empty string text block is empty")
    func emptyTextBlockIsEmpty() {
        let block = NoteBlock(orderIndex: 0, text: "", type: .text)
        #expect(isTextBlockEmpty(block) == true)
    }

    @Test("Text block with only newline is empty")
    func textBlockWithOnlyNewlineIsEmpty() {
        let block = NoteBlock(orderIndex: 0, text: AttributedString("\n"), type: .text)
        #expect(isTextBlockEmpty(block) == true)
    }

    @Test("Text block with multiple newlines is empty")
    func textBlockWithMultipleNewlinesIsEmpty() {
        let block = NoteBlock(orderIndex: 0, text: AttributedString("\n\n\n"), type: .text)
        #expect(isTextBlockEmpty(block) == true)
    }

    @Test("Text block with whitespace is empty")
    func textBlockWithWhitespaceIsEmpty() {
        let block = NoteBlock(orderIndex: 0, text: AttributedString("   "), type: .text)
        #expect(isTextBlockEmpty(block) == true)
    }

    @Test("Text block with mixed whitespace is empty")
    func textBlockWithMixedWhitespaceIsEmpty() {
        let block = NoteBlock(orderIndex: 0, text: AttributedString("  \n\t  \n  "), type: .text)
        #expect(isTextBlockEmpty(block) == true)
    }

    @Test("Text block with content is not empty")
    func textBlockWithContentIsNotEmpty() {
        let block = NoteBlock(orderIndex: 0, text: AttributedString("Hello"), type: .text)
        #expect(isTextBlockEmpty(block) == false)
    }

    @Test("Text block with content and newlines is not empty")
    func textBlockWithContentAndNewlinesIsNotEmpty() {
        let block = NoteBlock(orderIndex: 0, text: AttributedString("Hello\n\nWorld"), type: .text)
        #expect(isTextBlockEmpty(block) == false)
    }

    @Test("Nil text is empty")
    func nilTextIsEmpty() {
        let block = NoteBlock(orderIndex: 0, text: nil, type: .text)
        #expect(isTextBlockEmpty(block) == true)
    }

    @Test("Non-text block is not considered empty")
    func nonTextBlockIsNotEmpty() {
        let block = NoteBlock(orderIndex: 0, type: .quote)
        #expect(isTextBlockEmpty(block) == false)
    }
}

// MARK: - FilePathData Tests

@Suite("FilePathData Model")
struct FilePathDataTests {

    @Test("FilePathData creation with all properties")
    func filePathDataCreation() {
        let data = FilePathData(
            pathString: "/Users/test/Documents/file.pdf",
            displayName: "file.pdf",
            fileSize: 1024,
            modificationDate: Date(),
            isDirectory: false
        )

        #expect(data.pathString == "/Users/test/Documents/file.pdf")
        #expect(data.displayName == "file.pdf")
        #expect(data.fileSize == 1024)
        #expect(data.isDirectory == false)
    }

    @Test("Display title uses displayName when available")
    func displayTitleWithName() {
        let data = FilePathData(
            pathString: "/Users/test/file.pdf",
            displayName: "Custom Name"
        )
        #expect(data.displayTitle == "Custom Name")
    }

    @Test("Display title falls back to filename")
    func displayTitleFallback() {
        let data = FilePathData(pathString: "/Users/test/file.pdf")
        #expect(data.displayTitle == "file.pdf")
    }

    @Test("File extension extraction")
    func fileExtension() {
        let pdfData = FilePathData(pathString: "/Users/test/file.pdf")
        #expect(pdfData.fileExtension == "pdf")

        let noExtData = FilePathData(pathString: "/Users/test/file")
        #expect(noExtData.fileExtension == "")
    }

    @Test("Parent directory extraction")
    func parentDirectory() {
        let data = FilePathData(pathString: "/Users/test/Documents/file.pdf")
        #expect(data.parentDirectory == "/Users/test/Documents")
    }

    @Test("Formatted size for 1MB file")
    func formattedSize() {
        let data = FilePathData(pathString: "/test", fileSize: 1024 * 1024)
        #expect(data.formattedSize != nil)
    }

    @Test("File URL computed property")
    func fileURL() {
        let data = FilePathData(pathString: "/Users/test/file.pdf")
        #expect(data.fileURL != nil)
        #expect(data.fileURL?.path == "/Users/test/file.pdf")
    }
}

// MARK: - NoteBlock Type Tests

@Suite("NoteBlock with FilePathData")
struct NoteBlockFilePathTests {

    @Test("NoteBlock with filePath type")
    func noteBlockWithFilePath() {
        let filePathData = FilePathData(pathString: "/test/file.txt")
        let block = NoteBlock(orderIndex: 0, filePathData: filePathData, type: .filePath)

        #expect(block.type == .filePath)
        #expect(block.filePathData != nil)
        #expect(block.filePathData?.pathString == "/test/file.txt")
    }

    @Test("NoteBlock displayName for file link")
    func noteBlockDisplayName() {
        let filePathData = FilePathData(pathString: "/test")
        let fileBlock = NoteBlock(orderIndex: 0, filePathData: filePathData, type: .filePath)
        #expect(fileBlock.displayName == "File Link")
    }

    @Test("NoteBlock displayName for text block")
    func textBlockDisplayName() {
        let textBlock = NoteBlock(orderIndex: 0, text: "", type: .text)
        #expect(textBlock.displayName == "Text Block")
    }
}
