//
//  URLMetadataFetcher.swift
//  TextEditor
//
//  Async fetcher for page metadata (title, description, favicon, og:image).
//

import Foundation

/// Represents metadata fetched from a URL
struct URLMetadata: Sendable {
    var url: URL
    var title: String?
    var description: String?
    var faviconURL: URL?
    var ogImageURL: URL?
}

/// Actor that fetches and caches URL metadata
actor URLMetadataFetcher {
    static let shared = URLMetadataFetcher()

    private var cache: [URL: URLMetadata] = [:]
    private var inFlightTasks: [URL: Task<URLMetadata, Error>] = [:]

    private init() {}

    /// Fetches metadata for a given URL
    /// - Parameter url: The URL to fetch metadata from
    /// - Returns: URLMetadata containing title, description, favicon, and og:image
    func fetch(url: URL) async throws -> URLMetadata {
        // Check cache first
        if let cached = cache[url] {
            return cached
        }

        // Check if there's already a request in flight
        if let existingTask = inFlightTasks[url] {
            return try await existingTask.value
        }

        // Create new fetch task
        let task = Task<URLMetadata, Error> {
            let metadata = try await performFetch(url: url)
            return metadata
        }

        inFlightTasks[url] = task

        do {
            let metadata = try await task.value
            cache[url] = metadata
            inFlightTasks[url] = nil
            return metadata
        } catch {
            inFlightTasks[url] = nil
            throw error
        }
    }

    /// Clear the cache
    func clearCache() {
        cache.removeAll()
    }

    /// Performs the actual fetch operation
    private func performFetch(url: URL) async throws -> URLMetadata {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLMetadataError.invalidResponse
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw URLMetadataError.invalidData
        }

        return parseHTML(html, baseURL: url)
    }

    /// Parses HTML to extract metadata
    private func parseHTML(_ html: String, baseURL: URL) -> URLMetadata {
        var metadata = URLMetadata(url: baseURL)

        // Extract <title>
        if let titleMatch = html.range(of: "<title[^>]*>(.*?)</title>", options: .regularExpression, range: nil, locale: nil) {
            let titleContent = String(html[titleMatch])
            if let start = titleContent.range(of: ">"),
               let end = titleContent.range(of: "</title>") {
                let title = String(titleContent[start.upperBound..<end.lowerBound])
                metadata.title = decodeHTMLEntities(title).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Extract og:title if no title found
        if metadata.title == nil {
            metadata.title = extractMetaContent(from: html, property: "og:title")
        }

        // Extract description
        metadata.description = extractMetaContent(from: html, name: "description")
            ?? extractMetaContent(from: html, property: "og:description")

        // Extract og:image
        if let ogImage = extractMetaContent(from: html, property: "og:image") {
            metadata.ogImageURL = resolveURL(ogImage, baseURL: baseURL)
        }

        // Extract favicon
        metadata.faviconURL = extractFaviconURL(from: html, baseURL: baseURL)
            ?? URLValidator.faviconURL(for: baseURL)

        return metadata
    }

    /// Extracts meta content by name attribute
    private func extractMetaContent(from html: String, name: String) -> String? {
        let pattern = "<meta[^>]+name=[\"']\(name)[\"'][^>]+content=[\"']([^\"']+)[\"']"
        let altPattern = "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+name=[\"']\(name)[\"']"

        if let match = extractFirstGroup(from: html, pattern: pattern) {
            return decodeHTMLEntities(match)
        }
        if let match = extractFirstGroup(from: html, pattern: altPattern) {
            return decodeHTMLEntities(match)
        }
        return nil
    }

    /// Extracts meta content by property attribute (for Open Graph tags)
    private func extractMetaContent(from html: String, property: String) -> String? {
        let pattern = "<meta[^>]+property=[\"']\(property)[\"'][^>]+content=[\"']([^\"']+)[\"']"
        let altPattern = "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+property=[\"']\(property)[\"']"

        if let match = extractFirstGroup(from: html, pattern: pattern) {
            return decodeHTMLEntities(match)
        }
        if let match = extractFirstGroup(from: html, pattern: altPattern) {
            return decodeHTMLEntities(match)
        }
        return nil
    }

    /// Extracts favicon URL from HTML
    private func extractFaviconURL(from html: String, baseURL: URL) -> URL? {
        // Look for <link rel="icon"> or <link rel="shortcut icon">
        let patterns = [
            "<link[^>]+rel=[\"'](?:shortcut )?icon[\"'][^>]+href=[\"']([^\"']+)[\"']",
            "<link[^>]+href=[\"']([^\"']+)[\"'][^>]+rel=[\"'](?:shortcut )?icon[\"']"
        ]

        for pattern in patterns {
            if let href = extractFirstGroup(from: html, pattern: pattern) {
                return resolveURL(href, baseURL: baseURL)
            }
        }

        return nil
    }

    /// Extracts the first capture group from a regex match
    private func extractFirstGroup(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let groupRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[groupRange])
    }

    /// Resolves a potentially relative URL against a base URL
    private func resolveURL(_ urlString: String, baseURL: URL) -> URL? {
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return URL(string: urlString)
        } else if urlString.hasPrefix("//") {
            return URL(string: "https:\(urlString)")
        } else if urlString.hasPrefix("/") {
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.path = urlString
            components?.query = nil
            return components?.url
        } else {
            return URL(string: urlString, relativeTo: baseURL)?.absoluteURL
        }
    }

    /// Decodes common HTML entities
    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&nbsp;": " "
        ]

        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        // Handle numeric entities
        let numericPattern = "&#([0-9]+);"
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: range)

            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: result),
                   let numRange = Range(match.range(at: 1), in: result),
                   let codePoint = UInt32(result[numRange]),
                   let scalar = Unicode.Scalar(codePoint) {
                    result.replaceSubrange(fullRange, with: String(Character(scalar)))
                }
            }
        }

        return result
    }
}

/// Errors that can occur during metadata fetching
enum URLMetadataError: Error {
    case invalidResponse
    case invalidData
    case networkError
}
