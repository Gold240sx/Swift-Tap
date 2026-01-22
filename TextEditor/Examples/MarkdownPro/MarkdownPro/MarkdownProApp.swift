//
//  MarkdownProApp.swift
//  MarkdownPro
//
//  Created by Michael Martell on 1/11/26.
//

import SwiftUI
import SwiftData
import SDWebImageSVGCoder

@main
struct MarkdownProApp: App {
    init() {
        // Configure SDWebImage SVG support
        SDWebImageSetup.configure()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Document.self,
            Folder.self,
            Tag.self,
            EditorSettings.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Document") {
                    NotificationCenter.default.post(name: .createNewDocument, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .saveItem) {
                Button("Save Document") {
                    NotificationCenter.default.post(name: .saveDocument, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        #endif
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let createNewDocument = Notification.Name("createNewDocument")
    static let saveDocument = Notification.Name("saveDocument")
}
