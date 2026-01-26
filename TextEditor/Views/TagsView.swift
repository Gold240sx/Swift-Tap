//
//  TagsView.swift
//  TextEditor
//
//  View for managing tags
//

import SwiftUI
import SwiftData

struct TagsView: View {
    enum Action: String {
        case new = "New Tag"
        case edit = "Edit Tag"
        case none = "Tags"
    }
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var action = Action.none
    @State private var tagName = ""
    @State private var hexColor = Color.primary
    @State private var selectedTag: Tag?
    
    var body: some View {
        NavigationStack {
            VStack {
                if action != .none {
                    HStack {
                        TextField("Tag Name", text: $tagName)
                            .textFieldStyle(.roundedBorder)
                        ColorPicker("Color", selection: $hexColor, supportsOpacity: false)
                            .labelsHidden()
                        if !tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                if let selectedTag,
                                   let foundTag = tags.first(where: {$0.id == selectedTag.id}) {
                                    foundTag.name = tagName
                                    foundTag.hexColor = hexColor.toHex()!
                                } else {
                                    let newTag = Tag(name: tagName, hexColor: hexColor.toHex()!)
                                    context.insert(newTag)
                                }
                                try? context.save()
                                withAnimation {
                                    reset()
                                }
                            } label: {
                                Image(systemName: "checkmark")
                            }
                            .buttonStyle(.glassProminent)
                        }
                    }
                    .padding(.horizontal)
                }
                
                if tags.isEmpty && action == .none {
                    ContentUnavailableView("Create your first tag", systemImage: "tag")
                } else if !tags.isEmpty {
                    List {
                        ForEach(tags) { tag in
                            HStack {
                                Image(systemName: "tag.fill")
                                    .foregroundStyle(Color(hex: tag.hexColor)!)
                                Text(tag.name)
                                if action != .new {
                                    Spacer()
                                    Button {
                                        withAnimation {
                                            action = .edit
                                            selectedTag = tag
                                            tagName = tag.name
                                            hexColor = Color(hex: tag.hexColor)!
                                        }
                                    } label: {
                                        Image(systemName: "pencil")
                                    }
                                }
                            }
                        }
                        .onDelete { indices in
                            for index in indices {
                                context.delete(tags[index])
                            }
                            try? context.save()
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .padding()
            .navigationTitle(action.rawValue)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        action = .new
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
    
    func reset() {
        action = .none
        tagName = ""
        hexColor = .primary
        selectedTag = nil
    }
}

#Preview(traits: .mockData) {
    TagsView()
}
