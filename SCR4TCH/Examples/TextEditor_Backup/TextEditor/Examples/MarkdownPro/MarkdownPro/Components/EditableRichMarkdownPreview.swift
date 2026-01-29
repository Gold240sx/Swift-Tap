import SwiftUI
import SDWebImageSwiftUI

/// A rich markdown preview that allows inline editing of content
/// Changes sync back to the markdown source
struct EditableRichMarkdownPreview: View {
    @Binding var content: String
    let theme: EditorTheme
    let fontSize: CGFloat
    let lineHeight: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @State private var editingBlockIndex: Int? = nil
    @State private var editingText: String = ""

    private var parser: MarkdownParser {
        MarkdownParser(theme: theme, fontSize: fontSize, lineHeight: lineHeight)
    }

    private var blocksWithRanges: [(block: MarkdownBlock, range: Range<String.Index>)] {
        parseBlocksWithRanges(content)
    }

    private var syntaxTheme: SyntaxTheme {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: fontSize * 0.75) {
                ForEach(Array(blocksWithRanges.enumerated()), id: \.offset) { index, item in
                    EditableBlockView(
                        block: item.block,
                        range: item.range,
                        isEditing: editingBlockIndex == index,
                        editingText: $editingText,
                        theme: theme,
                        fontSize: fontSize,
                        syntaxTheme: syntaxTheme,
                        onTap: {
                            startEditing(index: index, range: item.range)
                        },
                        onCommit: {
                            commitEdit(at: item.range)
                        },
                        onCancel: {
                            cancelEdit()
                        }
                    )
                }

                // Add new content area at bottom
                if editingBlockIndex == nil {
                    AddContentButton(theme: theme, fontSize: fontSize) {
                        addNewParagraph()
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background)
        .onTapGesture {
            // Clicking outside cancels editing
            if editingBlockIndex != nil {
                cancelEdit()
            }
        }
    }

    private func startEditing(index: Int, range: Range<String.Index>) {
        editingText = String(content[range])
        editingBlockIndex = index
    }

    private func commitEdit(at range: Range<String.Index>) {
        guard editingBlockIndex != nil else { return }

        // Replace the content at the range
        content.replaceSubrange(range, with: editingText)
        editingBlockIndex = nil
        editingText = ""
    }

    private func cancelEdit() {
        editingBlockIndex = nil
        editingText = ""
    }

    private func addNewParagraph() {
        if !content.isEmpty && !content.hasSuffix("\n") {
            content += "\n"
        }
        content += "\n"
        // Start editing the new empty paragraph
        editingText = ""
        editingBlockIndex = blocksWithRanges.count
    }

    // MARK: - Table Parsing Helpers
    
    private func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("|") && !trimmed.replacingOccurrences(of: "|", with: "").trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let pattern = #"^\s*\|?\s*(:?-+:?\s*\|)+\s*(:?-+:?\s*)?\|?\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            return regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil
        }
        return false
    }
    
    private func parseTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") {
            trimmed = String(trimmed.dropFirst())
        }
        if trimmed.hasSuffix("|") {
            trimmed = String(trimmed.dropLast())
        }
        return trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
    
    private func parseTableFromRows(_ rows: [String], headerRows: Set<Int>, headerColumns: Set<Int>) -> MarkdownBlock {
        guard !rows.isEmpty else {
            return .paragraph(AttributedString(""), alignment: .left)
        }
        
        // Find separator row index
        var separatorIndex = -1
        for (idx, row) in rows.enumerated() {
            if isTableSeparator(row) {
                separatorIndex = idx
                break
            }
        }
        
        guard separatorIndex >= 1 && separatorIndex < rows.count else {
            return .paragraph(AttributedString(""), alignment: .left)
        }
        
        // Parse header row
        let headers = parseTableRow(rows[0])
        
        // Parse alignments from separator
        let separatorRow = parseTableRow(rows[separatorIndex])
        let alignments: [MarkdownBlock.TableAlignment] = separatorRow.map { section in
            let str = section.trimmingCharacters(in: .whitespaces)
            if str.hasPrefix(":") && str.hasSuffix(":") { return .center }
            if str.hasPrefix(":") { return .left }
            if str.hasSuffix(":") { return .right }
            return .none
        }
        
        // Parse data rows
        var dataRows: [[String]] = []
        for i in (separatorIndex + 1)..<rows.count {
            if isTableRow(rows[i]) {
                dataRows.append(parseTableRow(rows[i]))
            }
        }
        
        return .table(
            headers: headers,
            rows: dataRows,
            alignments: alignments,
            headerRows: headerRows.isEmpty ? [0] : headerRows,
            headerColumns: headerColumns.isEmpty ? [0] : headerColumns
        )
    }
    
    private func parseColumnsFromContents(_ columnContents: [[String]]) -> MarkdownBlock {
        // Parse each column's content into blocks
        let columnBlocks: [[MarkdownBlock]] = columnContents.map { lines in
            let markdown = lines.joined(separator: "\n")
            // Use the main parser to parse each column
            let blocks = parser.parseToBlocks(markdown)
            // Ensure empty columns still render (add empty paragraph)
            return blocks.isEmpty ? [.paragraph(AttributedString(""), alignment: .left)] : blocks
        }
        return .columns(columnContents: columnBlocks)
    }

    /// Parse markdown and track source ranges for each block
    private func parseBlocksWithRanges(_ markdown: String) -> [(block: MarkdownBlock, range: Range<String.Index>)] {
        var results: [(block: MarkdownBlock, range: Range<String.Index>)] = []
        let lines = markdown.components(separatedBy: "\n")
        var currentIndex = markdown.startIndex
        var lineIndex = 0

        var inCodeBlock = false
        var codeBlockStart: String.Index?
        var codeBlockLanguage = ""
        var codeBlockContent = ""

        var inToggle = false
        var toggleStart: String.Index?
        var toggleLevel = 0
        var toggleTitle = ""
        var toggleContent: [String] = []

        var inColumns = false
        var columnsStart: String.Index?
        var columnContents: [[String]] = [[]]

        var inTable = false
        var tableStart: String.Index?
        var tableRows: [String] = []
        var tableHeaderRows: Set<Int> = []
        var tableHeaderColumns: Set<Int> = []

        while lineIndex < lines.count {
            let line = lines[lineIndex]
            let lineStart = currentIndex
            let lineEnd = markdown.index(currentIndex, offsetBy: line.count, limitedBy: markdown.endIndex) ?? markdown.endIndex

            // Move to next line position
            let nextLineStart: String.Index
            if lineEnd < markdown.endIndex {
                nextLineStart = markdown.index(after: lineEnd)
            } else {
                nextLineStart = markdown.endIndex
            }

            // Handle code blocks
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    if let start = codeBlockStart {
                        let range = start..<nextLineStart
                        let block = MarkdownBlock.codeBlock(code: codeBlockContent, language: codeBlockLanguage)
                        results.append((block, range))
                    }
                    inCodeBlock = false
                    codeBlockStart = nil
                    codeBlockContent = ""
                    codeBlockLanguage = ""
                } else {
                    // Start code block
                    inCodeBlock = true
                    codeBlockStart = lineStart
                    codeBlockLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                currentIndex = nextLineStart
                lineIndex += 1
                continue
            }

            if inCodeBlock {
                if !codeBlockContent.isEmpty {
                    codeBlockContent += "\n"
                }
                codeBlockContent += line
                currentIndex = nextLineStart
                lineIndex += 1
                continue
            }

            // Handle toggle end
            if line.trimmingCharacters(in: .whitespaces) == "<<<" && inToggle {
                if let start = toggleStart {
                    // Parse toggle content
                    let contentMarkdown = toggleContent.joined(separator: "\n")
                    let innerBlocks = parser.parseToBlocks(contentMarkdown)
                    let range = start..<nextLineStart
                    let toggleBlock = MarkdownBlock.toggleHeading(
                        level: toggleLevel,
                        title: parser.parseInlineElements(toggleTitle),
                        content: innerBlocks
                    )
                    results.append((toggleBlock, range))
                }
                inToggle = false
                toggleStart = nil
                toggleLevel = 0
                toggleTitle = ""
                toggleContent = []
                currentIndex = nextLineStart
                lineIndex += 1
                continue
            }

            // Handle columns
            if line.trimmingCharacters(in: .whitespaces) == "{columns}" {
                inColumns = true
                columnsStart = lineStart
                columnContents = [[]]
                currentIndex = nextLineStart
                lineIndex += 1
                continue
            }

            if line.trimmingCharacters(in: .whitespaces) == "{/columns}" && inColumns {
                // Process columns
                if let start = columnsStart {
                    let range = start..<nextLineStart
                    let columnsBlock = parseColumnsFromContents(columnContents)
                    results.append((columnsBlock, range))
                }
                inColumns = false
                columnsStart = nil
                columnContents = [[]]
                currentIndex = nextLineStart
                lineIndex += 1
                continue
            }

            if line.trimmingCharacters(in: .whitespaces) == "{---}" && inColumns {
                // Start new column
                columnContents.append([])
                currentIndex = nextLineStart
                lineIndex += 1
                continue
            }

            // Collect column content
            if inColumns {
                columnContents[columnContents.count - 1].append(line)
                currentIndex = nextLineStart
                lineIndex += 1
                continue
            }

            // Handle table markers
            if line.trimmingCharacters(in: .whitespaces) == "{table}" {
                inTable = true
                tableStart = lineStart
                tableRows = []
                tableHeaderRows = [0]
                tableHeaderColumns = [0]
                currentIndex = nextLineStart
                lineIndex += 1
                continue
            }

            if line.trimmingCharacters(in: .whitespaces) == "{/table}" && inTable {
                // Process table
                if let start = tableStart {
                    let range = start..<nextLineStart
                    let tableBlock = parseTableFromRows(tableRows, headerRows: tableHeaderRows, headerColumns: tableHeaderColumns)
                    results.append((tableBlock, range))
                }
                inTable = false
                tableStart = nil
                tableRows = []
                tableHeaderRows = []
                tableHeaderColumns = []
                currentIndex = nextLineStart
                lineIndex += 1
                continue
            }

            // Handle header row marker
            if line.trimmingCharacters(in: .whitespaces) == "{header}" && inTable {
                tableHeaderRows.insert(tableRows.count)
                currentIndex = nextLineStart
                lineIndex += 1
                continue
            }

            // Handle header column marker
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("{header:") && inTable {
                let pattern = #"\{header:(\d+)\}"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let colRange = Range(match.range(at: 1), in: line),
                   let colIndex = Int(String(line[colRange])) {
                    tableHeaderColumns.insert(colIndex)
                }
                currentIndex = nextLineStart
                lineIndex += 1
                continue
            }

            // Collect table rows
            if inTable {
                if isTableRow(line) || isTableSeparator(line) {
                    tableRows.append(line)
                }
                currentIndex = nextLineStart
                lineIndex += 1
                continue
            }

            // Check for toggle heading start
            if line.hasPrefix(">>>") {
                let pattern = #"^>>>(#{1,6})\s+(.+)$"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let hashRange = Range(match.range(at: 1), in: line),
                   let textRange = Range(match.range(at: 2), in: line) {
                    inToggle = true
                    toggleStart = lineStart
                    toggleLevel = line[hashRange].count
                    toggleTitle = String(line[textRange])
                    toggleContent = []
                    currentIndex = nextLineStart
                    lineIndex += 1
                    continue
                }
            }

            if inToggle {
                toggleContent.append(line)
                currentIndex = nextLineStart
                lineIndex += 1
                continue
            }

            // Simple block detection
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if !trimmedLine.isEmpty {
                let range = lineStart..<nextLineStart
                let block: MarkdownBlock

                if let headingMatch = parseHeadingLine(line) {
                    block = .heading(level: headingMatch.level, content: parser.parseInlineElements(headingMatch.text))
                } else if line.hasPrefix(">") {
                    let quoteContent = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                    block = .blockquote(parser.parseInlineElements(quoteContent))
                } else if let listMatch = parseListLine(line) {
                    block = .listItem(indent: listMatch.indent, style: listMatch.style, content: parser.parseInlineElements(listMatch.text))
                } else if trimmedLine == "---" || trimmedLine == "***" || trimmedLine == "___" {
                    block = .horizontalRule
                } else if let imageMatch = parseImageLine(trimmedLine) {
                    block = .image(url: imageMatch.url, alt: imageMatch.alt, width: imageMatch.width, height: imageMatch.height)
                } else {
                    let (content, alignment) = parseParagraphAlignment(line)
                    block = .paragraph(parser.parseInlineElements(content), alignment: alignment)
                }

                results.append((block, range))
            }

            currentIndex = nextLineStart
            lineIndex += 1
        }

        // Handle unclosed table
        if inTable, let start = tableStart {
            let range = start..<markdown.endIndex
            let tableBlock = parseTableFromRows(tableRows, headerRows: tableHeaderRows, headerColumns: tableHeaderColumns)
            results.append((tableBlock, range))
        }

        // Handle unclosed toggle
        if inToggle, let start = toggleStart {
            let contentMarkdown = toggleContent.joined(separator: "\n")
            let innerBlocks = parser.parseToBlocks(contentMarkdown)
            let range = start..<markdown.endIndex
            let toggleBlock = MarkdownBlock.toggleHeading(
                level: toggleLevel,
                title: parser.parseInlineElements(toggleTitle),
                content: innerBlocks
            )
            results.append((toggleBlock, range))
        }

        // Handle unclosed columns
        if inColumns, let start = columnsStart {
            let range = start..<markdown.endIndex
            let columnsBlock = parseColumnsFromContents(columnContents)
            results.append((columnsBlock, range))
        }

        return results
    }

    private func parseHeadingLine(_ line: String) -> (level: Int, text: String)? {
        let pattern = #"^(#{1,6})\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let hashRange = Range(match.range(at: 1), in: line),
              let textRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        return (line[hashRange].count, String(line[textRange]))
    }

    private func parseListLine(_ line: String) -> (indent: Int, style: MarkdownBlock.ListStyle, text: String)? {
        // Checkbox
        let checkboxPattern = #"^(\s*)[-*+]\s+\[([ xX])\]\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: checkboxPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let indentRange = Range(match.range(at: 1), in: line),
           let checkRange = Range(match.range(at: 2), in: line),
           let textRange = Range(match.range(at: 3), in: line) {
            let indent = line[indentRange].count / 2
            let checked = line[checkRange] != " "
            return (indent, .checkbox(checked: checked), String(line[textRange]))
        }

        // Numbered
        let numberedPattern = #"^(\s*)(\d+)\.\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: numberedPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let indentRange = Range(match.range(at: 1), in: line),
           let numRange = Range(match.range(at: 2), in: line),
           let textRange = Range(match.range(at: 3), in: line) {
            let indent = line[indentRange].count / 2
            let num = Int(String(line[numRange])) ?? 1
            return (indent, .numbered(num), String(line[textRange]))
        }

        // Bullet
        let bulletPattern = #"^(\s*)[-*+]\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: bulletPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let indentRange = Range(match.range(at: 1), in: line),
           let textRange = Range(match.range(at: 2), in: line) {
            let indent = line[indentRange].count / 2
            return (indent, .bullet, String(line[textRange]))
        }

        return nil
    }

    private func parseImageLine(_ line: String) -> (url: String, alt: String, width: CGFloat?, height: CGFloat?)? {
        let pattern = #"^!\[([^\]]*)\]\(([^)\s]+)(?:\s*=(\d*)x(\d*))?\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let urlRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        var alt = ""
        if let altRange = Range(match.range(at: 1), in: line) {
            alt = String(line[altRange])
        }

        let url = String(line[urlRange])
        var width: CGFloat? = nil
        var height: CGFloat? = nil

        if match.range(at: 3).location != NSNotFound,
           let widthRange = Range(match.range(at: 3), in: line) {
            let widthStr = String(line[widthRange])
            if !widthStr.isEmpty {
                width = CGFloat(Int(widthStr) ?? 0)
            }
        }

        if match.range(at: 4).location != NSNotFound,
           let heightRange = Range(match.range(at: 4), in: line) {
            let heightStr = String(line[heightRange])
            if !heightStr.isEmpty {
                height = CGFloat(Int(heightStr) ?? 0)
            }
        }

        return (url, alt, width, height)
    }

    private func parser(_ text: String) -> AttributedString {
        parser.parseInlineElements(text)
    }

    private func parseParagraphAlignment(_ text: String) -> (content: String, alignment: MarkdownBlock.ParagraphAlignment) {
        // Check for alignment markers: {align:left}, {align:center}, {align:right}
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let leftPattern = #"^\{align:left\}\s*(.+?)\s*\{/align\}$"#
        let centerPattern = #"^\{align:center\}\s*(.+?)\s*\{/align\}$"#
        let rightPattern = #"^\{align:right\}\s*(.+?)\s*\{/align\}$"#

        if let regex = try? NSRegularExpression(pattern: leftPattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let contentRange = Range(match.range(at: 1), in: trimmed) {
            return (String(trimmed[contentRange]), .left)
        }

        if let regex = try? NSRegularExpression(pattern: centerPattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let contentRange = Range(match.range(at: 1), in: trimmed) {
            return (String(trimmed[contentRange]), .center)
        }

        if let regex = try? NSRegularExpression(pattern: rightPattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let contentRange = Range(match.range(at: 1), in: trimmed) {
            return (String(trimmed[contentRange]), .right)
        }

        return (text, .left)
    }
}

// MARK: - Editable Block View

struct EditableBlockView: View {
    let block: MarkdownBlock
    let range: Range<String.Index>
    let isEditing: Bool
    @Binding var editingText: String
    let theme: EditorTheme
    let fontSize: CGFloat
    let syntaxTheme: SyntaxTheme
    let onTap: () -> Void
    let onCommit: () -> Void
    let onCancel: () -> Void

    @State private var isHovering = false

    var body: some View {
        Group {
            if isEditing {
                editingView
            } else {
                displayView
            }
        }
    }

    @ViewBuilder
    private var displayView: some View {
        blockContent
            .padding(4)
            .background(isHovering ? theme.text.opacity(0.05) : Color.clear)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isHovering ? theme.link.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                onTap()
            }
            .help("Click to edit")
    }

    @ViewBuilder
    private var editingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $editingText)
                .font(.system(size: fontSize, design: .monospaced))
                .frame(minHeight: 60)
                .padding(8)
                .background(theme.background)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.link, lineWidth: 2)
                )

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button("Save") {
                    onCommit()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(8)
        .background(theme.text.opacity(0.05))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var blockContent: some View {
        switch block {
        case .paragraph(let content, let alignment):
            HStack {
                if alignment == .center || alignment == .right {
                    Spacer()
                }
                Text(content)
                    .multilineTextAlignment(textAlignment(for: alignment))
                    .textSelection(.enabled)
                if alignment == .center || alignment == .left {
                    Spacer()
                }
            }

        case .heading(let level, let content):
            Text(styledHeading(content, level: level))
                .textSelection(.enabled)
                .padding(.top, level == 1 ? fontSize * 0.5 : fontSize * 0.25)

        case .codeBlock(let code, let language):
            CodeBlockView(
                code: code,
                language: language,
                syntaxTheme: syntaxTheme,
                fontSize: fontSize
            )

        case .blockquote(let content):
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(theme.blockquote.opacity(0.5))
                    .frame(width: 3)

                Text(content)
                    .font(.system(size: fontSize).italic())
                    .foregroundColor(theme.blockquote)
                    .textSelection(.enabled)
            }

        case .listItem(let indent, let style, let content):
            HStack(alignment: .top, spacing: 8) {
                Text(listMarker(for: style))
                    .font(.system(size: fontSize))
                    .foregroundColor(theme.text.opacity(0.6))
                    .frame(width: 20, alignment: .trailing)

                Text(content)
                    .textSelection(.enabled)
            }
            .padding(.leading, CGFloat(indent) * 20)

        case .horizontalRule:
            Rectangle()
                .fill(theme.text.opacity(0.2))
                .frame(height: 1)

        case .image(let url, let alt, let width, let height):
            ImageBlockView(
                url: url,
                alt: alt,
                width: width,
                height: height,
                theme: theme,
                fontSize: fontSize
            )

        case .toggleHeading(let level, let title, let content):
            ToggleHeadingView(
                level: level,
                title: title,
                content: content,
                theme: theme,
                fontSize: fontSize,
                syntaxTheme: syntaxTheme
            )
            
        case .columns(let columnContents):
            ColumnsView(
                columns: columnContents,
                theme: theme,
                fontSize: fontSize,
                syntaxTheme: syntaxTheme
            )

        case .table(let headers, let rows, let alignments, let headerRows, let headerColumns):
            TableView(
                headers: headers,
                rows: rows,
                alignments: alignments,
                headerRows: headerRows,
                headerColumns: headerColumns,
                theme: theme,
                fontSize: fontSize
            )
        }
    }

    private func headingSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return 48
        case 2: return 36
        case 3: return 28
        case 4: return fontSize * 1.25
        case 5: return fontSize * 1.1
        default: return fontSize
        }
    }
    
    private func styledHeading(_ content: AttributedString, level: Int) -> AttributedString {
        var styled = content
        styled.font = .system(size: headingSize(for: level), weight: .bold)
        styled.foregroundColor = theme.heading
        return styled
    }

    private func listMarker(for style: MarkdownBlock.ListStyle) -> String {
        switch style {
        case .bullet: return "•"
        case .numbered(let n): return "\(n)."
        case .checkbox(let checked): return checked ? "☑" : "☐"
        }
    }

    private func textAlignment(for alignment: MarkdownBlock.ParagraphAlignment) -> TextAlignment {
        switch alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    private func frameAlignment(for alignment: MarkdownBlock.ParagraphAlignment) -> Alignment {
        switch alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}

// MARK: - Add Content Button

struct AddContentButton: View {
    let theme: EditorTheme
    let fontSize: CGFloat
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "plus.circle")
                Text("Add content...")
            }
            .font(.system(size: fontSize * 0.9))
            .foregroundColor(isHovering ? theme.link : theme.text.opacity(0.4))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
