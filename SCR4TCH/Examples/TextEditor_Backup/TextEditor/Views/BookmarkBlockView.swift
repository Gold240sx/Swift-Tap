//
//  BookmarkBlockView.swift
//  TextEditor
//
//  View for displaying bookmark blocks with title, description, favicon, and og:image.
//

import SwiftUI
import AppKit

struct BookmarkBlockView: View {
    @Bindable var bookmarkData: BookmarkData
    var onDelete: () -> Void

    @State private var isHovered = false
    @State private var isLoading = false

    var body: some View {
        HStack(spacing: 0) {
            // Left column: Title, description, favicon + URL
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(bookmarkData.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                // Description
                if let description = bookmarkData.descriptionText, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Favicon + URL
                HStack(spacing: 6) {
                    // Favicon
                    if let faviconURL = bookmarkData.faviconURL {
                        AsyncImage(url: faviconURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                            case .failure(_):
                                Image(systemName: "globe")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            case .empty:
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 16, height: 16)
                            @unknown default:
                                Image(systemName: "globe")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    // URL display
                    Text(displayURL)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.leading, 12)
            .padding(.trailing, bookmarkData.ogImageURL != nil ? 8 : 12)

            // Right column: OG Image
            if let ogImageURL = bookmarkData.ogImageURL {
                AsyncImage(url: ogImageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 80)
                            .clipped()
                    case .failure(_):
                        Color.gray.opacity(0.2)
                            .frame(width: 120, height: 80)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.tertiary)
                            }
                    case .empty:
                        Color.gray.opacity(0.1)
                            .frame(width: 120, height: 80)
                            .overlay {
                                ProgressView()
                                    .scaleEffect(0.6)
                            }
                    @unknown default:
                        Color.gray.opacity(0.2)
                            .frame(width: 120, height: 80)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.trailing, 12)
                .padding(.vertical, 12)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }
        }
        .overlay(alignment: .topTrailing) {
            if isHovered {
                HStack(spacing: 4) {
                    // Refresh button
                    Button {
                        refreshMetadata()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .padding(4)
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh metadata")

                    // Delete button
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .padding(4)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete bookmark")
                }
                .background {
                    Capsule()
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(radius: 2)
                }
                .padding(6)
            }
        }
        .overlay {
            if isLoading {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            openURL()
        }
        .contextMenu {
            Button("Open in Browser") {
                openURL()
            }

            Button("Copy URL") {
                copyURL()
            }

            Divider()

            Button("Refresh Metadata") {
                refreshMetadata()
            }

            Divider()

            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }

    /// Display URL - shows just the domain
    private var displayURL: String {
        if let url = bookmarkData.url, let host = url.host {
            return host
        }
        return bookmarkData.urlString
    }

    /// Opens the URL in the default browser
    private func openURL() {
        if let url = bookmarkData.url {
            NSWorkspace.shared.open(url)
        }
    }

    /// Copies the URL to the clipboard
    private func copyURL() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(bookmarkData.urlString, forType: .string)
    }

    /// Refreshes the bookmark metadata
    private func refreshMetadata() {
        guard let url = bookmarkData.url else { return }

        isLoading = true
        Task {
            do {
                let metadata = try await URLMetadataFetcher.shared.fetch(url: url)
                await MainActor.run {
                    bookmarkData.update(from: metadata)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    let data = BookmarkData(
        urlString: "https://apple.com",
        title: "Apple",
        descriptionText: "Discover the innovative world of Apple and shop everything iPhone, iPad, Apple Watch, Mac, and Apple TV.",
        faviconURLString: "https://www.google.com/s2/favicons?domain=apple.com&sz=32",
        ogImageURLString: nil
    )

    return BookmarkBlockView(bookmarkData: data, onDelete: {})
        .frame(width: 400)
        .padding()
}
