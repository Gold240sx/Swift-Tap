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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [RichTextNote.self, Category.self, Tag.self, AppSettings.self], inMemory: true)
}
