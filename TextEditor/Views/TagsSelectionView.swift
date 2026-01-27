//
//  TagsSelectionView.swift
//  TextEditor
//
//  View for selecting tags for a note
//

import SwiftUI
import SwiftData

struct TagsSelectionView: View {
    @Bindable var note: RichTextNote
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @Query(sort: \Tag.name) private var allTags: [Tag]
    
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search or Create Tag...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit(selectOrNewTag)
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
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Divider()
                
                tagsList
            }
            .navigationTitle("Tags")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    @ViewBuilder
    private var tagsList: some View {
        let filteredTags = searchText.isEmpty ? allTags : allTags.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        let exactMatch = allTags.first(where: { $0.name.localizedCaseInsensitiveCompare(searchText) == .orderedSame })
        let showCreateRow = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && exactMatch == nil
        
        if filteredTags.isEmpty && !showCreateRow {
            VStack(spacing: 12) {
                Spacer()
                ContentUnavailableView {
                    Label(searchText.isEmpty ? "No tags created" : "No matching tags", systemImage: "tag")
                } description: {
                    Text(searchText.isEmpty ? "Start typing to create a tag." : "Try a different search term.")
                }
                Spacer()
            }
        } else {
            List {
                if showCreateRow {
                    Button {
                        selectOrNewTag()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                            Text("Create \"\(searchText)\"")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                ForEach(filteredTags) { tag in
                    tagRow(for: tag, isExactMatch: tag.id == exactMatch?.id)
                }
            }
            .listStyle(.plain)
        }
    }
    
    @ViewBuilder
    private func tagRow(for tag: Tag, isExactMatch: Bool) -> some View {
        let isSelected = note.tags.contains(where: { $0.id == tag.id })
        
        HStack {
            Button {
                toggleTag(tag)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    
                    Image(systemName: "tag.fill")
                        .foregroundStyle(Color(hex: tag.hexColor)!)
                    
                    Text(tag.name)
                        .foregroundStyle(.primary)
                        .fontWeight(isExactMatch ? .bold : .regular)
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            Button {
                deleteTag(tag)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(0.7))
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
    
    private func selectOrNewTag() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // 1. Check for exact match
        if let exactMatch = allTags.first(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            if !note.tags.contains(where: { $0.id == exactMatch.id }) {
                note.tags.append(exactMatch)
                try? context.save()
            }
        } 
        // 2. No exact match, but let's see if we should create it
        else {
            let newTag = Tag(name: trimmed, hexColor: Color.accentColor.toHex() ?? "#007AFF")
            context.insert(newTag)
            note.tags.append(newTag)
            try? context.save()
        }
        
        withAnimation {
            searchText = ""
        }
    }
    
    private func toggleTag(_ tag: Tag) {
        if let index = note.tags.firstIndex(where: { $0.id == tag.id }) {
            note.tags.remove(at: index)
        } else {
            note.tags.append(tag)
        }
        try? context.save()
    }
    
    private func deleteTag(_ tag: Tag) {
        note.tags.removeAll { $0.id == tag.id }
        context.delete(tag)
        try? context.save()
    }
}

