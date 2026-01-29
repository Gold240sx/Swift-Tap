import SwiftUI
import SDWebImageSwiftUI
import SDWebImageSVGCoder
#if os(macOS)
import AppKit
#endif

/// A rich markdown preview that renders code blocks with full-width backgrounds and syntax highlighting
struct RichMarkdownPreview: View {
    let content: String
    let theme: EditorTheme
    let fontSize: CGFloat
    let lineHeight: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    private var parser: MarkdownParser {
        MarkdownParser(theme: theme, fontSize: fontSize, lineHeight: lineHeight)
    }

    private var blocks: [MarkdownBlock] {
        parser.parseToBlocks(content)
    }

    private var syntaxTheme: SyntaxTheme {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: fontSize * 0.75) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(for: block)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background)
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
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
            .padding(.vertical, 4)

        case .listItem(let indent, let style, let content):
            HStack(alignment: .top, spacing: 8) {
                Text(listMarker(for: style))
                    .font(.system(size: fontSize))
                    .foregroundColor(markerColor(for: style))
                    .frame(width: 20, alignment: .trailing)

                Text(content)
                    .textSelection(.enabled)
                    .strikethrough(isChecked(style), color: theme.text.opacity(0.5))
                    .foregroundColor(isChecked(style) ? theme.text.opacity(0.5) : theme.text)
            }
            .padding(.leading, CGFloat(indent) * 20)

        case .horizontalRule:
            Rectangle()
                .fill(theme.text.opacity(0.2))
                .frame(height: 1)
                .padding(.vertical, fontSize * 0.5)

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
        case .bullet:
            return "•"
        case .numbered(let n):
            return "\(n)."
        case .checkbox(let checked):
            return checked ? "☑" : "☐"
        }
    }

    private func markerColor(for style: MarkdownBlock.ListStyle) -> Color {
        switch style {
        case .checkbox(let checked):
            return checked ? theme.link : theme.text.opacity(0.6)
        default:
            return theme.text.opacity(0.6)
        }
    }

    private func isChecked(_ style: MarkdownBlock.ListStyle) -> Bool {
        if case .checkbox(let checked) = style {
            return checked
        }
        return false
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

// MARK: - Code Block View with Syntax Highlighting

struct CodeBlockView: View {
    let code: String
    let language: String
    let syntaxTheme: SyntaxTheme
    let fontSize: CGFloat

    @State private var copied = false

    private var highlighter: SyntaxHighlighter {
        SyntaxHighlighter(theme: syntaxTheme, fontSize: fontSize * 0.9)
    }

    private var detectedLanguage: Language {
        Language(alias: language) ?? .plainText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with language and copy button
            HStack {
                // Language badge
                if !language.isEmpty || detectedLanguage != .plainText {
                    Text(detectedLanguage.displayName)
                        .font(.system(size: fontSize * 0.7, weight: .medium, design: .monospaced))
                        .foregroundColor(syntaxTheme.text.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(syntaxTheme.text.opacity(0.1))
                        .cornerRadius(4)
                }

                Spacer()

                // Copy button
                Button(action: copyCode) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: fontSize * 0.7))
                        if copied {
                            Text("Copied!")
                                .font(.system(size: fontSize * 0.7))
                        }
                    }
                    .foregroundColor(copied ? .green : syntaxTheme.text.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(syntaxTheme.text.opacity(0.05))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(syntaxTheme.background.opacity(0.5))

            // Separator line
            Rectangle()
                .fill(syntaxTheme.text.opacity(0.1))
                .frame(height: 1)

            // Code content with syntax highlighting
            ScrollView(.horizontal, showsIndicators: true) {
                Text(highlighter.highlight(code, language: language))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(syntaxTheme.background)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(syntaxTheme.text.opacity(0.15), lineWidth: 1)
        )
    }

    private func copyCode() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #else
        UIPasteboard.general.string = code
        #endif

        withAnimation {
            copied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copied = false
            }
        }
    }
}

// MARK: - Image Block View with SDWebImage

struct ImageBlockView: View {
    let url: String
    let alt: String
    let width: CGFloat?
    let height: CGFloat?
    let theme: EditorTheme
    let fontSize: CGFloat

    @State private var isLoading = true
    @State private var loadFailed = false

    private var imageURL: URL? {
        URL(string: url)
    }

    private var isSVG: Bool {
        url.lowercased().hasSuffix(".svg")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let imageURL = imageURL {
                imageContent(url: imageURL)
            } else {
                errorView(message: "Invalid URL")
            }

            // Alt text caption
            if !alt.isEmpty {
                Text(alt)
                    .font(.system(size: fontSize * 0.85))
                    .foregroundColor(theme.text.opacity(0.6))
                    .italic()
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func imageContent(url: URL) -> some View {
        WebImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            loadingPlaceholder
        }
        .onSuccess { _, _, _ in
            Task { @MainActor in
                isLoading = false
                loadFailed = false
            }
        }
        .onFailure { _ in
            Task { @MainActor in
                isLoading = false
                loadFailed = true
            }
        }
        .indicator(.activity)
        .transition(.fade(duration: 0.3))
        .frame(
            width: width,
            height: height
        )
        .frame(maxWidth: width ?? .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.text.opacity(0.1), lineWidth: 1)
        )
        .overlay {
            if loadFailed {
                errorView(message: "Failed to load image")
            }
        }
    }

    private var loadingPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(theme.text.opacity(0.05))
            .frame(width: width ?? 200, height: height ?? 150)
            .overlay {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading...")
                        .font(.system(size: fontSize * 0.8))
                        .foregroundColor(theme.text.opacity(0.5))
                }
            }
    }

    private func errorView(message: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.red.opacity(0.1))
            .frame(width: width ?? 200, height: height ?? 100)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: fontSize * 1.5))
                        .foregroundColor(.red.opacity(0.7))
                    Text(message)
                        .font(.system(size: fontSize * 0.8))
                        .foregroundColor(.red.opacity(0.7))
                    Text(url)
                        .font(.system(size: fontSize * 0.7, design: .monospaced))
                        .foregroundColor(theme.text.opacity(0.5))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding()
            }
    }
}

// MARK: - Toggle Heading View (Collapsible Section)

struct ToggleHeadingView: View {
    let level: Int
    let title: AttributedString
    let content: [MarkdownBlock]
    let theme: EditorTheme
    let fontSize: CGFloat
    let syntaxTheme: SyntaxTheme

    @State private var isExpanded = true

    private var headingSize: CGFloat {
        switch level {
        case 1: return 48
        case 2: return 36
        case 3: return 28
        case 4: return fontSize * 1.25
        case 5: return fontSize * 1.1
        default: return fontSize
        }
    }
    
    private var chevronSize: CGFloat {
        36 * 0.5 // Fixed size based on level 2 (36pt)
    }
    
    private func styledTitle() -> AttributedString {
        var result = title
        result.font = .system(size: headingSize, weight: .bold)
        result.foregroundColor = theme.heading
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toggle header
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.2)) { 
                    isExpanded.toggle() 
                } 
            }) {
                HStack(spacing: 8) {
                    Text(styledTitle())
                        .textSelection(.enabled)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: chevronSize, weight: .semibold))
                        .foregroundColor(theme.heading.opacity(0.7))
                        .frame(width: 36 * 0.6)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Collapsible content
            if isExpanded {
                VStack(alignment: .leading, spacing: fontSize * 0.5) {
                    ForEach(Array(content.enumerated()), id: \.offset) { _, block in
                        ToggleContentBlockView(
                            block: block,
                            theme: theme,
                            fontSize: fontSize,
                            syntaxTheme: syntaxTheme
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(theme.text.opacity(0.03))
        .cornerRadius(8)
    }
}

// Helper view for rendering blocks inside toggle
struct ToggleContentBlockView: View {
    let block: MarkdownBlock
    let theme: EditorTheme
    let fontSize: CGFloat
    let syntaxTheme: SyntaxTheme

    var body: some View {
        switch block {
        case .paragraph(let content, let alignment):
            Text(content)
                .multilineTextAlignment(textAlignment(for: alignment))
                .frame(maxWidth: .infinity, alignment: frameAlignment(for: alignment))
                .textSelection(.enabled)
        case .heading(let level, let content):
            Text(content)
                .font(.system(size: headingSize(for: level), weight: .bold))
                .foregroundColor(theme.heading)
                .textSelection(.enabled)
        case .codeBlock(let code, let language):
            CodeBlockView(code: code, language: language, syntaxTheme: syntaxTheme, fontSize: fontSize)
        case .blockquote(let content):
            HStack(alignment: .top, spacing: 8) {
                Rectangle().fill(theme.blockquote.opacity(0.5)).frame(width: 3)
                Text(content).font(.system(size: fontSize).italic()).foregroundColor(theme.blockquote).textSelection(.enabled)
            }
        case .listItem(let indent, let style, let content):
            HStack(alignment: .top, spacing: 8) {
                Text(listMarker(for: style)).font(.system(size: fontSize)).foregroundColor(theme.text.opacity(0.6)).frame(width: 20, alignment: .trailing)
                Text(content).textSelection(.enabled)
            }
            .padding(.leading, CGFloat(indent) * 20)
        case .horizontalRule:
            Rectangle().fill(theme.text.opacity(0.2)).frame(height: 1)
        case .image(let url, let alt, let width, let height):
            ImageBlockView(url: url, alt: alt, width: width, height: height, theme: theme, fontSize: fontSize)
        case .toggleHeading(let level, let title, let innerContent):
            ToggleHeadingView(level: level, title: title, content: innerContent, theme: theme, fontSize: fontSize, syntaxTheme: syntaxTheme)
        case .columns(let cols):
            ColumnsView(columns: cols, theme: theme, fontSize: fontSize, syntaxTheme: syntaxTheme)
        case .table(let headers, let rows, let alignments, let headerRows, let headerColumns):
            TableView(headers: headers, rows: rows, alignments: alignments, headerRows: headerRows, headerColumns: headerColumns, theme: theme, fontSize: fontSize)
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

    private func listMarker(for style: MarkdownBlock.ListStyle) -> String {
        switch style {
        case .bullet: return "•"
        case .numbered(let n): return "\(n)."
        case .checkbox(let checked): return checked ? "☑" : "☐"
        }
    }
}

// MARK: - Columns View (Multi-column Layout)

struct ColumnsView: View {
    let columns: [[MarkdownBlock]]
    let theme: EditorTheme
    let fontSize: CGFloat
    let syntaxTheme: SyntaxTheme

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, columnBlocks in
                VStack(alignment: .leading, spacing: fontSize * 0.5) {
                    ForEach(Array(columnBlocks.enumerated()), id: \.offset) { _, block in
                        ToggleContentBlockView(
                            block: block,
                            theme: theme,
                            fontSize: fontSize,
                            syntaxTheme: syntaxTheme
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Add divider between columns (except for the last one)
                if index < columns.count - 1 {
                    Rectangle()
                        .fill(theme.text.opacity(0.1))
                        .frame(width: 1)
                }
            }
        }
        .padding()
        .background(theme.text.opacity(0.02))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.text.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Table Row Model

struct TableRow: Identifiable {
    let id = UUID()
    let values: [String]
}

// MARK: - Sticky Table View

struct StickyTableView: View {
    let columns: [String]
    let rows: [TableRow]
    let theme: EditorTheme
    let fontSize: CGFloat

    let defaultRowHeight: CGFloat = 36
    let cornerRadius: CGFloat = 12

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(alignment: .top, spacing: 0) {
                    ForEach(columns.indices, id: \.self) { colIndex in
                        cell(
                            text: columns[colIndex],
                            isHeader: true,
                            isAlt: false
                        )
                    }
                }
                
                // Data rows
                ForEach(rows.indices, id: \.self) { row in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(rows[row].values.indices, id: \.self) { col in
                            cell(
                                text: rows[row].values[col],
                                isHeader: false,
                                isAlt: row % 2 == 1
                            )
                        }
                    }
                        }
                    }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(theme.text.opacity(0.3), lineWidth: 1)
            )
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity)
        .frame(height: min(400, CGFloat(rows.count + 1) * defaultRowHeight))
    }

    // ─────────── Cell ───────────
    func cell(text: String, isHeader: Bool, isAlt: Bool) -> some View {
        HStack(spacing: 0) {
            Text(text)
                .font(isHeader ? .headline : .system(.body, design: .monospaced))
                .foregroundColor(isHeader ? theme.heading : theme.text)
                .lineLimit(1)
                .padding(.horizontal, 4)
        }
        .frame(width: 120, height: defaultRowHeight)
        .background(background(isHeader, isAlt))
        .overlay(Rectangle().stroke(theme.text.opacity(0.15)))
    }

    func background(_ isHeader: Bool, _ isAlt: Bool) -> Color {
        if isHeader {
            return theme.text.opacity(0.1)
        }
        return isAlt ? theme.text.opacity(0.06) : Color.clear
    }
}

// MARK: - Table View

struct TableView: View {
    let headers: [String]
    let rows: [[String]]
    let alignments: [MarkdownBlock.TableAlignment]
    let headerRows: Set<Int>
    let headerColumns: Set<Int>
    let theme: EditorTheme
    let fontSize: CGFloat

    private var tableRows: [TableRow] {
        rows.map { TableRow(values: $0) }
    }

    var body: some View {
        StickyTableView(
            columns: headers,
            rows: tableRows,
            theme: theme,
            fontSize: fontSize
        )
        .padding(.vertical, 12)
    }
}

extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(EdgeBorder(width: width, edges: edges).foregroundColor(color))
    }
}

struct EdgeBorder: Shape {
    var width: CGFloat
    var edges: [Edge]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            var x: CGFloat {
                switch edge {
                case .top, .bottom, .leading: return rect.minX
                case .trailing: return rect.maxX - width
                }
            }

            var y: CGFloat {
                switch edge {
                case .top, .leading, .trailing: return rect.minY
                case .bottom: return rect.maxY - width
                }
            }

            var w: CGFloat {
                switch edge {
                case .top, .bottom: return rect.width
                case .leading, .trailing: return width
                }
            }

            var h: CGFloat {
                switch edge {
                case .top, .bottom: return width
                case .leading, .trailing: return rect.height
                }
            }
            path.addRect(CGRect(x: x, y: y, width: w, height: h))
        }
        return path
    }
}

// MARK: - SVG Coder Registration

enum SDWebImageSetup {
    static var isConfigured = false

    static func configure() {
        guard !isConfigured else { return }
        SDImageCodersManager.shared.addCoder(SDImageSVGCoder.shared)
        isConfigured = true
    }
}

// MARK: - Syntax Theme Picker

struct SyntaxThemePicker: View {
    @Binding var selectedTheme: SyntaxTheme
    @Environment(\.colorScheme) private var colorScheme

    private var availableThemes: [SyntaxTheme] {
        colorScheme == .dark ? SyntaxTheme.darkThemes : SyntaxTheme.lightThemes
    }

    var body: some View {
        Menu {
            ForEach(availableThemes, id: \.name) { theme in
                Button(action: { selectedTheme = theme }) {
                    HStack {
                        Text(theme.name)
                        if theme.name == selectedTheme.name {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "paintbrush")
                Text(selectedTheme.name)
            }
            .font(.caption)
        }
    }
}

// MARK: - Language Picker for Code Blocks

struct LanguagePicker: View {
    @Binding var selectedLanguage: String
    let onSelect: (String) -> Void

    private let popularLanguages: [Language] = [
        .swift, .python, .javascript, .typescript, .java, .kotlin,
        .go, .rust, .c, .cpp, .ruby, .php, .sql, .bash, .html, .css, .json, .yaml
    ]

    var body: some View {
        Menu {
            Section("Popular") {
                ForEach(popularLanguages, id: \.rawValue) { lang in
                    Button(action: { selectLanguage(lang) }) {
                        HStack {
                            Text(lang.displayName)
                            if selectedLanguage.lowercased() == lang.rawValue {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Section("All Languages") {
                ForEach(Language.allCases.filter { !popularLanguages.contains($0) }, id: \.rawValue) { lang in
                    Button(action: { selectLanguage(lang) }) {
                        Text(lang.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                Text(displayLanguage)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.1))
            .cornerRadius(4)
        }
    }

    private var displayLanguage: String {
        if selectedLanguage.isEmpty {
            return "Language"
        }
        return Language(alias: selectedLanguage)?.displayName ?? selectedLanguage
    }

    private func selectLanguage(_ lang: Language) {
        selectedLanguage = lang.rawValue
        onSelect(lang.rawValue)
    }
}

// MARK: - Preview

#Preview("Light Theme") {
    let sampleContent = """
    # Syntax Highlighting Demo

    Here's some Swift code:

    ```swift
    import SwiftUI

    struct ContentView: View {
        @State private var count = 0

        var body: some View {
            VStack {
                Text("Count: \\(count)")
                    .font(.largeTitle)

                Button("Increment") {
                    count += 1
                }
            }
        }
    }
    ```

    And some Python:

    ```python
    def fibonacci(n):
        \"\"\"Calculate fibonacci sequence\"\"\"
        if n <= 1:
            return n
        return fibonacci(n-1) + fibonacci(n-2)

    # Print first 10 numbers
    for i in range(10):
        print(f"fib({i}) = {fibonacci(i)}")
    ```

    JavaScript example:

    ```javascript
    const fetchData = async (url) => {
        try {
            const response = await fetch(url);
            const data = await response.json();
            console.log('Data:', data);
            return data;
        } catch (error) {
            console.error('Error:', error);
        }
    };
    ```

    SQL query:

    ```sql
    SELECT users.name, COUNT(orders.id) as order_count
    FROM users
    LEFT JOIN orders ON users.id = orders.user_id
    WHERE users.created_at > '2024-01-01'
    GROUP BY users.id
    HAVING order_count > 5
    ORDER BY order_count DESC;
    ```
    """

    RichMarkdownPreview(
        content: sampleContent,
        theme: .light,
        fontSize: 14,
        lineHeight: 1.5
    )
    .frame(width: 700, height: 900)
}

#Preview("Dark Theme") {
    let sampleContent = """
    # Dark Mode Syntax Highlighting

    ```rust
    use std::collections::HashMap;

    fn main() {
        let mut scores: HashMap<String, i32> = HashMap::new();

        scores.insert(String::from("Blue"), 10);
        scores.insert(String::from("Red"), 50);

        for (key, value) in &scores {
            println!("{}: {}", key, value);
        }
    }
    ```

    ```go
    package main

    import (
        "fmt"
        "net/http"
    )

    func handler(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "Hello, World!")
    }

    func main() {
        http.HandleFunc("/", handler)
        http.ListenAndServe(":8080", nil)
    }
    ```
    """

    RichMarkdownPreview(
        content: sampleContent,
        theme: .dark,
        fontSize: 14,
        lineHeight: 1.5
    )
    .frame(width: 700, height: 600)
    .preferredColorScheme(.dark)
}
