import SwiftUI
import SwiftData

@main
struct TextEditorApp: App {
    let container: ModelContainer
    
    init() {
        let schema = Schema([Category.self, RichTextNote.self, TableData.self, TableCell.self, NoteBlock.self, AccordionData.self, CodeBlockData.self])
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
