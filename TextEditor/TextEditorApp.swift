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
        
        let schema = Schema([Category.self, RichTextNote.self, TableData.self, TableCell.self, NoteBlock.self, AccordionData.self, CodeBlockData.self, ImageData.self, ColumnData.self, Column.self, ListData.self, ListItem.self])
        let config = ModelConfiguration()
        do {
            container = try ModelContainer(for: schema, configurations: config)
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
    }
}
