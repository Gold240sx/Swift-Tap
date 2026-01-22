import Foundation
import SwiftUI

/// Native Swift markdown parser that converts markdown to AttributedString
struct MarkdownParser {
    let theme: EditorTheme
    let fontSize: CGFloat
    let lineHeight: CGFloat

    init(theme: EditorTheme = .light, fontSize: CGFloat = 16, lineHeight: CGFloat = 1.5) {
        self.theme = theme
        self.fontSize = fontSize
        self.lineHeight = lineHeight
    }

    // MARK: - Table Parsing Helpers
    private func isTableRow(_ line: String) -> Bool {
        // Table rows should have at least one pipe '|' and should not be all whitespace
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("|") && !trimmed.replacingOccurrences(of: "|", with: "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func isTableSeparator(_ line: String) -> Bool {
        // Typical separator: |---|---| or --- | :---: | ---:
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let pattern = #"^\s*\|?\s*(:?-+:?\s*\|)+\s*(:?-+:?\s*)?\|?\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            return regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil
        }
        return false
    }

    private func parseTableBlock(lines: [String], startIndex: Int) -> (block: MarkdownBlock, nextIndex: Int) {
        var index = startIndex
        let headerLine = lines[index]
        index += 1
        let separatorLine = lines[index]
        index += 1
        var rowLines: [String] = []
        while index < lines.count, isTableRow(lines[index]) {
            rowLines.append(lines[index])
            index += 1
        }

        // Parse header - handle empty cells properly
        let headers = parseTableRow(headerLine)

        // Parse alignments - handle empty cells properly
        let alignSections = parseTableRow(separatorLine)
        let alignments: [MarkdownBlock.TableAlignment] = alignSections.map { section in
            let str = section.trimmingCharacters(in: .whitespaces)
            if str.hasPrefix(":") && str.hasSuffix(":") { return .center }
            if str.hasPrefix(":") { return .left }
            if str.hasSuffix(":") { return .right }
            return .none
        }

        // Parse rows - handle empty cells properly
        let rows: [[String]] = rowLines.map { parseTableRow($0) }

        return (block: .table(headers: headers, rows: rows, alignments: alignments), nextIndex: index)
    }

    private func parseTableRow(_ line: String) -> [String] {
        // Remove leading/trailing pipes if present
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") {
            trimmed = String(trimmed.dropFirst())
        }
        if trimmed.hasSuffix("|") {
            trimmed = String(trimmed.dropLast())
        }
        
        // Split by pipe and preserve empty cells
        return trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Parses markdown string to AttributedString (for simple inline rendering)
    func parse(_ markdown: String) -> AttributedString {
        var result = AttributedString()

        let lines = markdown.components(separatedBy: "\n")
        var inCodeBlock = false
        var codeBlockContent = ""
        var codeBlockLanguage = ""

        for (index, line) in lines.enumerated() {
            // Handle code blocks
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    result.append(parseCodeBlock(codeBlockContent, language: codeBlockLanguage))
                    codeBlockContent = ""
                    codeBlockLanguage = ""
                    inCodeBlock = false
                } else {
                    // Start code block
                    inCodeBlock = true
                    codeBlockLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                continue
            }

            if inCodeBlock {
                if !codeBlockContent.isEmpty {
                    codeBlockContent += "\n"
                }
                codeBlockContent += line
                continue
            }

            // Parse regular line
            let parsedLine = parseLine(line)
            result.append(parsedLine)

            // Add newline except for last line
            if index < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }

        return result
    }

    /// Parses markdown into structured blocks for rich rendering
    func parseToBlocks(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = markdown.components(separatedBy: "\n")
        var index = 0

        var inCodeBlock = false
        var codeBlockContent = ""
        var codeBlockLanguage = ""
        var currentParagraph = ""

        // Toggle heading state
        var inToggle = false
        var toggleLevel = 0
        var toggleTitle = ""
        var toggleContent: [String] = []

        // Column state
        var inColumns = false
        var columnContents: [[String]] = [[]]
        
        // Table state
        var inTable = false
        var tableRows: [String] = []
        var tableHeaderRows: Set<Int> = []
        var tableHeaderColumns: Set<Int> = []
        
        // Alignment state
        var inAlignment = false
        var currentAlignment: MarkdownBlock.ParagraphAlignment = .left
        var alignmentContent: [String] = []

        func flushParagraph() {
            if !currentParagraph.isEmpty {
                let (content, alignment) = parseParagraphAlignment(currentParagraph)
                blocks.append(.paragraph(parseInlineElements(content), alignment: alignment))
                currentParagraph = ""
            }
        }

        func parseParagraphAlignment(_ text: String) -> (content: String, alignment: MarkdownBlock.ParagraphAlignment) {
            // Check for alignment markers: {align:left}, {align:center}, {align:right}
            // This can appear at the start/end or wrapped in formatting like **{align:center}...{/align}**
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            
            // First try exact match (alignment tags at start/end)
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
            
            // Try to find alignment blocks wrapped in formatting (e.g., **{align:center}...{/align}**)
            // Pattern: any characters before, {align:...}content{/align}, any characters after
            // Use dotMatchesLineSeparators to handle multi-line content
            let wrappedPattern = #"(.+?)\{align:(left|center|right)\}(.+?)\{/align\}(.+?)"#
            if let regex = try? NSRegularExpression(pattern: wrappedPattern, options: [.dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                
                // Extract parts
                let beforeRange = Range(match.range(at: 1), in: text)
                let alignRange = Range(match.range(at: 2), in: text)
                let contentRange = Range(match.range(at: 3), in: text)
                let afterRange = Range(match.range(at: 4), in: text)
                
                guard let beforeRange = beforeRange,
                      let alignRange = alignRange,
                      let contentRange = contentRange,
                      let afterRange = afterRange else {
                    return (text, .left)
                }
                
                let beforeText = String(text[beforeRange])
                let alignType = String(text[alignRange])
                let alignmentContent = String(text[contentRange])
                let afterText = String(text[afterRange])
                
                // Determine alignment
                let alignment: MarkdownBlock.ParagraphAlignment
                switch alignType {
                case "left":
                    alignment = .left
                case "center":
                    alignment = .center
                case "right":
                    alignment = .right
                default:
                    alignment = .left
                }
                
                // Reconstruct content: keep formatting markers, remove alignment tags
                let cleanedContent = beforeText + alignmentContent + afterText
                
                return (cleanedContent, alignment)
            }

            return (text, .left)
        }

        func processToggleContent() {
            let contentMarkdown = toggleContent.joined(separator: "\n")
            let innerBlocks = parseToBlocks(contentMarkdown)
            blocks.append(.toggleHeading(
                level: toggleLevel,
                title: parseInlineElements(toggleTitle),
                content: innerBlocks
            ))
            toggleContent = []
            toggleTitle = ""
            toggleLevel = 0
            inToggle = false
        }

        func processColumns() {
            let columnBlocks: [[MarkdownBlock]] = columnContents.map { lines in
                let markdown = lines.joined(separator: "\n")
                let blocks = parseToBlocks(markdown)
                // Ensure empty columns still render (add empty paragraph)
                return blocks.isEmpty ? [.paragraph(AttributedString(""), alignment: .left)] : blocks
            }
            blocks.append(.columns(columnContents: columnBlocks))
            columnContents = [[]]
            inColumns = false
        }
        
        func processTable() {
            guard !tableRows.isEmpty else {
                inTable = false
                tableRows = []
                tableHeaderRows = []
                tableHeaderColumns = []
                return
            }
            
            // Find separator row index
            var separatorIndex = -1
            for (idx, row) in tableRows.enumerated() {
                if isTableSeparator(row) {
                    separatorIndex = idx
                    break
                }
            }
            
            // Need at least header (index 0) and separator (index >= 1)
            guard separatorIndex >= 1 && separatorIndex < tableRows.count else {
                // Invalid table - need at least header + separator
                inTable = false
                tableRows = []
                tableHeaderRows = []
                tableHeaderColumns = []
                return
            }
            
            // Parse header row (index 0)
            let headers = parseTableRow(tableRows[0])
            
            // Parse alignments from separator row
            let separatorRow = parseTableRow(tableRows[separatorIndex])
            let alignments: [MarkdownBlock.TableAlignment] = separatorRow.map { section in
                let str = section.trimmingCharacters(in: .whitespaces)
                if str.hasPrefix(":") && str.hasSuffix(":") { return .center }
                if str.hasPrefix(":") { return .left }
                if str.hasSuffix(":") { return .right }
                return .none
            }
            
            // Parse data rows (after separator)
            var dataRows: [[String]] = []
            for i in (separatorIndex + 1)..<tableRows.count {
                if isTableRow(tableRows[i]) {
                    dataRows.append(parseTableRow(tableRows[i]))
                }
            }
            
            // Create table block
            blocks.append(.table(
                headers: headers,
                rows: dataRows,
                alignments: alignments,
                headerRows: tableHeaderRows.isEmpty ? [0] : tableHeaderRows,
                headerColumns: tableHeaderColumns.isEmpty ? [0] : tableHeaderColumns
            ))

            inTable = false
            tableRows = []
            tableHeaderRows = []
            tableHeaderColumns = []
        }
        
        func processAlignment() {
            guard !alignmentContent.isEmpty else {
                inAlignment = false
                alignmentContent = []
                return
            }
            
            // Join all content lines, preserving line breaks
            var content = alignmentContent.joined(separator: "\n")
            
            // Remove closing tag if it's at the end of the content
            content = content.trimmingCharacters(in: .whitespaces)
            if content.hasSuffix("{/align}") {
                content = String(content.dropLast(8)).trimmingCharacters(in: .whitespaces)
            }
            
            // Parse the content to handle any nested markdown (inline formatting, etc.)
            // But we'll create a single paragraph block with alignment applied
            let parsedContent = parseInlineElements(content)
            
            // Create a single paragraph block with the alignment
            blocks.append(.paragraph(parsedContent, alignment: currentAlignment))
            
            inAlignment = false
            alignmentContent = []
        }

        while index < lines.count {
            let line = lines[index]

            // Handle code blocks (highest priority)
            if line.hasPrefix("```") {
                if inCodeBlock {
                    if inToggle {
                        toggleContent.append("```\(codeBlockLanguage)")
                        toggleContent.append(codeBlockContent)
                        toggleContent.append("```")
                    } else if inColumns {
                        columnContents[columnContents.count - 1].append("```\(codeBlockLanguage)")
                        columnContents[columnContents.count - 1].append(codeBlockContent)
                        columnContents[columnContents.count - 1].append("```")
                    } else if inAlignment {
                        // Code blocks inside alignment blocks are treated as text content
                        alignmentContent.append("```\(codeBlockLanguage)")
                        alignmentContent.append(codeBlockContent)
                        alignmentContent.append("```")
                    } else {
                        flushParagraph()
                        blocks.append(.codeBlock(code: codeBlockContent, language: codeBlockLanguage))
                    }
                    codeBlockContent = ""
                    codeBlockLanguage = ""
                    inCodeBlock = false
                } else {
                    if !inAlignment && !inToggle && !inColumns {
                        flushParagraph()
                    }
                    inCodeBlock = true
                    codeBlockLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                index += 1
                continue
            }

            if inCodeBlock {
                if !codeBlockContent.isEmpty {
                    codeBlockContent += "\n"
                }
                codeBlockContent += line
                index += 1
                continue
            }

            // Handle toggle end marker
            if line.trimmingCharacters(in: .whitespaces) == "<<<" && inToggle {
                flushParagraph()
                processToggleContent()
                index += 1
                continue
            }
            
            // Handle alignment block end marker
            if line.trimmingCharacters(in: .whitespaces) == "{/align}" && inAlignment {
                flushParagraph()
                processAlignment()
                index += 1
                continue
            }
            
            // Handle alignment block start markers
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if !inAlignment {
                // Check if line contains complete alignment block (opening and closing on same line)
                let completeAlignmentPattern = #"^\{align:(left|center|right)\}(.+?)\{/align\}$"#
                if let regex = try? NSRegularExpression(pattern: completeAlignmentPattern),
                   let match = regex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)),
                   let alignRange = Range(match.range(at: 1), in: trimmedLine),
                   let contentRange = Range(match.range(at: 2), in: trimmedLine) {
                    flushParagraph()
                    
                    // Determine alignment type
                    let alignType = String(trimmedLine[alignRange])
                    let alignment: MarkdownBlock.ParagraphAlignment
                    switch alignType {
                    case "left":
                        alignment = .left
                    case "center":
                        alignment = .center
                    case "right":
                        alignment = .right
                    default:
                        alignment = .left
                    }
                    
                    // Extract content between tags
                    let content = String(trimmedLine[contentRange])
                    let parsedContent = parseInlineElements(content)
                    blocks.append(.paragraph(parsedContent, alignment: alignment))
                    
                    index += 1
                    continue
                }
                
                // Check if line starts with alignment tag (multi-line block)
                let alignmentPattern = #"^\{align:(left|center|right)\}(.*)$"#
                if let regex = try? NSRegularExpression(pattern: alignmentPattern),
                   let match = regex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)),
                   let alignRange = Range(match.range(at: 1), in: trimmedLine) {
                    flushParagraph()
                    inAlignment = true
                    
                    // Determine alignment type
                    let alignType = String(trimmedLine[alignRange])
                    switch alignType {
                    case "left":
                        currentAlignment = .left
                    case "center":
                        currentAlignment = .center
                    case "right":
                        currentAlignment = .right
                    default:
                        currentAlignment = .left
                    }
                    
                    // Extract content after the opening tag (if any on same line)
                    if match.range(at: 2).location != NSNotFound,
                       let contentRange = Range(match.range(at: 2), in: trimmedLine) {
                        let remainingContent = String(trimmedLine[contentRange])
                        if !remainingContent.isEmpty {
                            alignmentContent.append(remainingContent)
                        }
                    }
                    
                    index += 1
                    continue
                }
            }

            // Handle table markers
            if line.trimmingCharacters(in: .whitespaces) == "{table}" {
                flushParagraph()
                currentParagraph = "" // Clear any accumulated content
                inTable = true
                tableRows = []
                tableHeaderRows = [0] // First row is always header
                tableHeaderColumns = [0] // First column is always header
                index += 1
                continue
            }

            if line.trimmingCharacters(in: .whitespaces) == "{/table}" && inTable {
                // Don't flush paragraph here - we're processing a table block, not a paragraph
                processTable()
                index += 1
                continue
            }
            
            // Handle header row marker
            if line.trimmingCharacters(in: .whitespaces) == "{header}" && inTable {
                // Mark the next row as header
                tableHeaderRows.insert(tableRows.count)
                index += 1
                continue
            }
            
            // Handle header column marker
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("{header:") && inTable {
                // Parse column index: {header:0} or {header:1}
                let pattern = #"\{header:(\d+)\}"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let colRange = Range(match.range(at: 1), in: line),
                   let colIndex = Int(String(line[colRange])) {
                    tableHeaderColumns.insert(colIndex)
                }
                index += 1
                continue
            }

            // Handle column markers
            if line.trimmingCharacters(in: .whitespaces) == "{columns}" {
                flushParagraph()
                inColumns = true
                columnContents = [[]]
                index += 1
                continue
            }

            if line.trimmingCharacters(in: .whitespaces) == "{---}" && inColumns {
                columnContents.append([])
                index += 1
                continue
            }

            if line.trimmingCharacters(in: .whitespaces) == "{/columns}" && inColumns {
                flushParagraph()
                processColumns()
                index += 1
                continue
            }

            // If in alignment block, collect content
            if inAlignment {
                alignmentContent.append(line)
                index += 1
                continue
            }

            // If in toggle, collect content
            if inToggle {
                toggleContent.append(line)
                index += 1
                continue
            }

            // If in table, collect content
            if inTable {
                // Only collect actual table rows (lines with pipes)
                // Skip empty lines and non-table lines (they'll be ignored)
                if isTableRow(line) || isTableSeparator(line) {
                    tableRows.append(line)
                }
                // Don't process empty lines or other content while in table mode
                index += 1
                continue
            }

            // If in columns, collect content
            if inColumns {
                columnContents[columnContents.count - 1].append(line)
                index += 1
                continue
            }

            // Check for toggle heading: >>>## Heading
            if let toggleHeading = parseToggleHeadingStart(line) {
                flushParagraph()
                inToggle = true
                toggleLevel = toggleHeading.level
                toggleTitle = toggleHeading.title
                index += 1
                continue
            }

            // Check for legacy table format (without {table} markers) - must have at least header row + separator row
            if !inTable && isTableRow(line) && index + 1 < lines.count && isTableSeparator(lines[index + 1]) {
                flushParagraph()
                let tableResult = parseTableBlock(lines: lines, startIndex: index)
                // Convert to new format with default headers
                if case .table(let headers, let rows, let alignments, _, _) = tableResult.block {
                    blocks.append(.table(headers: headers, rows: rows, alignments: alignments, headerRows: [0], headerColumns: [0]))
                }
                index = tableResult.nextIndex
                continue
            }

            // Check for regular block-level elements
            if let heading = parseHeadingBlock(line) {
                flushParagraph()
                blocks.append(heading)
            } else if let image = parseImageBlock(line) {
                flushParagraph()
                blocks.append(image)
            } else if let blockquote = parseBlockquoteBlock(line) {
                flushParagraph()
                blocks.append(blockquote)
            } else if let listItem = parseListItemBlock(line) {
                flushParagraph()
                blocks.append(listItem)
            } else if parseHorizontalRule(line) != nil {
                flushParagraph()
                blocks.append(.horizontalRule)
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flushParagraph()
            } else {
                // Don't add table rows to paragraph if we're not in table mode
                // (they should be handled by {table} markers or legacy format)
                if !inTable && (isTableRow(line) || isTableSeparator(line)) {
                    // This is a table row but we're not in table mode - skip it
                    // This shouldn't happen if {table} markers are used correctly, but handle gracefully
                    index += 1
                    continue
                }
                if !currentParagraph.isEmpty {
                    currentParagraph += " "
                }
                currentParagraph += line
            }

            index += 1
        }

        // Flush any remaining content
        flushParagraph()

        // Handle unclosed toggle
        if inToggle {
            processToggleContent()
        }

        // Handle unclosed columns
        if inColumns {
            processColumns()
        }
        
        // Handle unclosed table
        if inTable {
            processTable()
        }
        
        // Handle unclosed alignment block
        if inAlignment {
            processAlignment()
        }
        
        return blocks
    }

    // MARK: - Block Parsing

    private func parseHeadingBlock(_ line: String) -> MarkdownBlock? {
        let pattern = #"^(#{1,6})\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let hashRange = Range(match.range(at: 1), in: line),
              let textRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let level = line[hashRange].count
        let text = String(line[textRange])
        return .heading(level: level, content: parseInlineElements(text))
    }

    /// Parse toggle heading start: >>>## Heading Title
    private func parseToggleHeadingStart(_ line: String) -> (level: Int, title: String)? {
        let pattern = #"^>>>(#{1,6})\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let hashRange = Range(match.range(at: 1), in: line),
              let textRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let level = line[hashRange].count
        let title = String(line[textRange])
        return (level: level, title: title)
    }

    private func parseBlockquoteBlock(_ line: String) -> MarkdownBlock? {
        guard line.hasPrefix(">") else { return nil }
        let content = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
        return .blockquote(parseInlineElements(content))
    }

    private func parseImageBlock(_ line: String) -> MarkdownBlock? {
        // Standard markdown image: ![alt](url)
        // Extended with optional size: ![alt](url =100x200) or ![alt](url =100x) or ![alt](url =x200)
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Pattern for image with optional dimensions
        let pattern = #"^!\[([^\]]*)\]\(([^)\s]+)(?:\s*=(\d*)x(\d*))?\)$"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
            return nil
        }

        // Extract alt text
        var alt = ""
        if let altRange = Range(match.range(at: 1), in: trimmed) {
            alt = String(trimmed[altRange])
        }

        // Extract URL
        guard let urlRange = Range(match.range(at: 2), in: trimmed) else {
            return nil
        }
        let url = String(trimmed[urlRange])

        // Extract optional dimensions
        var width: CGFloat? = nil
        var height: CGFloat? = nil

        if match.range(at: 3).location != NSNotFound,
           let widthRange = Range(match.range(at: 3), in: trimmed) {
            let widthStr = String(trimmed[widthRange])
            if !widthStr.isEmpty {
                width = CGFloat(Int(widthStr) ?? 0)
            }
        }

        if match.range(at: 4).location != NSNotFound,
           let heightRange = Range(match.range(at: 4), in: trimmed) {
            let heightStr = String(trimmed[heightRange])
            if !heightStr.isEmpty {
                height = CGFloat(Int(heightStr) ?? 0)
            }
        }

        return .image(url: url, alt: alt, width: width, height: height)
    }

    private func parseListItemBlock(_ line: String) -> MarkdownBlock? {
        // Checkbox list
        let checkboxPattern = #"^(\s*)[-*+]\s+\[([ xX])\]\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: checkboxPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let indentRange = Range(match.range(at: 1), in: line),
           let checkRange = Range(match.range(at: 2), in: line),
           let textRange = Range(match.range(at: 3), in: line) {
            let indent = String(line[indentRange]).count / 2
            let isChecked = line[checkRange] != " "
            let text = String(line[textRange])
            return .listItem(indent: indent, style: .checkbox(checked: isChecked), content: parseInlineElements(text))
        }

        // Unordered list
        let unorderedPattern = #"^(\s*)[-*+]\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: unorderedPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let indentRange = Range(match.range(at: 1), in: line),
           let textRange = Range(match.range(at: 2), in: line) {
            let indent = String(line[indentRange]).count / 2
            let text = String(line[textRange])
            return .listItem(indent: indent, style: .bullet, content: parseInlineElements(text))
        }

        // Ordered list
        let orderedPattern = #"^(\s*)(\d+)\.\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: orderedPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let indentRange = Range(match.range(at: 1), in: line),
           let numberRange = Range(match.range(at: 2), in: line),
           let textRange = Range(match.range(at: 3), in: line) {
            let indent = String(line[indentRange]).count / 2
            let number = Int(String(line[numberRange])) ?? 1
            let text = String(line[textRange])
            return .listItem(indent: indent, style: .numbered(number), content: parseInlineElements(text))
        }

        return nil
    }

    /// Parses a single line of markdown
    private func parseLine(_ line: String) -> AttributedString {
        if let heading = parseHeading(line) {
            return heading
        }

        if let blockquote = parseBlockquote(line) {
            return blockquote
        }

        if let listItem = parseListItem(line) {
            return listItem
        }

        if let horizontalRule = parseHorizontalRule(line) {
            return horizontalRule
        }

        return parseInlineElements(line)
    }

    // MARK: - Block Elements (AttributedString output)

    private func parseHeading(_ line: String) -> AttributedString? {
        let pattern = #"^(#{1,6})\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let hashRange = Range(match.range(at: 1), in: line),
              let textRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let level = line[hashRange].count
        let text = String(line[textRange])

        var attributed = parseInlineElements(text)

        let headingSizes: [Int: CGFloat] = [
            1: fontSize * 2.0,
            2: fontSize * 1.75,
            3: fontSize * 1.5,
            4: fontSize * 1.25,
            5: fontSize * 1.1,
            6: fontSize * 1.0
        ]

        let size = headingSizes[level] ?? fontSize
        attributed.font = .system(size: size, weight: .bold)
        attributed.foregroundColor = theme.heading

        return attributed
    }

    private func parseBlockquote(_ line: String) -> AttributedString? {
        guard line.hasPrefix(">") else { return nil }

        let content = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
        var attributed = parseInlineElements(content)
        attributed.foregroundColor = theme.blockquote
        attributed.font = .system(size: fontSize).italic()

        var prefix = AttributedString("│ ")
        prefix.foregroundColor = theme.blockquote.opacity(0.5)
        prefix.font = .system(size: fontSize)

        return prefix + attributed
    }

    private func parseListItem(_ line: String) -> AttributedString? {
        // Unordered list
        let unorderedPattern = #"^(\s*)[-*+]\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: unorderedPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let indentRange = Range(match.range(at: 1), in: line),
           let textRange = Range(match.range(at: 2), in: line) {

            let indent = String(line[indentRange])
            let text = String(line[textRange])
            let indentLevel = indent.count / 2

            var bullet = AttributedString(String(repeating: "  ", count: indentLevel) + "• ")
            bullet.foregroundColor = theme.text.opacity(0.6)
            bullet.font = .system(size: fontSize)

            let content = parseInlineElements(text)
            return bullet + content
        }

        // Ordered list
        let orderedPattern = #"^(\s*)(\d+)\.\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: orderedPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let indentRange = Range(match.range(at: 1), in: line),
           let numberRange = Range(match.range(at: 2), in: line),
           let textRange = Range(match.range(at: 3), in: line) {

            let indent = String(line[indentRange])
            let number = String(line[numberRange])
            let text = String(line[textRange])
            let indentLevel = indent.count / 2

            var marker = AttributedString(String(repeating: "  ", count: indentLevel) + "\(number). ")
            marker.foregroundColor = theme.text.opacity(0.6)
            marker.font = .system(size: fontSize)

            let content = parseInlineElements(text)
            return marker + content
        }

        // Checkbox list
        let checkboxPattern = #"^(\s*)[-*+]\s+\[([ xX])\]\s+(.+)$"#
        if let regex = try? NSRegularExpression(pattern: checkboxPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let indentRange = Range(match.range(at: 1), in: line),
           let checkRange = Range(match.range(at: 2), in: line),
           let textRange = Range(match.range(at: 3), in: line) {

            let indent = String(line[indentRange])
            let isChecked = line[checkRange] != " "
            let text = String(line[textRange])
            let indentLevel = indent.count / 2

            let checkmark = isChecked ? "☑" : "☐"
            var marker = AttributedString(String(repeating: "  ", count: indentLevel) + "\(checkmark) ")
            marker.foregroundColor = isChecked ? theme.link : theme.text.opacity(0.6)
            marker.font = .system(size: fontSize)

            var content = parseInlineElements(text)
            if isChecked {
                content.strikethroughStyle = .single
                content.foregroundColor = theme.text.opacity(0.5)
            }

            return marker + content
        }

        return nil
    }

    private func parseHorizontalRule(_ line: String) -> AttributedString? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let patterns = [
            #"^-{3,}$"#,
            #"^\*{3,}$"#,
            #"^_{3,}$"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                var hr = AttributedString("─────────────────────────────────────────")
                hr.foregroundColor = theme.text.opacity(0.3)
                hr.font = .system(size: fontSize * 0.8)
                return hr
            }
        }

        return nil
    }

    private func parseCodeBlock(_ content: String, language: String) -> AttributedString {
        var attributed = AttributedString(content)
        attributed.font = .system(size: fontSize * 0.9, design: .monospaced)
        attributed.foregroundColor = theme.code
        attributed.backgroundColor = theme.codeBackground

        if !language.isEmpty {
            var label = AttributedString("[\(language)]\n")
            label.font = .system(size: fontSize * 0.75, design: .monospaced)
            label.foregroundColor = theme.code.opacity(0.6)
            label.backgroundColor = theme.codeBackground
            attributed = label + attributed
        }

        return AttributedString("\n") + attributed + AttributedString("\n")
    }

    // MARK: - Inline Elements

    func parseInlineElements(_ text: String, depth: Int = 0) -> AttributedString {
        // Prevent infinite recursion
        guard depth < 10 else {
            var result = AttributedString(text)
            result.font = .system(size: fontSize)
            result.foregroundColor = theme.text
            return result
        }
        
        var result = AttributedString(text)
        result.font = .system(size: fontSize)
        result.foregroundColor = theme.text

        // Apply inline formatting in order
        // Process formatting tags (size, color) first, then markdown syntax (bold, italic, etc.)
        // This allows nested formatting like **{size:21}text{/size}**
        result = applyFontSize(result, originalText: text, depth: depth)
        result = applyColor(result, originalText: text, depth: depth)
        result = applyBoldItalic(result, originalText: text, depth: depth)
        result = applyCode(result, originalText: text)
        result = applyLinks(result, originalText: text)
        result = applyStrikethrough(result, originalText: text)
        result = applyHighlight(result, originalText: text)
        result = applyUnderline(result, originalText: text)

        return result
    }

    // MARK: - Color Formatting {color:name}text{/color}

    private func applyColor(_ attributed: AttributedString, originalText: String, depth: Int = 0) -> AttributedString {
        var result = attributed

        let pattern = #"\{color:([a-zA-Z]+)\}(.+?)\{/color\}"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: originalText, range: NSRange(originalText.startIndex..., in: originalText))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: originalText),
                   let colorRange = Range(match.range(at: 1), in: originalText),
                   let textRange = Range(match.range(at: 2), in: originalText) {
                    let fullText = String(originalText[fullRange])
                    let colorName = String(originalText[colorRange]).lowercased()
                    let matchedText = String(originalText[textRange])

                    // Recursively parse the inner content to handle nested formatting
                    let innerParsed = parseInlineElements(matchedText, depth: depth + 1)
                    
                    if let attrRange = result.range(of: fullText) {
                        var styled = innerParsed
                        // Apply color to all runs, preserving existing font (size, weight, style)
                        for run in styled.runs {
                            styled[run.range].foregroundColor = colorFromName(colorName)
                            // Font is already set from recursive parsing, don't override it
                        }
                        result.replaceSubrange(attrRange, with: styled)
                    } else if let attrRange = result.range(of: matchedText) {
                        var styled = innerParsed
                        for run in styled.runs {
                            styled[run.range].foregroundColor = colorFromName(colorName)
                            // Font is already set from recursive parsing, don't override it
                        }
                        result.replaceSubrange(attrRange, with: styled)
                    }
                }
            }
        }

        return result
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "yellow": return .yellow
        case "purple": return .purple
        case "pink": return .pink
        case "cyan": return .cyan
        case "teal": return .teal
        case "indigo": return .indigo
        case "mint": return .mint
        case "brown": return .brown
        case "gray", "grey": return .gray
        case "black": return .black
        case "white": return .white
        default: return theme.text
        }
    }

    // MARK: - Font Size Formatting {size:number}text{/size}
    
    /// Extracts size value from text containing {size:XX} tags
    private func extractSizeFromText(_ text: String) -> CGFloat? {
        let pattern = #"\{size:(\d+)\}"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let sizeRange = Range(match.range(at: 1), in: text) {
            if let sizeValue = Int(String(text[sizeRange])) {
                return CGFloat(sizeValue)
            }
        }
        return nil
    }

    private func applyFontSize(_ attributed: AttributedString, originalText: String, depth: Int = 0) -> AttributedString {
        var result = attributed

        let pattern = #"\{size:(\d+)\}(.+?)\{/size\}"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: originalText, range: NSRange(originalText.startIndex..., in: originalText))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: originalText),
                   let sizeRange = Range(match.range(at: 1), in: originalText),
                   let textRange = Range(match.range(at: 2), in: originalText) {
                    let fullText = String(originalText[fullRange])
                    let sizeValue = CGFloat(Int(String(originalText[sizeRange])) ?? Int(fontSize))
                    let matchedText = String(originalText[textRange])
                    
                    // Recursively parse the inner content to handle nested formatting
                    let innerParsed = parseInlineElements(matchedText, depth: depth + 1)

                    // Find the position in the result string
                    // The innerParsed already has all formatting applied from recursive parsing
                    // We need to scale the font size while preserving weight/style
                    // Check the original matchedText to detect what formatting was applied
                    let isBold = matchedText.contains("**") || matchedText.contains("__")
                    let isItalic = (matchedText.contains("*") && !matchedText.contains("**")) ||
                                  (matchedText.contains("_") && !matchedText.contains("__"))
                    
                    if let attrRange = result.range(of: fullText) {
                        var styled = innerParsed
                        // Apply size to all runs while preserving weight/style
                        for run in styled.runs {
                            // Apply size with preserved weight/style based on original text markers
                            if isBold && isItalic {
                                styled[run.range].font = .system(size: sizeValue, weight: .bold).italic()
                            } else if isBold {
                                styled[run.range].font = .system(size: sizeValue, weight: .bold)
                            } else if isItalic {
                                styled[run.range].font = .system(size: sizeValue).italic()
                            } else {
                                styled[run.range].font = .system(size: sizeValue)
                            }
                        }
                        result.replaceSubrange(attrRange, with: styled)
                    } else if let attrRange = result.range(of: matchedText) {
                        var styled = innerParsed
                        for run in styled.runs {
                            if isBold && isItalic {
                                styled[run.range].font = .system(size: sizeValue, weight: .bold).italic()
                            } else if isBold {
                                styled[run.range].font = .system(size: sizeValue, weight: .bold)
                            } else if isItalic {
                                styled[run.range].font = .system(size: sizeValue).italic()
                            } else {
                                styled[run.range].font = .system(size: sizeValue)
                            }
                        }
                        result.replaceSubrange(attrRange, with: styled)
                    }
                }
            }
        }

        return result
    }

    // MARK: - Highlight Formatting ==text==

    private func applyHighlight(_ attributed: AttributedString, originalText: String) -> AttributedString {
        var result = attributed

        let pattern = #"==(.+?)=="#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: originalText, range: NSRange(originalText.startIndex..., in: originalText))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: originalText),
                   let textRange = Range(match.range(at: 1), in: originalText) {
                    let fullText = String(originalText[fullRange])
                    let matchedText = String(originalText[textRange])

                    if let attrRange = result.range(of: fullText) {
                        var styled = AttributedString(matchedText)
                        styled.font = .system(size: fontSize)
                        styled.foregroundColor = .black
                        styled.backgroundColor = .yellow.opacity(0.5)
                        result.replaceSubrange(attrRange, with: styled)
                    }
                }
            }
        }

        return result
    }

    private func applyBoldItalic(_ attributed: AttributedString, originalText: String, depth: Int = 0) -> AttributedString {
        var result = attributed

        // Bold + Italic (***text*** or ___text___)
        let boldItalicPatterns = [#"\*\*\*(.+?)\*\*\*"#, #"___(.+?)___"#]
        for pattern in boldItalicPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: originalText, range: NSRange(originalText.startIndex..., in: originalText))
                for match in matches.reversed() {
                    if let fullRange = Range(match.range, in: originalText),
                       let textRange = Range(match.range(at: 1), in: originalText) {
                        let fullText = String(originalText[fullRange])
                        let matchedText = String(originalText[textRange])
                        
                        // Recursively parse the inner content
                        let innerParsed = parseInlineElements(matchedText, depth: depth + 1)
                        
                        // Extract size from matchedText if present
                        let extractedSize = extractSizeFromText(matchedText) ?? fontSize
                        
                        var styled = innerParsed
                        // Apply bold+italic to all runs, preserving size from recursive parsing
                        for run in styled.runs {
                            // Apply bold+italic - preserve size from inner parsing or extracted size
                            styled[run.range].font = .system(size: extractedSize, weight: .bold).italic()
                        }
                        
                        if let attrRange = result.range(of: fullText) {
                            result.replaceSubrange(attrRange, with: styled)
                        } else if let attrRange = result.range(of: matchedText) {
                            result.replaceSubrange(attrRange, with: styled)
                        }
                    }
                }
            }
        }

        // Bold (**text** or __text__)
        let boldPatterns = [#"\*\*(.+?)\*\*"#, #"__(.+?)__"#]
        for pattern in boldPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: originalText, range: NSRange(originalText.startIndex..., in: originalText))
                for match in matches.reversed() {
                    if let fullRange = Range(match.range, in: originalText),
                       let textRange = Range(match.range(at: 1), in: originalText) {
                        let fullText = String(originalText[fullRange])
                        let matchedText = String(originalText[textRange])
                        if fullText.hasPrefix("***") || fullText.hasPrefix("___") { continue }
                        
                        // Recursively parse the inner content to handle nested formatting tags
                        let innerParsed = parseInlineElements(matchedText, depth: depth + 1)
                        
                        // Extract size from matchedText if present
                        let extractedSize = extractSizeFromText(matchedText) ?? fontSize
                        
                        // Apply bold to the parsed content
                        var styled = innerParsed
                        // Apply bold to all runs - preserve size from inner parsing or extracted size
                        for run in styled.runs {
                            styled[run.range].font = .system(size: extractedSize, weight: .bold)
                        }
                        
                        // Try to find and replace the full text, or just the inner text if full text not found
                        if let attrRange = result.range(of: fullText) {
                            result.replaceSubrange(attrRange, with: styled)
                        } else if let attrRange = result.range(of: matchedText) {
                            result.replaceSubrange(attrRange, with: styled)
                        }
                    }
                }
            }
        }

        // Italic (*text* or _text_)
        // Must ensure we don't match when there are double asterisks/underscores
        let italicPatterns = [#"\*([^*]+?)\*"#, #"_([^_]+?)_"#]
        for (patternIndex, pattern) in italicPatterns.enumerated() {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: originalText, range: NSRange(originalText.startIndex..., in: originalText))
                for match in matches.reversed() {
                    if let fullRange = Range(match.range, in: originalText),
                       let textRange = Range(match.range(at: 1), in: originalText) {
                        let fullText = String(originalText[fullRange])
                        let matchedText = String(originalText[textRange])
                        
                        // Check if this is part of a bold pattern by checking surrounding characters
                        let matchStart = match.range.location
                        let matchEnd = matchStart + match.range.length
                        
                        // Check character before match (if exists)
                        let charBefore: Character?
                        if matchStart > 0 {
                            let beforeIndex = originalText.index(originalText.startIndex, offsetBy: matchStart - 1)
                            charBefore = originalText[beforeIndex]
                        } else {
                            charBefore = nil
                        }
                        
                        // Check character after match (if exists)
                        let charAfter: Character?
                        if matchEnd < originalText.count {
                            let afterIndex = originalText.index(originalText.startIndex, offsetBy: matchEnd)
                            charAfter = originalText[afterIndex]
                        } else {
                            charAfter = nil
                        }
                        
                        // Determine the marker character for this pattern
                        let marker: Character = patternIndex == 0 ? "*" : "_"
                        
                        // Skip if this is part of a bold pattern
                        // For asterisk italic (*text*): skip if immediately preceded or followed by *
                        // For underscore italic (_text_): skip if immediately preceded or followed by _
                        // This prevents matching *text* from within **text**
                        if (marker == "*" && (charBefore == "*" || charAfter == "*")) ||
                           (marker == "_" && (charBefore == "_" || charAfter == "_")) {
                            continue
                        }
                        
                        // Also check if full text starts/ends with double markers
                        let doubleMarker = String(repeating: marker, count: 2)
                        if fullText.hasPrefix(doubleMarker) || fullText.hasSuffix(doubleMarker) {
                            continue
                        }
                        
                        // Recursively parse the inner content
                        let innerParsed = parseInlineElements(matchedText, depth: depth + 1)
                        
                        // Extract size from matchedText if present
                        let extractedSize = extractSizeFromText(matchedText) ?? fontSize
                        
                        var styled = innerParsed
                        // Apply italic to all runs - preserve size from inner parsing or extracted size
                        for run in styled.runs {
                            styled[run.range].font = .system(size: extractedSize).italic()
                        }
                        
                        if let attrRange = result.range(of: fullText) {
                            result.replaceSubrange(attrRange, with: styled)
                        } else if let attrRange = result.range(of: matchedText) {
                            result.replaceSubrange(attrRange, with: styled)
                        }
                    }
                }
            }
        }

        return result
    }

    private func applyCode(_ attributed: AttributedString, originalText: String) -> AttributedString {
        var result = attributed

        let pattern = #"`([^`]+)`"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: originalText, range: NSRange(originalText.startIndex..., in: originalText))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: originalText),
                   let textRange = Range(match.range(at: 1), in: originalText) {
                    let fullText = String(originalText[fullRange])
                    let matchedText = String(originalText[textRange])
                    if let attrRange = result.range(of: fullText) {
                        var styled = AttributedString(" \(matchedText) ")
                        styled.font = .system(size: fontSize * 0.9, design: .monospaced)
                        styled.foregroundColor = theme.code
                        styled.backgroundColor = theme.codeBackground
                        result.replaceSubrange(attrRange, with: styled)
                    }
                }
            }
        }

        return result
    }

    private func applyLinks(_ attributed: AttributedString, originalText: String) -> AttributedString {
        var result = attributed

        let pattern = #"\[([^\]]+)\]\(([^)]+)\)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: originalText, range: NSRange(originalText.startIndex..., in: originalText))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: originalText),
                   let textRange = Range(match.range(at: 1), in: originalText),
                   let urlRange = Range(match.range(at: 2), in: originalText) {
                    let fullText = String(originalText[fullRange])
                    let linkText = String(originalText[textRange])
                    let urlString = String(originalText[urlRange])
                    if let attrRange = result.range(of: fullText) {
                        var styled = AttributedString(linkText)
                        styled.font = .system(size: fontSize)
                        styled.foregroundColor = theme.link
                        styled.underlineStyle = .single
                        if let url = URL(string: urlString) {
                            styled.link = url
                        }
                        result.replaceSubrange(attrRange, with: styled)
                    }
                }
            }
        }

        // Auto-link URLs
        let urlPattern = #"https?://[^\s<>\"{}|\\^`\[\]]+"#
        if let regex = try? NSRegularExpression(pattern: urlPattern) {
            let matches = regex.matches(in: originalText, range: NSRange(originalText.startIndex..., in: originalText))
            for match in matches.reversed() {
                if let range = Range(match.range, in: originalText) {
                    let urlString = String(originalText[range])
                    if let attrRange = result.range(of: urlString) {
                        var styled = AttributedString(urlString)
                        styled.font = .system(size: fontSize)
                        styled.foregroundColor = theme.link
                        styled.underlineStyle = .single
                        if let url = URL(string: urlString) {
                            styled.link = url
                        }
                        result.replaceSubrange(attrRange, with: styled)
                    }
                }
            }
        }

        return result
    }

    private func applyStrikethrough(_ attributed: AttributedString, originalText: String) -> AttributedString {
        var result = attributed

        let pattern = #"~~(.+?)~~"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: originalText, range: NSRange(originalText.startIndex..., in: originalText))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: originalText),
                   let textRange = Range(match.range(at: 1), in: originalText) {
                    let fullText = String(originalText[fullRange])
                    let matchedText = String(originalText[textRange])
                    if let attrRange = result.range(of: fullText) {
                        var styled = AttributedString(matchedText)
                        styled.font = .system(size: fontSize)
                        styled.foregroundColor = theme.text.opacity(0.6)
                        styled.strikethroughStyle = .single
                        result.replaceSubrange(attrRange, with: styled)
                    }
                }
            }
        }

        return result
    }

    private func applyUnderline(_ attributed: AttributedString, originalText: String) -> AttributedString {
        var result = attributed

        // Support <u>text</u> syntax for underline
        let pattern = #"<u>(.+?)</u>"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: originalText, range: NSRange(originalText.startIndex..., in: originalText))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: originalText),
                   let textRange = Range(match.range(at: 1), in: originalText) {
                    let fullText = String(originalText[fullRange])
                    let matchedText = String(originalText[textRange])
                    if let attrRange = result.range(of: fullText) {
                        var styled = AttributedString(matchedText)
                        styled.font = .system(size: fontSize)
                        styled.foregroundColor = theme.text
                        styled.underlineStyle = .single
                        result.replaceSubrange(attrRange, with: styled)
                    }
                }
            }
        }

        return result
    }
}

// MARK: - Markdown Block Types

enum MarkdownBlock: Identifiable {
    case paragraph(AttributedString, alignment: ParagraphAlignment = .left)
    case heading(level: Int, content: AttributedString)
    case codeBlock(code: String, language: String)
    case blockquote(AttributedString)
    case listItem(indent: Int, style: ListStyle, content: AttributedString)
    case horizontalRule
    case image(url: String, alt: String, width: CGFloat?, height: CGFloat?)
    case toggleHeading(level: Int, title: AttributedString, content: [MarkdownBlock])
    case columns(columnContents: [[MarkdownBlock]])
    case table(headers: [String], rows: [[String]], alignments: [TableAlignment], headerRows: Set<Int> = [0], headerColumns: Set<Int> = [0])

    var id: String {
        switch self {
        case .paragraph(let content, _): return "p-\(content.hashValue)"
        case .heading(let level, let content): return "h\(level)-\(content.hashValue)"
        case .codeBlock(let code, _): return "code-\(code.hashValue)"
        case .blockquote(let content): return "quote-\(content.hashValue)"
        case .listItem(_, _, let content): return "li-\(content.hashValue)"
        case .horizontalRule: return "hr-\(UUID().uuidString)"
        case .image(let url, _, _, _): return "img-\(url.hashValue)"
        case .toggleHeading(let level, let title, _): return "toggle-\(level)-\(title.hashValue)"
        case .columns(let cols): return "cols-\(cols.count)"
        case .table(let headers, _, _, _, _): return "table-\(headers.joined().hashValue)"
        }
    }

    enum ListStyle {
        case bullet
        case numbered(Int)
        case checkbox(checked: Bool)
    }

    enum TableAlignment {
        case left
        case center
        case right
        case none
    }

    enum ParagraphAlignment {
        case left
        case center
        case right
    }
}

