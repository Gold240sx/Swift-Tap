//
//  SCR4TCHApp.swift
//  SCR4TCH
//
//  Created by Michael Martell on 1/27/26.
//

import SwiftUI
import SwiftData

@main
struct SCR4TCHApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RichTextNote.self,
            Category.self,
            Tag.self,
            NoteBlock.self,
            TableData.self,
            TableCell.self,
            AccordionData.self,
            CodeBlockData.self,
            ImageData.self,
            ColumnData.self,
            Column.self,
            ListData.self,
            ListItem.self,
            BookmarkData.self,
            FilePathData.self,
            ReminderData.self,
            AppSettings.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

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
        .commands {
            MacSettingsCommands()
            
            // Remove Window Menu
            CommandGroup(replacing: .windowList) {}
            
            // Remove View Menu items (Sidebar and Toolbar commands)
            CommandGroup(replacing: .sidebar) {}
            CommandGroup(replacing: .toolbar) {}
            // Remove "New Window" (File > New)
            CommandGroup(replacing: .newItem) {}

            // Remove Window Sizing
            CommandGroup(replacing: .windowSize) {}
            
            CommandMenu("View") {
                Button("Add New Tab") {
                    // Trigger system "New Tab" action
                    NSApp.sendAction(Selector("newWindowForTab:"), to: nil, from: nil)
                }
                .keyboardShortcut("t", modifiers: .command) 
            }
        }
    }
}
