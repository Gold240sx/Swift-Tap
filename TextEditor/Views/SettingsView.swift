import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) var context
    @Query private var allSettings: [AppSettings]
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Tag.name) private var tags: [Tag]
    
    private var settings: AppSettings {
        allSettings.first ?? AppSettings.default
    }
    
    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            CategoryManagementView()
                .tabItem {
                    Label("Categories", systemImage: "folder")
                }
            
            TagManagementView()
                .tabItem {
                    Label("Tags", systemImage: "tag")
                }
        }
        .frame(width: 500, height: 400)
        .navigationTitle("Settings")
    }
    
    private var generalSettings: some View {
        Form {
            Section("Notes Configuration") {
                Picker("Default Save Location", selection: Binding(
                    get: { settings.defaultStatus },
                    set: { 
                        settings.defaultStatus = $0
                        try? context.save()
                    }
                )) {
                    Text("Saved Notes").tag(RichTextNote.NoteStatus.saved)
                    Text("Temp Notes").tag(RichTextNote.NoteStatus.temp)
                }
                .help("Select where new notes are saved by default.")
            }
            
            Section("Cleanup Rules") {
                Picker("Temp Note Duration", selection: Binding(
                    get: { settings.tempDurationHours },
                    set: { 
                        settings.tempDurationHours = $0
                        try? context.save()
                    }
                )) {
                    Text("1 hour").tag(1)
                    Text("12 hours").tag(12)
                    Text("24 hours").tag(24)
                    Text("48 hours").tag(48)
                    Text("7 days").tag(168)
                }
                .help("How long a note stays in 'Temp' before being moved to 'Deleted'.")
                
                Text("Deleted notes are permanently removed after 30 days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
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
                            .fill(Color(hex: category.hexColor) ?? .gray)
                            .frame(width: 12, height: 12)
                        Text(category.name)
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
                            .foregroundStyle(Color(hex: tag.hexColor) ?? .gray)
                        Text(tag.name)
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
