import SwiftUI
import SwiftData

import SDWebImage
import SDWebImageSVGCoder

@main
struct TextEditorApp: App {
    let container: ModelContainer
    
    init() {
        // Register SVG Coder
        SDImageCodersManager.shared.addCoder(SDImageSVGCoder.shared)
        
        let schema = Schema([
            Category.self, Tag.self, RichTextNote.self, TableData.self, TableCell.self,
            NoteBlock.self, AccordionData.self, CodeBlockData.self, ImageData.self,
            ColumnData.self, Column.self, ListData.self, ListItem.self, BookmarkData.self,
            FilePathData.self, AppSettings.self
        ])
        let config = ModelConfiguration()
        do {
            container = try ModelContainer(for: schema, configurations: config)
            ensureInitialSettings()
            
            // Run lifecycle cleanup on launch
            Task { @MainActor [container] in
                let context = ModelContext(container)
                LifecycleManager.shared.runCleanup(context: context)
            }
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            NotesView()
                .modelContainer(container)
                .onAppear {
                    print(URL.applicationSupportDirectory.path(percentEncoded: false))
                }
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
                .modelContainer(container)
        }
        
        MenuBarExtra("RichText Notes", systemImage: "note.text") {
            NoteMenuBarView()
                .modelContainer(container)
        }
        #endif
    }
    
    private func ensureInitialSettings() {
        let context = ModelContext(container)
        let fetchDescriptor = FetchDescriptor<AppSettings>()
        if let settings = try? context.fetch(fetchDescriptor), settings.isEmpty {
            context.insert(AppSettings.default)
            try? context.save()
        }
    }
}
