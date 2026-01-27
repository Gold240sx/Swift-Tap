import SwiftUI
import SwiftData

struct NoteMenuBarView: View {
    @Environment(\.modelContext) var context
    @Query(sort: \RichTextNote.updatedOn, order: .reverse) private var notes: [RichTextNote]
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Notes")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)
            
            ForEach(notes.prefix(10)) { note in
                Button {
                    // Open the main window and select this note
                    // Note: In a real app, you'd use a custom URL scheme or notification to trigger selection
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    HStack {
                        Image(systemName: note.status == .saved ? "note.text" : "clock")
                        Text(note.title.isEmpty ? "Untitled Note" : note.title)
                            .lineLimit(1)
                        Spacer()
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                        }
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            Button("New Note...") {
                let newNote = RichTextNote(text: "")
                context.insert(newNote)
                try? context.save()
                NSApp.activate(ignoringOtherApps: true)
            }
            
            Button("Open Main Window") {
                NSApp.activate(ignoringOtherApps: true)
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.bottom, 8)
    }
}
