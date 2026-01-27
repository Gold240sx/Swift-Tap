//
//  BookmarkData.swift
//  TextEditor
//
//  Data model for bookmark blocks that display URL metadata.
//

import Foundation
import SwiftData

@Model
class BookmarkData {
    var id: UUID?
    var urlString: String?
    var title: String?
    var descriptionText: String?
    var faviconURLString: String?
    var ogImageURLString: String?
    var fetchedAt: Date?
    
    var noteBlock: NoteBlock?

    init(
        id: UUID = UUID(),
        urlString: String,
        title: String? = nil,
        descriptionText: String? = nil,
        faviconURLString: String? = nil,
        ogImageURLString: String? = nil,
        fetchedAt: Date? = nil
    ) {
        self.id = id
        self.urlString = urlString
        self.title = title
        self.descriptionText = descriptionText
        self.faviconURLString = faviconURLString
        self.ogImageURLString = ogImageURLString
        self.fetchedAt = fetchedAt
    }

    /// Computed property for the URL
    var url: URL? {
        guard let str = urlString else { return nil }
        return URL(string: str)
    }

    /// Computed property for the favicon URL
    var faviconURL: URL? {
        guard let str = faviconURLString else { return nil }
        return URL(string: str)
    }

    /// Computed property for the og:image URL
    var ogImageURL: URL? {
        guard let str = ogImageURLString else { return nil }
        return URL(string: str)
    }

    /// Display title - falls back to domain if no title
    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        if let url = url, let host = url.host {
            return host
        }
        return urlString ?? ""
    }

    /// Updates the bookmark with fetched metadata
    func update(from metadata: URLMetadata) {
        self.title = metadata.title
        self.descriptionText = metadata.description
        self.faviconURLString = metadata.faviconURL?.absoluteString
        self.ogImageURLString = metadata.ogImageURL?.absoluteString
        self.fetchedAt = Date()
    }
}
