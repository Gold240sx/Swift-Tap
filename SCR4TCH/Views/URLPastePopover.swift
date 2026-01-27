//
//  URLPastePopover.swift
//  TextEditor
//
//  Popover shown when a URL is pasted, allowing the user to choose the URL display type.
//

import SwiftUI

/// Types of URL display options
enum URLDisplayType: String, CaseIterable {
    case standard   // Blue underlined text
    case bookmark   // Full block with title, description, favicon, og:image
}

struct URLPastePopover: View {
    let url: URL
    let onSelect: (URLDisplayType) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                Text("Insert URL as...")
                    .font(.headline)
                Spacer()
            }

            // URL preview
            Text(url.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Divider()

            // Options
            VStack(spacing: 8) {
                URLOptionButton(
                    title: "Link",
                    description: "Blue underlined text",
                    icon: "link",
                    action: { onSelect(.standard) }
                )

                URLOptionButton(
                    title: "Bookmark",
                    description: "Block with title, description, and image",
                    icon: "bookmark.fill",
                    action: { onSelect(.bookmark) }
                )
            }

            Divider()

            // Cancel button
            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .frame(width: 260)
    }
}

/// A button for URL display options
struct URLOptionButton: View {
    let title: String
    let description: String
    let icon: String
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        }
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    URLPastePopover(
        url: URL(string: "https://apple.com")!,
        onSelect: { _ in },
        onCancel: {}
    )
}
