//
//----------------------------------------------
// Original project: RichNotes
// by  Stewart Lynch on 2025-10-28
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


import Foundation
import SwiftData

@Model
class RichTextNote {
    var text: AttributedString
    var createdOn: Date
    var updatedOn: Date
    var category: Category?
    
    @Relationship(deleteRule: .cascade)
    var tables: [TableData]
    
    @Relationship(deleteRule: .cascade)
    var blocks: [NoteBlock]

    /// Stores the last used code language for new code blocks (defaults to "swift")
    var lastUsedCodeLanguage: String = "swift"

    var previewText: String {
        blocks.sorted(by: { $0.orderIndex < $1.orderIndex })
            .compactMap { block in
                if let text = block.text {
                    return String(text.characters)
                }
                return nil
            }
            .joined(separator: " ")
    }
    
    init(text: AttributedString, createdOn: Date = Date.now, updatedOn: Date = Date.now) {
        self.text = text
        self.createdOn = createdOn
        self.updatedOn = updatedOn
        self.tables = []
        self.blocks = []
    }
    
    static var sample: RichTextNote = RichTextNote(text: """
        Now is the time for all good men to come to the aid of the party.
        
        This is going to be a lot of fun.
        """)
}
