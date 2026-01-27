//
//  FilePathData.swift
//  TextEditor
//
//  Data model for file path blocks that link to local files.
//

import Foundation
import SwiftData
import AppKit

@Model
class FilePathData {
    var id: UUID?
    var pathString: String?
    var displayName: String?
    var fileSize: Int64?
    var modificationDate: Date?
    var isDirectory: Bool?
    var fetchedAt: Date?
    
    var noteBlock: NoteBlock?

    init(
        id: UUID = UUID(),
        pathString: String,
        displayName: String? = nil,
        fileSize: Int64? = nil,
        modificationDate: Date? = nil,
        isDirectory: Bool = false,
        fetchedAt: Date? = nil
    ) {
        self.id = id
        self.pathString = pathString
        self.displayName = displayName
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.isDirectory = isDirectory
        self.fetchedAt = fetchedAt
    }

    /// Computed property for the file URL
    var fileURL: URL? {
        guard let pathString = pathString else { return nil }
        return URL(fileURLWithPath: pathString)
    }

    /// Display title - falls back to last path component if no display name
    var displayTitle: String {
        if let name = displayName, !name.isEmpty {
            return name
        }
        if let pathString = pathString {
            return (pathString as NSString).lastPathComponent
        }
        return "Unknown File"
    }

    /// Formatted file size string
    var formattedSize: String? {
        guard let size = fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// Formatted modification date string
    var formattedDate: String? {
        guard let date = modificationDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// File extension
    var fileExtension: String {
        guard let pathString = pathString else { return "" }
        return (pathString as NSString).pathExtension.lowercased()
    }

    /// Parent directory path
    var parentDirectory: String {
        guard let pathString = pathString else { return "" }
        return (pathString as NSString).deletingLastPathComponent
    }

    /// Check if file exists
    var fileExists: Bool {
        guard let pathString = pathString else { return false }
        return FileManager.default.fileExists(atPath: pathString)
    }

    /// Updates the file path data with current file system info
    func refreshMetadata() {
        let fileManager = FileManager.default
        guard let pathString = pathString, fileManager.fileExists(atPath: pathString) else { return }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: pathString)

            if let size = attributes[.size] as? Int64 {
                self.fileSize = size
            }

            if let modDate = attributes[.modificationDate] as? Date {
                self.modificationDate = modDate
            }

            if let fileType = attributes[.type] as? FileAttributeType {
                self.isDirectory = (fileType == .typeDirectory)
            }

            self.fetchedAt = Date()
        } catch {
            // Silently fail - metadata is optional
        }
    }

    /// Creates a FilePathData from a file URL with metadata
    static func create(from url: URL) -> FilePathData {
        let data = FilePathData(
            pathString: url.path,
            displayName: url.lastPathComponent
        )
        data.refreshMetadata()
        return data
    }

    /// Creates a FilePathData from a path string with metadata
    static func create(from path: String) -> FilePathData {
        let data = FilePathData(
            pathString: path,
            displayName: (path as NSString).lastPathComponent
        )
        data.refreshMetadata()
        return data
    }
}
