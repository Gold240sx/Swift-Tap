//
//  FilePathBlockView.swift
//  TextEditor
//
//  View for displaying file path blocks with file info, icon, and actions.
//

import SwiftUI
import AppKit

struct FilePathBlockView: View {
    @Bindable var filePathData: FilePathData
    var onDelete: () -> Void

    @State private var isHovered = false
    @State private var isLoading = false
    @State private var fileIcon: NSImage?

    var body: some View {
        mainContent
            .background { backgroundView }
            .overlay(alignment: .topTrailing) { hoverButtons }
            .overlay { loadingOverlay }
            .onHover { isHovered = $0 }
            .onTapGesture { openFile() }
            .contextMenu { contextMenuContent }
            .onAppear { loadFileIcon() }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        HStack(spacing: 0) {
            iconView
            infoView
            extensionBadge
        }
    }

    // MARK: - Icon View

    private var iconView: some View {
        VStack {
            if let icon = fileIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
            } else {
                fallbackIcon
            }
        }
        .padding(.leading, 12)
        .padding(.vertical, 12)
    }

    private var fallbackIcon: some View {
        let isDirectory = filePathData.isDirectory ?? false
        return Image(systemName: isDirectory ? "folder.fill" : "doc.fill")
            .font(.system(size: 36))
            .foregroundStyle(isDirectory ? .blue : .secondary)
            .frame(width: 48, height: 48)
    }

    // MARK: - Info View

    private var infoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(filePathData.displayTitle)
                .font(.headline)
                .lineLimit(1)
                .foregroundStyle(.primary)

            Text(filePathData.parentDirectory)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            metadataRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }

    private var metadataRow: some View {
        HStack(spacing: 12) {
            if let size = filePathData.formattedSize {
                metadataItem(icon: "doc", text: size)
            }

            if let date = filePathData.formattedDate {
                metadataItem(icon: "clock", text: date)
            }

            if !filePathData.fileExists {
                fileNotFoundIndicator
            }
        }
    }

    private func metadataItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }

    private var fileNotFoundIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text("File not found")
        }
        .font(.caption2)
        .foregroundStyle(.red)
    }

    // MARK: - Extension Badge

    @ViewBuilder
    private var extensionBadge: some View {
        if !(filePathData.fileExtension ?? "").isEmpty && !(filePathData.isDirectory ?? false) {
            Text((filePathData.fileExtension ?? "").uppercased())
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .foregroundColor(.accentColor)
                .clipShape(Capsule())
                .padding(.trailing, 12)
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1)
            }
    }

    private var borderColor: Color {
        filePathData.fileExists ? Color.gray.opacity(0.3) : Color.red.opacity(0.3)
    }

    // MARK: - Hover Buttons

    @ViewBuilder
    private var hoverButtons: some View {
        if isHovered {
            HStack(spacing: 4) {
                hoverButton(icon: "folder", help: "Reveal in Finder", action: revealInFinder)
                hoverButton(icon: "arrow.clockwise", help: "Refresh metadata", action: refreshMetadata)
                hoverButton(icon: "xmark", help: "Delete file link", action: onDelete)
            }
            .background {
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(radius: 2)
            }
            .padding(6)
        }
    }

    private func hoverButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .padding(4)
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    // MARK: - Loading Overlay

    @ViewBuilder
    private var loadingOverlay: some View {
        if isLoading {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay { ProgressView() }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        Button("Open") { openFile() }
        Button("Reveal in Finder") { revealInFinder() }
        Button("Copy Path") { copyPath() }
        Divider()
        Button("Refresh Metadata") { refreshMetadata() }
        Divider()
        Button("Delete", role: .destructive) { onDelete() }
    }

    // MARK: - Actions

    private func loadFileIcon() {
        guard let url = filePathData.fileURL else { return }

        Task {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 48, height: 48)

            await MainActor.run {
                self.fileIcon = icon
            }
        }
    }

    private func openFile() {
        guard let url = filePathData.fileURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func revealInFinder() {
        guard let url = filePathData.fileURL else { return }
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }

    private func copyPath() {
        guard let pathString = filePathData.pathString else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(pathString, forType: .string)
    }

    private func refreshMetadata() {
        isLoading = true

        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)

            await MainActor.run {
                filePathData.refreshMetadata()
                loadFileIcon()
                isLoading = false
            }
        }
    }
}

#Preview {
    let data = FilePathData(
        pathString: "/Users/example/Documents/test.pdf",
        displayName: "test.pdf",
        fileSize: 1024 * 1024 * 5,
        modificationDate: Date(),
        isDirectory: false
    )

    return FilePathBlockView(filePathData: data, onDelete: {})
        .frame(width: 400)
        .padding()
}
