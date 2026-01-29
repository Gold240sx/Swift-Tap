//
//----------------------------------------------
// Original project: RichNotes
// by  Stewart Lynch on 2025-10-22
//
// Follow me on Mastodon: https://iosdev.space/@StewartLynch
// Follow me on Threads: https://www.threads.net/@stewartlynch
// Follow me on Bluesky: https://bsky.app/profile/stewartlynch.bsky.social
// Follow me on X: https://x.com/StewartLynch
// Follow me on LinkedIn: https://linkedin.com/in/StewartLynch
// Email: slynch@createchsol.com
// Subscribe on YouTube: https://youTube.com/@StewartLynch
// Buy me a ko-fi:  https://ko-fi.com/StewartLynch
//----------------------------------------------
// Copyright © 2025 CreaTECH Solutions. All rights reserved.


import SwiftUI
import AppKit

struct RichTextEditorView: View {
    @State private var text: AttributedString = ""
    @State private var selection = AttributedTextSelection()
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var moreEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            MacEditorView(
                text: $text,
                selection: $selection,
                selectedRange: $selectedRange,
                font: .systemFont(ofSize: NSFont.systemFontSize)
            )
                .focused($isFocused)
                .padding()
                .navigationTitle("RichText Editor")
                .toolbarTitleDisplayMode(.inlineLarge)
                .toolbar {
                    #if os(iOS)
                    ToolbarItemGroup(placement: .keyboard) {
                        Group {
                            FormatStyleButtons(text: $text, selectedRange: $selectedRange)
                            Spacer()
                            Button {
                                moreEditing.toggle()
                            } label: {
                                Image(systemName: "textformat.alt")
                            }
                            Button {
                                isFocused = false
                            } label: {
                                Image(systemName: "keyboard.chevron.compact.down")
                            }
                        }
                        .disabled(!isFocused)
                    }
                    #else
                    ToolbarItemGroup(placement: .primaryAction) {
                        FormatStyleButtons(text: $text, selectedRange: $selectedRange)
                        Button {
                            moreEditing.toggle()
                        } label: {
                            Image(systemName: "textformat.alt")
                        }
                    }
                    #endif
                }
                #if os(iOS)
                .sheet(isPresented: $moreEditing) {
                    MoreFormattingView(text: $text, selectedRange: $selectedRange)
                        .presentationDetents([.height(200)])
                }
                #else
                .popover(isPresented: $moreEditing) {
                    MoreFormattingView(text: $text, selectedRange: $selectedRange)
                        .frame(width: 400, height: 250)
                }
                #endif
        }
    }
}

#Preview {
    RichTextEditorView()
}
