import SwiftUI
import SwiftData

struct MetadataSelectionSheet: View {
    @Bindable var note: RichTextNote
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    
    enum MetadataTab: String, CaseIterable {
        case status = "Status"
        case categories = "Categories"
        case tags = "Tags"
        
        var icon: String {
            switch self {
            case .status: return "flag.fill"
            case .categories: return "folder.fill"
            case .tags: return "tag.fill"
            }
        }
    }
    
    @State private var selectedTab: MetadataTab = .status
    @State private var searchText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            tabBar
            
            Divider()
            
            VStack {
                switch selectedTab {
                case .status:
                    ScrollView {
                        statusSection.padding()
                    }
                case .categories:
                    categoryTabContent
                case .tags:
                    tagsTabContent
                }
            }
            .frame(height: 350) // Consistent height for the content area
            
            Divider()
            
            pinSection.padding()
        }
        .frame(width: 320)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
    }
    
    // MARK: - Subviews
    
    private var header: some View {
        HStack {
            Text("Note Properties")
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MetadataTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                        searchText = "" // Reset search when switching tabs
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .textCase(.uppercase)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selectedTab == tab ? .blue : .secondary)
                    .overlay(alignment: .bottom) {
                        if selectedTab == tab {
                            Rectangle()
                                .fill(.blue)
                                .frame(height: 2)
                                .padding(.horizontal, 16)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
    
    private var categoryTabContent: some View {
        VStack(spacing: 0) {
            searchBar(placeholder: "Search or Create Category...")
            
            let filteredCategories = searchText.isEmpty ? categories : categories.filter { ($0.name ?? "").localizedCaseInsensitiveContains(searchText) }
            let exactMatch = categories.first(where: { ($0.name ?? "").localizedCaseInsensitiveCompare(searchText) == .orderedSame })
            let showCreateRow = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && exactMatch == nil
            
            List {
                if showCreateRow {
                    Button {
                        createCategory()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Create \"\(searchText)\"")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.blue.opacity(0.1))
                }
                
                Section {
                    CategorySelectionItem(
                        name: "Uncategorized",
                        color: .gray,
                        isSelected: note.category == nil,
                        action: {
                            note.category = nil
                            try? context.save()
                        }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    
                    ForEach(filteredCategories.sorted(by: { ($0.name ?? "") < ($1.name ?? "") })) { category in
                        CategorySelectionItem(
                            name: category.name ?? "Uncategorized",
                            color: Color(hex: category.hexColor ?? "#000000") ?? .blue,
                            isSelected: note.category == category,
                            action: {
                                note.category = category
                                try? context.save()
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    Text("Existing Categories")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
    
    private var tagsTabContent: some View {
        VStack(spacing: 0) {
            searchBar(placeholder: "Search or Create Tag...")
            
            let filteredTags = searchText.isEmpty ? allTags : allTags.filter { ($0.name ?? "").localizedCaseInsensitiveContains(searchText) }
            let exactMatch = allTags.first(where: { ($0.name ?? "").localizedCaseInsensitiveCompare(searchText) == .orderedSame })
            let showCreateRow = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && exactMatch == nil
            
            List {
                if showCreateRow {
                    Button {
                        createTag()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Create \"\(searchText)\"")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.blue.opacity(0.1))
                }
                
                Section {
                    ForEach(filteredTags.sorted(by: { ($0.name ?? "") < ($1.name ?? "") })) { tag in
                        TagSelectionItem(
                            tag: tag,
                            isSelected: (note.tags ?? []).contains(tag),
                            action: {
                                if note.tags == nil { note.tags = [] }
                                if let index = note.tags?.firstIndex(of: tag) {
                                    note.tags?.remove(at: index)
                                } else {
                                    note.tags?.append(tag)
                                }
                                try? context.save()
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    Text("Existing Tags")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
    
    private func searchBar(placeholder: String) -> some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Current Status", icon: "flag.fill")
            
            Text("Choose a status based on how long you intend to keep this note. This helps keep your notes organized and your workspace clean.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(spacing: 12) {
                ForEach(RichTextNote.NoteStatus.allCases.filter { $0 != .deletingSoon }, id: \.self) { status in
                    StatusButton(
                        status: status,
                        isSelected: note.status == status,
                        action: { 
                            note.status = status
                            if status == .deleted {
                                note.movedToDeletedOn = Date.now
                            } else {
                                note.movedToDeletedOn = nil
                            }
                            try? context.save()
                        }
                    )
                }
            }
        }
    }
    
    private func createCategory() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let newCategory = Category(name: trimmed, hexColor: "#34C759") // Default green
        context.insert(newCategory)
        note.category = newCategory
        try? context.save()
        
        withAnimation {
            searchText = ""
        }
    }
    
    private func createTag() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let newTag = Tag(name: trimmed, hexColor: "#007AFF") // Default blue
        context.insert(newTag)
        if note.tags == nil { note.tags = [] }
        note.tags?.append(newTag)
        try? context.save()
        
        withAnimation {
            searchText = ""
        }
    }
    
    private var pinSection: some View {
        Toggle(isOn: $note.isPinned) {
            SectionHeader(title: "Pinned", icon: "pin.fill")
        }
        .toggleStyle(.switch)
        .onChange(of: note.isPinned) {
            try? context.save()
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

struct StatusButton: View {
    let status: RichTextNote.NoteStatus
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.title3)
                Text(statusLabel)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? color.opacity(0.2) : Color.white.opacity(0.05))
            .foregroundStyle(isSelected ? color : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var iconName: String {
        switch status {
        case .saved: return "checkmark.circle.fill"
        case .temp: return "clock.fill"
        case .deletingSoon: return "clock.badge.exclamationmark.fill"
        case .deleted: return "trash.fill"
        }
    }
    
    private var statusLabel: String {
        switch status {
        case .saved: return "Saved"
        case .temp: return "Temp"
        case .deletingSoon: return "Deleting Soon"
        case .deleted: return "Deleted"
        }
    }
    
    private var color: Color {
        switch status {
        case .saved: return .blue
        case .temp: return .orange
        case .deletingSoon: return .red
        case .deleted: return .red
        }
    }
}

struct CategorySelectionItem: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(name)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                }
            }
            .padding(10)
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TagSelectionItem: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void
    
    private var tagColor: Color {
        Color(hex: tag.hexColor ?? "007AFF") ?? .gray
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return tagColor.opacity(0.2)
        } else {
            return Color.white.opacity(0.05)
        }
    }
    
    private var strokeColor: Color {
        if isSelected {
            return tagColor.opacity(0.5)
        } else {
            return Color.white.opacity(0.1)
        }
    }
    
    private var foregroundColor: Color {
        isSelected ? tagColor : .primary
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "tag.fill")
                    .font(.caption2)
                    .foregroundStyle(tagColor)
                Text(tag.name ?? "Tag")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(strokeColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
