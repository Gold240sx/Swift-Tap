import SwiftUI
import SwiftData

/// Sidebar view showing all documents organized by folders
struct DocumentListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Document> { !$0.isTrash }, sort: \Document.modifiedAt, order: .reverse)
    private var documents: [Document]

    @Query(sort: \Folder.sortOrder)
    private var folders: [Folder]

    @Binding var selectedDocument: Document?
    @State private var searchText = ""
    @State private var showingNewFolderSheet = false
    @State private var selectedFolder: Folder?
    @State private var sortOption: SortOption = .modified

    enum SortOption: String, CaseIterable {
        case modified = "Modified"
        case created = "Created"
        case title = "Title"
        case wordCount = "Word Count"

        var icon: String {
            switch self {
            case .modified: return "clock"
            case .created: return "calendar"
            case .title: return "textformat"
            case .wordCount: return "number"
            }
        }
    }

    private var filteredDocuments: [Document] {
        var result = documents

        // Filter by folder
        if let folder = selectedFolder {
            result = result.filter { $0.folder?.id == folder.id }
        }

        // Filter by search
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort
        switch sortOption {
        case .modified:
            result.sort { $0.modifiedAt > $1.modifiedAt }
        case .created:
            result.sort { $0.createdAt > $1.createdAt }
        case .title:
            result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .wordCount:
            result.sort { $0.wordCount > $1.wordCount }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search documents...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(white: 0.5).opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Folders section
            FolderSectionView(
                folders: folders,
                selectedFolder: $selectedFolder,
                showingNewFolderSheet: $showingNewFolderSheet
            )

            Divider()
                .padding(.vertical, 8)

            // Sort options
            HStack {
                Text("Sort by:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Label(option.rawValue, systemImage: option.icon)
                            .tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Spacer()

                Text("\(filteredDocuments.count) documents")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)

            // Document list
            List(selection: $selectedDocument) {
                ForEach(filteredDocuments) { document in
                    DocumentRowView(document: document)
                        .tag(document)
                        .contextMenu {
                            documentContextMenu(for: document)
                        }
                }
                .onDelete(perform: deleteDocuments)
            }
            .listStyle(.sidebar)
        }
        .sheet(isPresented: $showingNewFolderSheet) {
            NewFolderSheet()
        }
    }

    @ViewBuilder
    private func documentContextMenu(for document: Document) -> some View {
        Button(action: { toggleFavorite(document) }) {
            Label(
                document.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: document.isFavorite ? "star.slash" : "star"
            )
        }

        Divider()

        Menu("Move to Folder") {
            Button("No Folder") {
                document.folder = nil
            }
            Divider()
            ForEach(folders) { folder in
                Button(folder.name) {
                    document.folder = folder
                }
            }
        }

        Divider()

        Button(role: .destructive, action: { moveToTrash(document) }) {
            Label("Move to Trash", systemImage: "trash")
        }
    }

    private func deleteDocuments(at offsets: IndexSet) {
        for index in offsets {
            let document = filteredDocuments[index]
            moveToTrash(document)
        }
    }

    private func toggleFavorite(_ document: Document) {
        document.isFavorite.toggle()
        document.modifiedAt = Date()
    }

    private func moveToTrash(_ document: Document) {
        document.moveToTrash()
    }
}

// MARK: - Document Row View

struct DocumentRowView: View {
    @Bindable var document: Document

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if document.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                Text(document.title)
                    .font(.headline)
                    .lineLimit(1)
            }

            Text(document.excerpt)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Text(document.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(document.wordCount) words")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Folder Section View

struct FolderSectionView: View {
    let folders: [Folder]
    @Binding var selectedFolder: Folder?
    @Binding var showingNewFolderSheet: Bool

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Folders")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: { showingNewFolderSheet = true }) {
                        Image(systemName: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            if isExpanded {
                VStack(spacing: 2) {
                    // All documents
                    FolderRowView(
                        name: "All Documents",
                        icon: "doc.text",
                        color: .blue,
                        isSelected: selectedFolder == nil,
                        action: { selectedFolder = nil }
                    )

                    // Folders
                    ForEach(folders.filter { $0.parent == nil }) { folder in
                        FolderRowView(
                            name: folder.name,
                            icon: folder.icon,
                            color: Color(hex: folder.colorHex) ?? .blue,
                            isSelected: selectedFolder?.id == folder.id,
                            action: { selectedFolder = folder }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }
}

// MARK: - Folder Row View

struct FolderRowView: View {
    let name: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)

                Text(name)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? color.opacity(0.15) : (isHovering ? Color.primary.opacity(0.05) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - New Folder Sheet

struct NewFolderSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedIcon = "folder"
    @State private var selectedColor = "#007AFF"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Folder Name", text: $name)

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.adaptive(minimum: 40)), count: 6), spacing: 8) {
                        ForEach(Folder.iconOptions, id: \.self) { icon in
                            Button(action: { selectedIcon = icon }) {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.adaptive(minimum: 40)), count: 6), spacing: 8) {
                        ForEach(Folder.colorOptions, id: \.hex) { option in
                            Button(action: { selectedColor = option.hex }) {
                                Circle()
                                    .fill(Color(hex: option.hex) ?? .blue)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == option.hex ? 2 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createFolder()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }

    private func createFolder() {
        let folder = Folder(
            name: name,
            icon: selectedIcon,
            colorHex: selectedColor
        )
        modelContext.insert(folder)
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selected: Document? = nil

    DocumentListView(selectedDocument: $selected)
        .frame(width: 300, height: 600)
        .modelContainer(for: [Document.self, Folder.self, Tag.self], inMemory: true)
}
