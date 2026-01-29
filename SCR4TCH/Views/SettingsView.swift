import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    @Query private var allSettings: [AppSettings]
    @ObservedObject private var langManager = LanguageManager.shared
    
    private var settings: AppSettings {
        allSettings.first ?? AppSettings.default
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(langManager.translate("appearance_language")) {
                    Picker(langManager.translate("language"), selection: Binding(
                        get: { langManager.currentLanguage },
                        set: { langManager.setLanguage($0) }
                    )) {
                        ForEach(SupportedLanguage.allCases, id: \.self) { language in
                            Text("\(language.flag) \(language.name)").tag(language)
                        }
                    }
                    
                    Picker(langManager.translate("font_size"), selection: Binding(
                        get: { langManager.currentFontSize },
                        set: { langManager.setFontSize($0) }
                    )) {
                        ForEach(FontSizePreference.allCases, id: \.self) { preference in
                            Label(preference.name, systemImage: preference.icon)
                                .tag(preference)
                        }
                    }
                    
                }
                
                Section(langManager.translate("notes_configuration")) {
                    Picker(langManager.translate("default_save_location"), selection: Binding(
                        get: { settings.defaultStatus ?? .saved },
                        set: {
                            settings.defaultStatus = $0
                            try? context.save()
                        }
                    )) {
                        Text(langManager.translate("saved")).tag(RichTextNote.NoteStatus.saved)
                        Text(langManager.translate("temp")).tag(RichTextNote.NoteStatus.temp)
                    }
                }
                
                Section(langManager.translate("cleanup_rules")) {
                    Picker(langManager.translate("temp_note_duration"), selection: Binding(
                        get: { settings.tempDurationHours ?? 24 },
                        set: {
                            settings.tempDurationHours = $0
                            try? context.save()
                        }
                    )) {
                        Text("1 \(langManager.translate("hour"))").tag(1)
                        Text("12 \(langManager.translate("hours"))").tag(12)
                        Text("24 \(langManager.translate("hours"))").tag(24)
                        Text("48 \(langManager.translate("hours"))").tag(48)
                        Text("7 \(langManager.translate("days"))").tag(168)
                    }
                    
                    Text(langManager.translate("deleted_notes_info"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(langManager.translate("settings"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(langManager.translate("done")) {
                        dismiss()
                    }
                }
            }
            .frame(width: 500, height: 450)
        }
    }
}

struct CategoryManagementView: View {
    @Environment(\.modelContext) var context
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var newCategoryName = ""
    @State private var newCategoryColor = Color.accentColor
    
    var body: some View {
        VStack {
            List {
                ForEach(categories) { category in
                    HStack {
                        Circle()
                            .fill(Color(hex: category.hexColor ?? "#808080") ?? .gray)
                            .frame(width: 12, height: 12)
                        Text(category.name ?? "Uncategorized")
                        Spacer()
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        context.delete(categories[index])
                    }
                    try? context.save()
                }
            }
            
            Divider()
            
            HStack {
                TextField("New Category", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
                ColorPicker("", selection: $newCategoryColor)
                    .labelsHidden()
                Button("Add") {
                    let category = Category(name: newCategoryName, hexColor: newCategoryColor.toHex() ?? "#808080")
                    context.insert(category)
                    try? context.save()
                    newCategoryName = ""
                }
                .disabled(newCategoryName.isEmpty)
            }
            .padding()
        }
    }
}

struct TagManagementView: View {
    @Environment(\.modelContext) var context
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var newTagName = ""
    @State private var newTagColor = Color.accentColor
    
    var body: some View {
        VStack {
            List {
                ForEach(tags) { tag in
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(Color(hex: tag.hexColor ?? "#808080") ?? .gray)
                        Text(tag.name ?? "Tag")
                        Spacer()
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        context.delete(tags[index])
                    }
                    try? context.save()
                }
            }
            
            Divider()
            
            HStack {
                TextField("New Tag", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                ColorPicker("", selection: $newTagColor)
                    .labelsHidden()
                Button("Add") {
                    let tag = Tag(name: newTagName, hexColor: newTagColor.toHex() ?? "#808080")
                    context.insert(tag)
                    try? context.save()
                    newTagName = ""
                }
                .disabled(newTagName.isEmpty)
            }
            .padding()
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: AppSettings.self, inMemory: true)
}
