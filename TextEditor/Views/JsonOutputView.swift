import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
private let platformTextBackgroundColor = UIColor.systemBackground
#elseif canImport(AppKit)
import AppKit
private let platformTextBackgroundColor = NSColor.textBackgroundColor
#endif

struct JsonOutputView: View {
    let note: RichTextNote
    @State private var copied: Bool = false
    
    var jsonString: String {
        var dict: [String: Any] = [
            "noteId": String(describing: note.persistentModelID),
            "createdOn": note.createdOn.formatted(),
            "updatedOn": note.updatedOn.formatted(),
            "category": note.category?.name ?? "None"
        ]
        
        var blocks: [[String: Any]] = []
        for block in note.blocks.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            var bDict: [String: Any] = [
                "id": block.id.uuidString,
                "type": "\(block.type)",
                "order": block.orderIndex
            ]
            
            if block.type == .text, let text = block.text {
                bDict["content"] = String(text.characters)
            } else if block.type == .table, let table = block.table {
                var tDict: [String: Any] = [
                    "title": table.title,
                    "rows": table.rowCount,
                    "cols": table.columnCount,
                    "columnWidths": table.columnWidths,
                    "rowHeights": table.rowHeights
                ]
                var cells: [[String: String]] = []
                for r in 0..<table.rowCount {
                    for c in 0..<table.columnCount {
                        if let content = table.getCell(row: r, column: c)?.content, !content.isEmpty {
                            cells.append(["r": "\(r)", "c": "\(c)", "text": content])
                        }
                    }
                }
                tDict["cells"] = cells
                bDict["table"] = tDict
            }
            blocks.append(bDict)
        }
        dict["blocks"] = blocks
        
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "Error encoding JSON"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Page JSON Schema")
                    .font(.headline)
                Spacer()
                Button {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(jsonString, forType: .string)
                    #endif
                    withAnimation {
                        copied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                        .foregroundColor(copied ? .green : .accentColor)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            
            Divider()
            
            ScrollView {
                Text(jsonString)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(platformTextBackgroundColor))
    }
}
