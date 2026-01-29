import SwiftUI
import SwiftData

/// Full document editor view with title, tags, and markdown editor
struct DocumentEditorView: View {
    @Bindable var document: Document
    @Environment(\.modelContext) private var modelContext

    @Query private var allTags: [Tag]

    @State private var editorMode: EditorMode = .split
    @State private var isEditingTitle = false
    @State private var showingTagPicker = false
    @State private var autoSaveTask: Task<Void, Never>?

    private let autoSaveDelay: UInt64 = 2_000_000_000 // 2 seconds

    var body: some View {
        VStack(spacing: 0) {
            // Document header
            documentHeader

            Divider()

            // Markdown editor
            MarkdownEditor(
                content: Binding(
                    get: { document.content },
                    set: { newValue in
                        document.updateContent(newValue)
                        scheduleAutoSave()
                    }
                ),
                editorMode: $editorMode,
                showToolbar: true,
                showWordCount: true,
                onSave: saveDocument
            )
        }
        .onAppear {
            document.markAccessed()
            editorMode = document.metadata.editorMode ?? .split
        }
        .onDisappear {
            autoSaveTask?.cancel()
            saveDocument()
        }
    }

    private var documentHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            HStack {
                if isEditingTitle {
                    TextField("Document Title", text: $document.title)
                        .font(.title.bold())
                        .textFieldStyle(.plain)
                        .onSubmit { isEditingTitle = false }
                } else {
                    Text(document.title)
                        .font(.title.bold())
                        .onTapGesture {
                            isEditingTitle = true
                        }
                }

                Spacer()

                // Favorite button
                Button(action: { document.isFavorite.toggle() }) {
                    Image(systemName: document.isFavorite ? "star.fill" : "star")
                        .foregroundColor(document.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help(document.isFavorite ? "Remove from favorites" : "Add to favorites")
            }

            // Tags row
            HStack(spacing: 8) {
                // Existing tags
                ForEach(document.tags) { tag in
                    TagChip(tag: tag) {
                        document.tags.removeAll { $0.id == tag.id }
                    }
                }

                // Add tag button
                Button(action: { showingTagPicker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Tag")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingTagPicker) {
                    TagPickerView(document: document, allTags: allTags)
                }

                Spacer()

                // Metadata
                Text("Last modified \(document.modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: autoSaveDelay)
            if !Task.isCancelled {
                saveDocument()
            }
        }
    }

    private func saveDocument() {
        document.metadata.editorMode = editorMode
        document.modifiedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let tag: Tag
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: tag.colorHex) ?? .blue)
                .frame(width: 8, height: 8)

            Text(tag.name)
                .font(.caption)

            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: tag.colorHex)?.opacity(0.15) ?? Color.blue.opacity(0.15))
        .cornerRadius(12)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Tag Picker View

struct TagPickerView: View {
    @Bindable var document: Document
    let allTags: [Tag]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var newTagName = ""
    @State private var newTagColor = "#007AFF"

    var availableTags: [Tag] {
        allTags.filter { tag in
            !document.tags.contains { $0.id == tag.id }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)
                .padding(.bottom, 4)

            // Create new tag
            HStack {
                TextField("New tag name...", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { createAndAddTag() }

                Menu {
                    ForEach(Tag.colorOptions, id: \.hex) { option in
                        Button(action: { newTagColor = option.hex }) {
                            HStack {
                                Circle()
                                    .fill(Color(hex: option.hex) ?? .blue)
                                    .frame(width: 12, height: 12)
                                Text(option.name)
                            }
                        }
                    }
                } label: {
                    Circle()
                        .fill(Color(hex: newTagColor) ?? .blue)
                        .frame(width: 20, height: 20)
                }

                Button(action: createAndAddTag) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newTagName.isEmpty)
            }

            if !availableTags.isEmpty {
                Divider()

                Text("Existing Tags")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ScrollView {
                    FlowLayout(spacing: 8) {
                        ForEach(availableTags) { tag in
                            Button(action: { addTag(tag) }) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: tag.colorHex) ?? .blue)
                                        .frame(width: 8, height: 8)
                                    Text(tag.name)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
        .padding()
        .frame(width: 280)
    }

    private func createAndAddTag() {
        guard !newTagName.isEmpty else { return }

        // Check if tag already exists
        if let existingTag = allTags.first(where: { $0.name.lowercased() == newTagName.lowercased() }) {
            addTag(existingTag)
        } else {
            let tag = Tag(name: newTagName, colorHex: newTagColor)
            modelContext.insert(tag)
            addTag(tag)
        }

        newTagName = ""
    }

    private func addTag(_ tag: Tag) {
        if !document.tags.contains(where: { $0.id == tag.id }) {
            document.tags.append(tag)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Empty State View

struct EmptyDocumentView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No Document Selected")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Select a document from the sidebar or create a new one")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onCreate) {
                Label("New Document", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Document.self, Folder.self, Tag.self, configurations: config)

    let document = Document(title: "Sample Document", content: "# Hello World\n\nThis is a **sample** document.")
    container.mainContext.insert(document)

    return DocumentEditorView(document: document)
        .modelContainer(container)
        .frame(width: 800, height: 600)
}
