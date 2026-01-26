//
//  URLValidator.swift
//  TextEditor
//
//  URL detection and validation helper.
//

import Foundation

struct URLValidator {

    /// Regular expression pattern for URL validation
    /// Matches common URL formats including http, https, and www prefixes
    private static let urlPattern = #"^(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$"#

    /// Checks if a string is a valid URL
    /// - Parameter string: The string to validate
    /// - Returns: True if the string is a valid URL
    static func isValidURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Quick check using URL initializer
        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            return true
        }

        // Try adding https:// prefix for URLs like "example.com"
        if let url = URL(string: "https://\(trimmed)"), url.host != nil {
            // Validate against regex pattern
            if let regex = try? NSRegularExpression(pattern: urlPattern, options: .caseInsensitive) {
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                return regex.firstMatch(in: trimmed, options: [], range: range) != nil
            }
        }

        return false
    }

    /// Extracts a valid URL from a string
    /// - Parameter string: The string to extract URL from
    /// - Returns: A URL if the string contains a valid URL, nil otherwise
    static func extractURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Try direct URL creation
        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            return url
        }

        // Try with https:// prefix
        if let url = URL(string: "https://\(trimmed)"), url.host != nil {
            // Validate it looks like a domain
            if isValidURL(trimmed) {
                return url
            }
        }

        return nil
    }

    /// Extracts the domain from a URL string
    /// - Parameter urlString: The URL string
    /// - Returns: The domain (e.g., "example.com")
    static func extractDomain(from urlString: String) -> String? {
        guard let url = extractURL(from: urlString) else { return nil }
        return url.host
    }

    /// Constructs a favicon URL for a given website URL
    /// - Parameter url: The website URL
    /// - Returns: A URL pointing to the site's favicon
    static func faviconURL(for url: URL) -> URL? {
        guard let host = url.host else { return nil }
        // Use Google's favicon service as a reliable fallback
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=32")
    }
}
