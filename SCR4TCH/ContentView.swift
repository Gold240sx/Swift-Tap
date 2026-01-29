//
//  ContentView.swift
//  SCR4TCH
//
//  Created by Michael Martell on 1/27/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        NotesView()
            .onOpenURL { url in
                handleOpenURL(url)
            }
    }

    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "scr4tch" else { return }
        
        // Handle open-note
        if url.host == "open-note" {
            let path = url.path
            let uuidString = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if let uuid = UUID(uuidString: uuidString) {
                NotificationCenter.default.post(name: .openNote, object: uuid)
            }
        }
    }
}

extension Notification.Name {
    static let openNote = Notification.Name("openNote")
}

#Preview {
    ContentView()
        .modelContainer(for: [RichTextNote.self, Category.self, Tag.self, AppSettings.self], inMemory: true)
}
