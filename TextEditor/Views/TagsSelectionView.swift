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
    @State private var showTagEditor = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Current tags
                if !note.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Tags")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(note.tags) { tag in
                                HStack(spacing: 4) {
                                    Image(systemName: "tag.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Color(hex: tag.hexColor)!)
                                    Text(tag.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Button {
                                        note.tags.removeAll { $0.id == tag.id }
                                        try? context.save()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: tag.hexColor)?.opacity(0.15) ?? Color.gray.opacity(0.1))
                                .foregroundStyle(Color(hex: tag.hexColor) ?? .primary)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    Divider()
                }
                
                // Available tags
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Available Tags")
                            .font(.headline)
                        Spacer()
                        Button {
                            showTagEditor = true
                        } label: {
                            Label("New Tag", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if allTags.isEmpty {
                        VStack(spacing: 12) {
                            ContentUnavailableView("No tags available", systemImage: "tag")
                            Button {
                                showTagEditor = true
                            } label: {
                                Label("Create Your First Tag", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(allTags) { tag in
                                    HStack {
                                        Image(systemName: "tag.fill")
                                            .foregroundStyle(Color(hex: tag.hexColor)!)
                                        Text(tag.name)
                                        Spacer()
                                        if note.tags.contains(where: { $0.id == tag.id }) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        } else {
                                            Button {
                                                note.tags.append(tag)
                                                try? context.save()
                                            } label: {
                                                Image(systemName: "plus.circle")
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if note.tags.contains(where: { $0.id == tag.id }) {
                                            note.tags.removeAll { $0.id == tag.id }
                                        } else {
                                            note.tags.append(tag)
                                        }
                                        try? context.save()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Tags")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showTagEditor) {
                TagsView()
            }
            #else
            .popover(isPresented: $showTagEditor) {
                TagsView()
                    .frame(width: 400, height: 500)
            }
            #endif
        }
    }
}

