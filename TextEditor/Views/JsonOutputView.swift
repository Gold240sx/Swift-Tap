import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
private let platformTextBackgroundColor = UIColor.systemBackground
#elseif canImport(AppKit)
import AppKit
private let platformTextBackgroundColor = NSColor.textBackgroundColor
#endif

enum OutputViewMode: String, CaseIterable {
    case json = "JSON"
    case markdown = "Markdown"
    case preview = "Preview"
}

struct JsonOutputView: View {
    let note: RichTextNote
    @State private var copied: Bool = false
    @State private var copiedAsMarkdown: Bool = false
    @State private var viewMode: OutputViewMode = .json
    @Environment(\.colorScheme) private var colorScheme
    
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
    
    /// Returns the JSON wrapped in Markdown code fences
    var markdownJsonOutput: String {
        return "```json\n\(jsonString)\n```"
    }
    
    /// Converts the note content to Markdown format
    var markdownContent: String {
        var markdown = ""
        
        // Title
        if !note.title.isEmpty {
            markdown += "# \(note.title)\n\n"
        }
        
        // Blocks
        for block in note.blocks.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            markdown += blockToMarkdown(block)
            markdown += "\n\n"
        }
        
        return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Converts a single block to Markdown
    private func blockToMarkdown(_ block: NoteBlock) -> String {
        switch block.type {
        case .text:
            if let text = block.text {
                return convertAttributedStringToMarkdown(text)
            }
            return ""
            
        case .table:
            if let table = block.table {
                var md = ""
                if !table.title.isEmpty {
                    md += "**\(table.title)**\n\n"
                }
                
                // Header row
                var headerRow = "|"
                for c in 0..<table.columnCount {
                    if let cell = table.getCell(row: 0, column: c) {
                        headerRow += " \(cell.content) |"
                    } else {
                        headerRow += " |"
                    }
                }
                md += headerRow + "\n"
                
                // Separator
                var separator = "|"
                for _ in 0..<table.columnCount {
                    separator += " --- |"
                }
                md += separator + "\n"
                
                // Data rows
                for r in 1..<table.rowCount {
                    var row = "|"
                    for c in 0..<table.columnCount {
                        if let cell = table.getCell(row: r, column: c) {
                            row += " \(cell.content) |"
                        } else {
                            row += " |"
                        }
                    }
                    md += row + "\n"
                }
                return md
            }
            return ""
            
        case .accordion:
            if let accordion = block.accordion {
                var md = ""
                let headingLevel = accordion.level == .h1 ? "#" : (accordion.level == .h2 ? "##" : "###")
                md += "\(headingLevel) \(String(accordion.heading.characters))\n\n"
                
                for nestedBlock in accordion.contentBlocks.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                    md += blockToMarkdown(nestedBlock)
                    md += "\n\n"
                }
                return md.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ""
            
        case .code:
            if let codeBlock = block.codeBlock {
                let lang = codeBlock.language == .plainText ? "" : codeBlock.languageString
                return "```\(lang)\n\(codeBlock.code)\n```"
            }
            return ""
            
        case .list:
            if let listData = block.listData {
                var md = ""
                for item in listData.items.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                    let prefix: String
                    switch listData.listType {
                    case .bullet:
                        prefix = "- "
                    case .numbered:
                        prefix = "\(item.orderIndex + 1). "
                    case .checkbox:
                        prefix = item.isChecked ? "- [x] " : "- [ ] "
                    }
                    md += "\(prefix)\(item.text ?? "")\n"
                }
                return md
            }
            return ""
            
        case .quote:
            if let text = block.text {
                let lines = String(text.characters).components(separatedBy: "\n")
                return lines.map { "> \($0)" }.joined(separator: "\n")
            }
            return ""
            
        case .image:
            if let imageData = block.imageData {
                var md = "![\(imageData.altText)]"
                if !imageData.urlString.isEmpty {
                    md += "(\(imageData.urlString))"
                }
                return md
            }
            return ""
            
        case .bookmark:
            if let bookmarkData = block.bookmarkData {
                return "[\(bookmarkData.title)](\(bookmarkData.urlString))"
            }
            return ""
            
        case .filePath:
            if let filePathData = block.filePathData {
                return "[\(filePathData.displayName)](\(filePathData.pathString))"
            }
            return ""
            
        case .columns:
            if let columnData = block.columnData {
                var md = ""
                for column in columnData.columns.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                    md += "**Column \(column.orderIndex + 1):**\n\n"
                    for colBlock in column.blocks.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                        md += blockToMarkdown(colBlock)
                        md += "\n\n"
                    }
                }
                return md.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ""
        }
    }
    
    /// Converts AttributedString to Markdown, preserving formatting
    private func convertAttributedStringToMarkdown(_ attributedString: AttributedString) -> String {
        #if os(macOS)
        // Convert to NSAttributedString for easier attribute access
        let nsAttributedString = NSAttributedString(attributedString)
        var markdown = ""
        
        nsAttributedString.enumerateAttributes(in: NSRange(location: 0, length: nsAttributedString.length), options: []) { attributes, range, _ in
            let text = nsAttributedString.attributedSubstring(from: range).string
            
            // Get font attributes
            var isBold = false
            var isItalic = false
            
            if let font = attributes[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                isBold = traits.contains(.bold)
                isItalic = traits.contains(.italic)
            }
            
            let underlineStyle = attributes[.underlineStyle] as? Int ?? 0
            let strikethroughStyle = attributes[.strikethroughStyle] as? Int ?? 0
            
            var formattedText = text
            
            // Apply formatting in order: strikethrough, bold, italic, underline
            if strikethroughStyle == NSUnderlineStyle.single.rawValue {
                formattedText = "~~\(formattedText)~~"
            }
            if isBold && isItalic {
                formattedText = "***\(formattedText)***"
            } else if isBold {
                formattedText = "**\(formattedText)**"
            } else if isItalic {
                formattedText = "*\(formattedText)*"
            }
            if underlineStyle == NSUnderlineStyle.single.rawValue {
                // Markdown doesn't have native underline, but we can use HTML
                formattedText = "<u>\(formattedText)</u>"
            }
            
            markdown += formattedText
        }
        
        return markdown
        #else
        // For iOS, use a simpler approach
        var markdown = ""
        
        for run in attributedString.runs {
            let runRange = run.range
            let text = String(attributedString[runRange].characters)
            
            let font = run.font
            let underlineStyle = run.underlineStyle
            let strikethroughStyle = run.strikethroughStyle
            
            var formattedText = text
            
            if strikethroughStyle == .single {
                formattedText = "~~\(formattedText)~~"
            }
            if underlineStyle == .single {
                formattedText = "<u>\(formattedText)</u>"
            }
            
            markdown += formattedText
        }
        
        return markdown
        #endif
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewMode == .json ? "Page JSON Schema" : (viewMode == .markdown ? "Markdown Output" : "Markdown Preview"))
                    .font(.headline)
                Spacer()
                Menu {
                    Button {
                        #if os(iOS)
                        UIPasteboard.general.string = jsonString
                        #else
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(jsonString, forType: .string)
                        #endif
                        withAnimation {
                            copied = true
                            copiedAsMarkdown = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        Label(copied && !copiedAsMarkdown ? "Copied" : "Copy JSON", systemImage: copied && !copiedAsMarkdown ? "checkmark.circle.fill" : "doc.on.doc")
                    }
                    
                    if viewMode != .json {
                        Button {
                            #if os(iOS)
                            UIPasteboard.general.string = markdownContent
                            #else
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(markdownContent, forType: .string)
                            #endif
                            withAnimation {
                                copiedAsMarkdown = true
                                copied = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copiedAsMarkdown = false
                            }
                        } label: {
                            Label(copiedAsMarkdown ? "Copied" : "Copy Markdown", systemImage: copiedAsMarkdown ? "checkmark.circle.fill" : "doc.text")
                        }
                    }
                    
                    Button {
                        let markdown = markdownJsonOutput
                        #if os(iOS)
                        UIPasteboard.general.string = markdown
                        #else
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(markdown, forType: .string)
                        #endif
                        withAnimation {
                            copiedAsMarkdown = true
                            copied = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copiedAsMarkdown = false
                        }
                    } label: {
                        Label("Copy JSON as Markdown", systemImage: "doc.text")
                    }
                } label: {
                    Label(
                        copied ? (copiedAsMarkdown ? "Copied" : "Copied") : "Copy",
                        systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc"
                    )
                    .foregroundColor(copied ? .green : .accentColor)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            
            Divider()
            
            // View mode selector
            Picker("View Mode", selection: $viewMode) {
                ForEach(OutputViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            
            Divider()
            
            // Content view based on selected mode
            ScrollView {
                switch viewMode {
                case .json:
                    Text(jsonString)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        
                case .markdown:
                    Text(markdownContent)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        
                case .preview:
                    MarkdownPreviewView(content: markdownContent)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(Color(platformTextBackgroundColor))
    }
}

// MARK: - Markdown Preview View

struct MarkdownPreviewView: View {
    let content: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parseMarkdownBlocks(content), id: \.id) { block in
                renderBlock(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private struct MarkdownBlock {
        enum BlockType {
            case text(String)
            case code(String, String) // content, language
        }
        let type: BlockType
        let id = UUID()
    }
    
    private func parseMarkdownBlocks(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = markdown.components(separatedBy: "\n")
        var index = 0
        var inCodeBlock = false
        var codeBlockContent: [String] = []
        var codeBlockLanguage = ""
        var textContent: [String] = []
        
        while index < lines.count {
            let line = lines[index]
            
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    if !codeBlockContent.isEmpty {
                        blocks.append(MarkdownBlock(type: .code(codeBlockContent.joined(separator: "\n"), codeBlockLanguage)))
                    }
                    codeBlockContent = []
                    codeBlockLanguage = ""
                    inCodeBlock = false
                } else {
                    // Start code block - save any accumulated text first
                    if !textContent.isEmpty {
                        blocks.append(MarkdownBlock(type: .text(textContent.joined(separator: "\n"))))
                        textContent = []
                    }
                    inCodeBlock = true
                    codeBlockLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                index += 1
                continue
            }
            
            if inCodeBlock {
                codeBlockContent.append(line)
            } else {
                textContent.append(line)
            }
            index += 1
        }
        
        // Handle any remaining content
        if inCodeBlock && !codeBlockContent.isEmpty {
            blocks.append(MarkdownBlock(type: .code(codeBlockContent.joined(separator: "\n"), codeBlockLanguage)))
        } else if !textContent.isEmpty {
            blocks.append(MarkdownBlock(type: .text(textContent.joined(separator: "\n"))))
        }
        
        return blocks
    }
    
    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block.type {
        case .code(let code, let language):
            CodeBlockPreview(code: code, language: language)
                .padding(.vertical, 4)
        case .text(let text):
            let lines = text.components(separatedBy: "\n")
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                renderMarkdownLine(line.trimmingCharacters(in: .whitespaces))
            }
        }
    }
    
    @ViewBuilder
    private func renderMarkdownLine(_ trimmed: String) -> some View {
        if trimmed.isEmpty {
            Spacer()
                .frame(height: 8)
        } else if trimmed.hasPrefix("# ") {
            Text(String(trimmed.dropFirst(2)))
                .font(.system(size: 32, weight: .bold))
                .padding(.vertical, 4)
        } else if trimmed.hasPrefix("## ") {
            Text(String(trimmed.dropFirst(3)))
                .font(.system(size: 24, weight: .bold))
                .padding(.vertical, 4)
        } else if trimmed.hasPrefix("### ") {
            Text(String(trimmed.dropFirst(4)))
                .font(.system(size: 20, weight: .semibold))
                .padding(.vertical, 4)
        } else if trimmed.hasPrefix("> ") {
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 3)
                Text(String(trimmed.dropFirst(2)))
                    .font(.system(size: 15).italic())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } else if trimmed.hasPrefix("|") && trimmed.contains("|") && !trimmed.hasPrefix("|---") {
            // Table row (skip separator rows)
            let cells = trimmed.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
            HStack(spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    if !cell.isEmpty {
                        Text(cell)
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        } else if trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]") {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.square.fill")
                    .foregroundStyle(.green)
                Text(String(trimmed.dropFirst(6)))
                    .strikethrough()
                    .foregroundStyle(.secondary)
            }
        } else if trimmed.hasPrefix("- [ ]") {
            HStack(spacing: 8) {
                Image(systemName: "square")
                    .foregroundStyle(.secondary)
                Text(String(trimmed.dropFirst(6)))
            }
        } else if trimmed.hasPrefix("- ") {
            HStack(spacing: 8) {
                Text("•")
                    .foregroundStyle(.secondary)
                Text(String(trimmed.dropFirst(2)))
            }
        } else if trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
            let parts = trimmed.split(separator: ". ", maxSplits: 1)
            if parts.count == 2 {
                HStack(spacing: 8) {
                    Text("\(parts[0]).")
                        .foregroundStyle(.secondary)
                    Text(String(parts[1]))
                }
            } else {
                renderInlineMarkdown(trimmed)
            }
        } else {
            renderInlineMarkdown(trimmed)
        }
    }
    
    private func renderInlineMarkdown(_ text: String) -> some View {
        // Simple inline markdown rendering
        var attributed = AttributedString(text)
        
        // Bold **text**
        if let regex = try? NSRegularExpression(pattern: #"\*\*(.+?)\*\*"#) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                if let range = Range(match.range(at: 1), in: text) {
                    let boldText = String(text[range])
                    if let attrRange = attributed.range(of: "**\(boldText)**") {
                        attributed[attrRange].font = .system(size: 15, weight: .bold)
                        attributed.replaceSubrange(attrRange, with: AttributedString(boldText))
                    }
                }
            }
        }
        
        // Italic *text*
        if let regex = try? NSRegularExpression(pattern: #"(?<!\*)\*([^*]+?)\*(?!\*)"#) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                if let range = Range(match.range(at: 1), in: text) {
                    let italicText = String(text[range])
                    if let attrRange = attributed.range(of: "*\(italicText)*") {
                        attributed[attrRange].font = .system(size: 15).italic()
                        attributed.replaceSubrange(attrRange, with: AttributedString(italicText))
                    }
                }
            }
        }
        
        // Code `text`
        if let regex = try? NSRegularExpression(pattern: #"`([^`]+)`"#) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                if let range = Range(match.range(at: 1), in: text) {
                    let codeText = String(text[range])
                    if let attrRange = attributed.range(of: "`\(codeText)`") {
                        attributed[attrRange].font = .system(size: 13, design: .monospaced)
                        attributed[attrRange].foregroundColor = .blue
                        attributed[attrRange].backgroundColor = Color.gray.opacity(0.2)
                        attributed.replaceSubrange(attrRange, with: AttributedString(codeText))
                    }
                }
            }
        }
        
        return Text(attributed)
            .font(.system(size: 15))
            .padding(.vertical, 2)
    }
}

// MARK: - Code Block Preview

struct CodeBlockPreview: View {
    let code: String
    let language: String
    @Environment(\.colorScheme) private var colorScheme
    
    private var theme: SyntaxTheme {
        colorScheme == .dark ? .dark : .light
    }
    
    private var highlighter: SyntaxHighlighter {
        SyntaxHighlighter(theme: theme, fontSize: 13)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !language.isEmpty {
                HStack {
                    Text(language)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.background.opacity(0.5))
                Divider()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(highlighter.highlight(code, language: language))
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
