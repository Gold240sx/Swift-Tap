import SwiftUI
import SwiftData
import Foundation

/// A reusable markdown editor component with source editing and rich preview
struct MarkdownEditor: View {
    @Binding var content: String
    @Binding var editorMode: EditorMode

    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @State private var scrollPosition: CGFloat = 0
    @StateObject private var undoManager = ContentUndoManager()
    @State private var lastContent: String = ""
    @State private var isUndoRedoOperation: Bool = false

    let theme: String
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let showToolbar: Bool
    let showWordCount: Bool
    let placeholder: String
    let onSave: (() -> Void)?

    init(
        content: Binding<String>,
        editorMode: Binding<EditorMode> = .constant(.split),
        theme: String = "system",
        fontSize: CGFloat = 16,
        lineHeight: CGFloat = 1.5,
        showToolbar: Bool = true,
        showWordCount: Bool = true,
        placeholder: String = "Start writing...",
        onSave: (() -> Void)? = nil
    ) {
        self._content = content
        self._editorMode = editorMode
        self.theme = theme
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.showToolbar = showToolbar
        self.showWordCount = showWordCount
        self.placeholder = placeholder
        self.onSave = onSave
    }

    private var currentTheme: EditorTheme {
        EditorTheme.theme(for: theme, colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showToolbar {
                EditorToolbar(
                    content: $content,
                    editorMode: $editorMode,
                    selectedRange: $selectedRange,
                    undoManager: undoManager,
                    onUndo: {
                        isUndoRedoOperation = true
                        if let previousContent = undoManager.undo() {
                            content = previousContent
                        }
                    },
                    onRedo: {
                        isUndoRedoOperation = true
                        if let nextContent = undoManager.redo() {
                            content = nextContent
                        }
                    },
                    onSave: onSave
                )
            }

            GeometryReader { geometry in
                editorContent(geometry: geometry)
            }

            if showWordCount {
                EditorStatusBar(content: content)
            }
        }
        .background(currentTheme.background)
        .onAppear {
            // Initialize undo manager with current content
            undoManager.updateCurrentContent(content)
            lastContent = content
        }
        .onChange(of: content) { oldValue, newValue in
            // Track content changes for undo (skip if from undo/redo operation)
            // Use Task to defer state modifications until after view update completes
            Task { @MainActor in
                if !isUndoRedoOperation && newValue != lastContent {
                    undoManager.recordState(oldValue)
                    lastContent = newValue
                } else if isUndoRedoOperation {
                    // Reset flag after undo/redo
                    isUndoRedoOperation = false
                    lastContent = newValue
                }
            }
        }
    }

    @ViewBuilder
    private func editorContent(geometry: GeometryProxy) -> some View {
        switch editorMode {
        case .source:
            sourceEditor
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .preview:
            previewPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .split:
            HStack(spacing: 0) {
                sourceEditor
                    .frame(width: geometry.size.width / 2)

                Divider()

                previewPane
                    .frame(width: geometry.size.width / 2)
            }
        }
    }

    private var sourceEditor: some View {
        SourceEditorView(
            content: $content,
            selectedRange: $selectedRange,
            theme: currentTheme,
            fontSize: fontSize,
            lineHeight: lineHeight,
            placeholder: placeholder
        )
    }

    private var previewPane: some View {
        RichMarkdownPreview(
            content: content,
            theme: currentTheme,
            fontSize: fontSize,
            lineHeight: lineHeight
        )
    }
}

// MARK: - Source Editor View

struct SourceEditorView: View {
    @Binding var content: String
    @Binding var selectedRange: NSRange

    let theme: EditorTheme
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if content.isEmpty {
                Text(placeholder)
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundColor(theme.text.opacity(0.4))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            // Selectable text editor
            #if os(macOS)
            SelectableTextEditor(
                text: $content,
                selectedRange: $selectedRange,
                font: .monospacedSystemFont(ofSize: fontSize, weight: .regular),
                textColor: NSColor(theme.text),
                backgroundColor: NSColor(theme.background),
                onTextChange: { newText in
                    ensureTrailingNewlineAfterList(newText)
                }
            )
            #else
            SelectableTextEditor(
                text: $content,
                selectedRange: $selectedRange,
                font: .monospacedSystemFont(ofSize: fontSize, weight: .regular),
                textColor: UIColor(theme.text),
                backgroundColor: UIColor(theme.background),
                onTextChange: { newText in
                    ensureTrailingNewlineAfterList(newText)
                }
            )
            #endif
        }
        .background(theme.background)
    }

    /// Ensures there's always a trailing newline when content ends with a list
    private func ensureTrailingNewlineAfterList(_ text: String) {
        // Only add trailing newline if content ends with a list item
        guard !text.isEmpty else { return }

        let lines = text.components(separatedBy: "\n")
        guard let lastLine = lines.last else { return }

        // Check if last line is a list item (and not empty)
        let trimmedLast = lastLine.trimmingCharacters(in: .whitespaces)
        if !trimmedLast.isEmpty {
            // Check if it matches a list pattern
            let listPatterns = [
                #"^[-*+]\s+\[[ xX]\]\s+.+"#,  // Checkbox with content
                #"^\d+\.\s+.+"#,               // Numbered list with content
                #"^[-*+]\s+.+"#,               // Bullet list with content
                #"^>\s*.+"#                    // Blockquote with content
            ]

            for pattern in listPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   regex.firstMatch(in: trimmedLast, range: NSRange(trimmedLast.startIndex..., in: trimmedLast)) != nil {
                    // Content ends with a list item - ensure there's a trailing newline for easy exit
                    if !text.hasSuffix("\n") {
                        // Don't auto-add newline here as it would interfere with typing
                        // The user can press Enter twice to exit the list
                    }
                    break
                }
            }
        }
    }

}

// MARK: - Editor Toolbar

struct EditorToolbar: View {
    @Binding var content: String
    @Binding var editorMode: EditorMode
    @Binding var selectedRange: NSRange
    @ObservedObject var undoManager: ContentUndoManager

    let onUndo: () -> Void
    let onRedo: () -> Void
    let onSave: (() -> Void)?

    @State private var showingColorPicker = false
    @State private var showingSizePicker = false
    @State private var selectedColor = "blue"
    @State private var selectedSize = 16
    @State private var showingImageInput = false
    @State private var imageURL = ""
    @State private var imageAlt = ""
    @State private var imageWidth = ""
    @State private var imageHeight = ""
    @State private var showingEmojiPicker = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // Undo/Redo
                Group {
                    Button(action: onUndo) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .help("Undo (⌘Z)")
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!undoManager.canUndo)
                    
                    Button(action: onRedo) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .help("Redo (⌘⇧Z)")
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!undoManager.canRedo)
                }
                
                ToolbarDivider()
                
                // Text formatting
                Group {
                    ToolbarButton(icon: "bold", tooltip: "Bold (⌘B)") {
                        applyWrap(prefix: "**", suffix: "**")
                    }

                    ToolbarButton(icon: "italic", tooltip: "Italic (⌘I)") {
                        applyWrap(prefix: "_", suffix: "_")
                    }

                    ToolbarButton(icon: "strikethrough", tooltip: "Strikethrough") {
                        applyWrap(prefix: "~~", suffix: "~~")
                    }

                    ToolbarButton(icon: "underline", tooltip: "Underline") {
                        applyWrap(prefix: "<u>", suffix: "</u>")
                    }

                    ToolbarButton(icon: "highlighter", tooltip: "Highlight") {
                        applyWrap(prefix: "==", suffix: "==")
                    }
                }

                ToolbarDivider()

                // Color picker
                ToolbarMenuButton(
                    icon: "paintpalette",
                    tooltip: "Text Color",
                    menu: {
                        ForEach(colorOptions, id: \.name) { option in
                            Button(action: { applyColor(option.name) }) {
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .foregroundColor(option.color)
                                    Text(option.name.capitalized)
                                }
                            }
                        }
                    }
                )

                // Font size picker
                ToolbarMenuButton(
                    icon: "textformat.size",
                    tooltip: "Font Size",
                    menu: {
                        ForEach(sizeOptions, id: \.self) { size in
                            Button(action: { applySize(size) }) {
                                Text("\(size)pt")
                            }
                        }
                    }
                )

                ToolbarDivider()

                // Structure
                Group {
                    ToolbarButton(icon: "text.badge.plus", tooltip: "Heading") {
                        insertAtLineStart("# ")
                    }

                    ToolbarButton(icon: "link", tooltip: "Link") {
                        applyWrap(prefix: "[", suffix: "](url)")
                    }

                    // Inline code (single backtick)
                    ToolbarButton(icon: "chevron.left.forwardslash.chevron.right", tooltip: "Inline Code") {
                        applyWrap(prefix: "`", suffix: "`")
                    }

                    // Code block (triple backticks) with language selection
                    ToolbarMenuButton(
                        icon: "text.and.command.macwindow",
                        tooltip: "Code Block",
                        menu: {
                            Section("Popular") {
                                ForEach(popularLanguages, id: \.rawValue) { lang in
                                    Button(action: { applyCodeBlock(language: lang.rawValue) }) {
                                        Label(lang.displayName, systemImage: "chevron.left.forwardslash.chevron.right")
                                    }
                                }
                            }
                            Section("All Languages") {
                                ForEach(Language.allCases.filter { !popularLanguages.contains($0) }, id: \.rawValue) { lang in
                                    Button(action: { applyCodeBlock(language: lang.rawValue) }) {
                                        Text(lang.displayName)
                                    }
                                }
                            }
                            Divider()
                            Button(action: { applyCodeBlock(language: "") }) {
                                Label("Plain Text", systemImage: "text.alignleft")
                            }
                        }
                    )

                    ToolbarButton(icon: "text.quote", tooltip: "Quote") {
                        insertAtLineStart("> ")
                    }

                    ToolbarButton(icon: "photo", tooltip: "Insert Image") {
                        showingImageInput = true
                    }

                    // Emoji picker
                    ToolbarButton(icon: "face.smiling", tooltip: "Insert Emoji") {
                        showingEmojiPicker = true
                    }
                    .popover(isPresented: $showingEmojiPicker, arrowEdge: .bottom) {
                        EmojiPickerView(onSelect: { emoji in
                            insertEmoji(emoji)
                            showingEmojiPicker = false
                        })
                    }

                    // Toggle heading
                    ToolbarMenuButton(
                        icon: "chevron.right.square",
                        tooltip: "Toggle Section",
                        menu: {
                            ForEach(1...3, id: \.self) { level in
                                Button(action: { insertToggleHeading(level: level) }) {
                                    Label("Toggle H\(level)", systemImage: "chevron.right")
                                }
                            }
                        }
                    )

                    // Columns
                    ToolbarMenuButton(
                        icon: "rectangle.split.2x1",
                        tooltip: "Columns Layout",
                        menu: {
                            Button(action: { insertColumns(count: 2) }) {
                                Label("2 Columns", systemImage: "rectangle.split.2x1")
                            }
                            Button(action: { insertColumns(count: 3) }) {
                                Label("3 Columns", systemImage: "rectangle.split.3x1")
                            }
                        }
                    )

                    // Table
                    ToolbarButton(icon: "tablecells", tooltip: "Insert Table") {
                        insertTable()
                    }
                }

                ToolbarDivider()

                // Paragraph alignment
                Group {
                    ToolbarButton(icon: "text.alignleft", tooltip: "Align Left") {
                        applyAlignment("left")
                    }

                    ToolbarButton(icon: "text.aligncenter", tooltip: "Align Center") {
                        applyAlignment("center")
                    }

                    ToolbarButton(icon: "text.alignright", tooltip: "Align Right") {
                        applyAlignment("right")
                    }
                }

                ToolbarDivider()

                // Lists
                Group {
                    ToolbarButton(icon: "list.bullet", tooltip: "Bullet List") {
                        insertAtLineStart("- ")
                    }

                    ToolbarButton(icon: "list.number", tooltip: "Numbered List") {
                        insertAtLineStart("1. ")
                    }

                    ToolbarButton(icon: "checklist", tooltip: "Checkbox") {
                        insertAtLineStart("- [ ] ")
                    }
                }

                Spacer()

                // View mode selector
                Picker("Mode", selection: $editorMode) {
                    ForEach(EditorMode.allCases, id: \.self) { mode in
                        Label(mode.displayName, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                if let onSave = onSave {
                    ToolbarDivider()

                    Button(action: onSave) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(white: 0.5).opacity(0.1))
        .sheet(isPresented: $showingImageInput) {
            ImageInsertSheet(
                imageURL: $imageURL,
                imageAlt: $imageAlt,
                imageWidth: $imageWidth,
                imageHeight: $imageHeight,
                onInsert: { url, alt, width, height in
                    insertImage(url: url, alt: alt, width: width, height: height)
                    showingImageInput = false
                    // Reset fields
                    imageURL = ""
                    imageAlt = ""
                    imageWidth = ""
                    imageHeight = ""
                },
                onCancel: {
                    showingImageInput = false
                    imageURL = ""
                    imageAlt = ""
                    imageWidth = ""
                    imageHeight = ""
                }
            )
        }
    }

    private var colorOptions: [(name: String, color: Color)] {
        [
            ("red", .red),
            ("orange", .orange),
            ("yellow", .yellow),
            ("green", .green),
            ("blue", .blue),
            ("purple", .purple),
            ("pink", .pink),
            ("cyan", .cyan),
            ("teal", .teal),
            ("gray", .gray)
        ]
    }

    private var sizeOptions: [Int] {
        [10, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 64]
    }

    private var popularLanguages: [Language] {
        [.swift, .python, .javascript, .typescript, .java, .kotlin,
         .go, .rust, .c, .cpp, .ruby, .php, .sql, .bash, .html, .css, .json, .yaml]
    }

    private var emojiCategories: [(name: String, emojis: [String])] {
        [
            ("Smileys", ["😀", "😃", "😄", "😁", "😅", "😂", "🤣", "😊", "😇", "🙂", "😉", "😍", "🥰", "😘", "😋", "😜", "🤔", "🤨", "😐", "😑", "😶", "🙄", "😏", "😣", "😥", "😮", "🤐", "😯", "😪", "😫", "🥱", "😴", "😌", "😛", "😝", "🤤", "😒", "😓", "😔", "😕", "🙃", "🤑", "😲", "🙁", "😖", "😞", "😟", "😤", "😢", "😭", "😦", "😧", "😨", "😩", "🤯", "😬", "😰", "😱"]),
            ("Gestures", ["👍", "👎", "👌", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "👇", "☝️", "✋", "🤚", "🖐️", "🖖", "👋", "🤝", "🙏", "✍️", "💪", "👏", "🙌", "👐", "🤲", "🤜", "🤛", "✊", "👊"]),
            ("Objects", ["💻", "🖥️", "📱", "📲", "💾", "💿", "📀", "🎮", "🕹️", "📷", "📸", "📹", "🎥", "📽️", "📺", "📻", "🎙️", "🎚️", "🎛️", "⏱️", "⏲️", "⏰", "🕰️", "📡", "🔋", "🔌", "💡", "🔦", "🕯️", "📚", "📖", "📝", "✏️", "🖊️", "🖋️", "✒️", "📁", "📂", "📅", "📆"]),
            ("Symbols", ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "⭐", "🌟", "✨", "💫", "🔥", "💥", "💢", "💦", "💨", "🎉", "🎊", "✅", "❌", "❓", "❗", "💯", "🔴", "🟠", "🟡", "🟢", "🔵", "🟣", "⚫", "⚪", "🟤"]),
            ("Nature", ["🌸", "🌺", "🌻", "🌼", "🌷", "🌹", "🥀", "🌾", "🌿", "☘️", "🍀", "🍁", "🍂", "🍃", "🌲", "🌳", "🌴", "🌵", "🌱", "🌊", "🌈", "☀️", "🌤️", "⛅", "🌥️", "☁️", "🌦️", "🌧️", "⛈️", "🌩️", "🌨️", "❄️", "☃️", "⛄", "🌬️", "💨", "🌪️", "🌫️", "🌀", "🌙", "⭐", "🌟"]),
            ("Food", ["🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥬", "🥒", "🌶️", "🫑", "🌽", "🥕", "🧄", "🧅", "🥔", "🍠", "🍕", "🍔", "🍟", "🌭", "🥪", "🌮", "🌯", "🥗", "🍜", "🍝"])
        ]
    }
    
    private var allEmojis: [String] {
        emojiCategories.flatMap { $0.emojis }
    }

    private func applyWrap(prefix: String, suffix: String) {
        selectedRange = TextFormatter.toggleWrap(
            in: &content,
            selectedRange: selectedRange,
            prefix: prefix,
            suffix: suffix
        )
    }

    private func insertAtLineStart(_ text: String) {
        selectedRange = TextFormatter.insertAtLineStart(
            in: &content,
            selectedRange: selectedRange,
            insertion: text
        )
    }

    private func applyColor(_ colorName: String) {
        selectedRange = TextFormatter.wrapSelection(
            in: &content,
            selectedRange: selectedRange,
            prefix: "{color:\(colorName)}",
            suffix: "{/color}"
        )
    }

    private func applySize(_ size: Int) {
        selectedRange = TextFormatter.wrapSelection(
            in: &content,
            selectedRange: selectedRange,
            prefix: "{size:\(size)}",
            suffix: "{/size}"
        )
    }

    private func applyCodeBlock(language: String = "") {
        let nsString = content as NSString
        let langSuffix = language.isEmpty ? "" : language

        // Check if we have a selection
        if selectedRange.length > 0 && selectedRange.location + selectedRange.length <= nsString.length {
            let selectedText = nsString.substring(with: selectedRange)
            let before = nsString.substring(to: selectedRange.location)
            let after = nsString.substring(from: selectedRange.location + selectedRange.length)

            // Wrap selection in code block with language
            content = before + "```\(langSuffix)\n" + selectedText + "\n```" + after
            let offset = 4 + langSuffix.count
            selectedRange = NSRange(location: selectedRange.location + offset, length: selectedText.count)
        } else {
            // No selection - insert empty code block at cursor or end
            let insertPosition = selectedRange.location != NSNotFound ? selectedRange.location : nsString.length
            let before = nsString.substring(to: min(insertPosition, nsString.length))
            let after = insertPosition < nsString.length ? nsString.substring(from: insertPosition) : ""

            let codeBlock = "\n```\(langSuffix)\n\n```\n"
            content = before + codeBlock + after
            // Place cursor inside the code block
            let offset = 5 + langSuffix.count
            selectedRange = NSRange(location: before.count + offset, length: 0)
        }
    }

    private func insertImage(url: String, alt: String, width: String, height: String) {
        let nsString = content as NSString

        // Build the image markdown
        var imageMarkdown = "![\(alt)](\(url)"

        // Add optional dimensions
        if !width.isEmpty || !height.isEmpty {
            imageMarkdown += " =\(width)x\(height)"
        }
        imageMarkdown += ")"

        // Insert at cursor position or end
        let insertPosition = selectedRange.location != NSNotFound ? selectedRange.location : nsString.length
        let before = nsString.substring(to: min(insertPosition, nsString.length))
        let after = insertPosition < nsString.length ? nsString.substring(from: insertPosition) : ""

        // Add newlines if needed
        let needsNewlineBefore = !before.isEmpty && !before.hasSuffix("\n")
        let needsNewlineAfter = !after.isEmpty && !after.hasPrefix("\n")

        var insertion = ""
        if needsNewlineBefore { insertion += "\n" }
        insertion += imageMarkdown
        if needsNewlineAfter { insertion += "\n" }

        content = before + insertion + after
        selectedRange = NSRange(location: before.count + insertion.count, length: 0)
    }

    private func insertEmoji(_ emoji: String) {
        let nsString = content as NSString
        let insertPosition = selectedRange.location != NSNotFound ? selectedRange.location : nsString.length
        let before = nsString.substring(to: min(insertPosition, nsString.length))
        let after = insertPosition < nsString.length ? nsString.substring(from: insertPosition) : ""

        content = before + emoji + after
        selectedRange = NSRange(location: before.count + emoji.count, length: 0)
    }

    private func insertToggleHeading(level: Int) {
        let nsString = content as NSString
        let insertPosition = selectedRange.location != NSNotFound ? selectedRange.location : nsString.length
        let before = nsString.substring(to: min(insertPosition, nsString.length))
        let after = insertPosition < nsString.length ? nsString.substring(from: insertPosition) : ""

        let hashes = String(repeating: "#", count: level)
        let toggleBlock = "\n>>>\(hashes) Toggle Title\n\nContent goes here...\n\n<<<\n"

        let needsNewlineBefore = !before.isEmpty && !before.hasSuffix("\n")
        var insertion = ""
        if needsNewlineBefore { insertion += "\n" }
        insertion += toggleBlock

        content = before + insertion + after
        // Position cursor at "Toggle Title" for easy editing
        let titleStart = before.count + (needsNewlineBefore ? 1 : 0) + 4 + level
        selectedRange = NSRange(location: titleStart, length: 12)
    }

    private func insertColumns(count: Int) {
        let nsString = content as NSString
        let insertPosition = selectedRange.location != NSNotFound ? selectedRange.location : nsString.length
        let before = nsString.substring(to: min(insertPosition, nsString.length))
        let after = insertPosition < nsString.length ? nsString.substring(from: insertPosition) : ""

        var columnsBlock = "\n{columns}\n"
        for i in 0..<count {
            columnsBlock += "Column \(i + 1) content...\n"
            if i < count - 1 {
                columnsBlock += "{---}\n"
            }
        }
        columnsBlock += "{/columns}\n"

        let needsNewlineBefore = !before.isEmpty && !before.hasSuffix("\n")
        var insertion = ""
        if needsNewlineBefore { insertion += "\n" }
        insertion += columnsBlock

        content = before + insertion + after
        selectedRange = NSRange(location: before.count + insertion.count, length: 0)
    }

    private func insertTable() {
        let nsString = content as NSString
        let insertPosition = selectedRange.location != NSNotFound ? selectedRange.location : nsString.length
        let before = nsString.substring(to: min(insertPosition, nsString.length))
        let after = insertPosition < nsString.length ? nsString.substring(from: insertPosition) : ""

        let tableMarkdown = """
{table}
| Header 1 | Header 2 | Header 3 |
|:---------|:--------:|---------:|
| Cell 1   | Cell 2   | Cell 3   |
| Cell 4   | Cell 5   | Cell 6   |
{/table}

"""

        let needsNewlineBefore = !before.isEmpty && !before.hasSuffix("\n")
        var insertion = ""
        if needsNewlineBefore { insertion += "\n" }
        insertion += tableMarkdown

        content = before + insertion + after
        // Position cursor at first header cell
        let headerStart = before.count + (needsNewlineBefore ? 1 : 0) + 2
        selectedRange = NSRange(location: headerStart, length: 7)
    }

    private func applyAlignment(_ alignment: String) {
        let nsString = content as NSString

        guard selectedRange.location != NSNotFound,
              selectedRange.location + selectedRange.length <= nsString.length else {
            // No selection - wrap current line
            let lineRange = nsString.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let lineText = nsString.substring(with: lineRange).trimmingCharacters(in: .newlines)
            if !lineText.isEmpty {
                let wrapped = "{align:\(alignment)}\(lineText){/align}"
                let before = nsString.substring(to: lineRange.location)
                let after = nsString.substring(from: lineRange.location + lineRange.length)
                content = before + wrapped + "\n" + after
                selectedRange = NSRange(location: lineRange.location + wrapped.count + 1, length: 0)
            }
            return
        }

        if selectedRange.length > 0 {
            // Wrap selection
            let selectedText = nsString.substring(with: selectedRange)
            let wrapped = "{align:\(alignment)}\(selectedText){/align}"
            let before = nsString.substring(to: selectedRange.location)
            let after = nsString.substring(from: selectedRange.location + selectedRange.length)
            content = before + wrapped + after
            selectedRange = NSRange(location: selectedRange.location, length: wrapped.count)
        } else {
            // Wrap current line
            let lineRange = nsString.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let lineText = nsString.substring(with: lineRange).trimmingCharacters(in: .newlines)
            if !lineText.isEmpty {
                let wrapped = "{align:\(alignment)}\(lineText){/align}"
                let before = nsString.substring(to: lineRange.location)
                let after = nsString.substring(from: lineRange.location + lineRange.length)
                content = before + wrapped + "\n" + after
                selectedRange = NSRange(location: lineRange.location + wrapped.count + 1, length: 0)
            }
        }
    }
}

extension String {
    func lineNumber(at location: Int) -> Int {
        let prefix = String(self.prefix(location))
        return prefix.components(separatedBy: "\n").count - 1
    }
}

// MARK: - Image Insert Sheet

struct ImageInsertSheet: View {
    @Binding var imageURL: String
    @Binding var imageAlt: String
    @Binding var imageWidth: String
    @Binding var imageHeight: String

    let onInsert: (String, String, String, String) -> Void
    let onCancel: () -> Void

    @State private var previewURL: URL?
    @State private var showPreview = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Insert Image")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(white: 0.5).opacity(0.1))

            // Form
            Form {
                Section("Image Source") {
                    TextField("Image URL", text: $imageURL, prompt: Text("https://example.com/image.png"))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: imageURL) { _, newValue in
                            previewURL = URL(string: newValue)
                        }

                    if let url = previewURL, !imageURL.isEmpty {
                        HStack {
                            Text("Preview:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(showPreview ? "Hide" : "Show") {
                                showPreview.toggle()
                            }
                            .font(.caption)
                        }

                        if showPreview {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 150)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                case .failure:
                                    Label("Failed to load preview", systemImage: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                case .empty:
                                    ProgressView()
                                        .frame(height: 100)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                }

                Section("Details") {
                    TextField("Alt Text", text: $imageAlt, prompt: Text("Description of the image"))
                        .textFieldStyle(.roundedBorder)
                }

                Section("Size (Optional)") {
                    HStack {
                        TextField("Width", text: $imageWidth, prompt: Text("Auto"))
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Text("×")
                            .foregroundColor(.secondary)
                        TextField("Height", text: $imageHeight, prompt: Text("Auto"))
                            .textFieldStyle(.roundedBorder)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                    }
                    Text("Leave empty for auto-sizing. Supports PNG, JPG, WebP, and SVG.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)

            // Footer
            HStack {
                Spacer()
                Button("Insert Image") {
                    onInsert(imageURL, imageAlt, imageWidth, imageHeight)
                }
                .buttonStyle(.borderedProminent)
                .disabled(imageURL.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 400)
    }
}

// MARK: - Toolbar Divider

struct ToolbarDivider: View {
    var body: some View {
        Divider()
            .frame(height: 20)
            .padding(.horizontal, 4)
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovering = false
    @State private var showTooltip = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 28)
                .background(isHovering ? Color.primary.opacity(0.1) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            isHovering = hovering
            #if os(macOS)
            // On macOS, .help() already provides tooltips, but we can enhance visibility
            showTooltip = hovering
            #else
            // On iOS, show custom tooltip after a delay
            if hovering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if isHovering {
                        showTooltip = true
                    }
                }
            } else {
                showTooltip = false
            }
            #endif
        }
        .overlay(alignment: .bottom) {
            if showTooltip {
                TooltipView(text: tooltip)
                    .offset(y: 35)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }
}

struct TooltipView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(6)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

struct ToolbarMenuButton<Content: View>: View {
    let icon: String
    let tooltip: String
    @ViewBuilder let menu: () -> Content
    
    @State private var isHovering = false
    @State private var showTooltip = false
    
    var body: some View {
        Menu {
            menu()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 28)
                .background(isHovering ? Color.primary.opacity(0.1) : Color.clear)
                .cornerRadius(4)
        }
        .menuStyle(.borderlessButton)
        .help(tooltip)
        .onHover { hovering in
            isHovering = hovering
            #if os(macOS)
            showTooltip = hovering
            #else
            if hovering {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if isHovering {
                        showTooltip = true
                    }
                }
            } else {
                showTooltip = false
            }
            #endif
        }
        .overlay(alignment: .bottom) {
            if showTooltip {
                TooltipView(text: tooltip)
                    .offset(y: 35)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }
}

// MARK: - Editor Status Bar

struct EditorStatusBar: View {
    let content: String

    private var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    private var characterCount: Int {
        content.count
    }

    private var lineCount: Int {
        content.components(separatedBy: .newlines).count
    }

    var body: some View {
        HStack {
            Text("\(wordCount) words")
            Text("•")
                .foregroundColor(.secondary)
            Text("\(characterCount) characters")
            Text("•")
                .foregroundColor(.secondary)
            Text("\(lineCount) lines")

            Spacer()

            Text("Markdown")
                .foregroundColor(.secondary)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(white: 0.5).opacity(0.05))
    }
}

// MARK: - Preview

#Preview("Split Mode") {
    @Previewable @State var content = "# Welcome to MarkdownPro\n\nThis is a **powerful** markdown editor with {color:blue}color support{/color}.\n\n## Code Example\n\n```swift\nlet greeting = \"Hello, World!\"\nprint(greeting)\n```\n\nAnd some `inline code` too.\n\n- Item 1\n- Item 2\n\n> This is a quote"
    @Previewable @State var mode = EditorMode.split

    MarkdownEditor(
        content: $content,
        editorMode: $mode
    )
    .frame(width: 1000, height: 600)
}

#Preview("Source Mode") {
    @Previewable @State var content = "# Hello\n\nThis is **markdown**."
    @Previewable @State var mode = EditorMode.source

    MarkdownEditor(
        content: $content,
        editorMode: $mode
    )
    .frame(width: 500, height: 400)
}

#Preview("Preview Mode") {
    @Previewable @State var content = "# Hello\n\nThis is **markdown**.\n\n```python\nprint('Hello')\n```"
    @Previewable @State var mode = EditorMode.preview

    MarkdownEditor(
        content: $content,
        editorMode: $mode
    )
    .frame(width: 500, height: 400)
}

// MARK: - Emoji Picker View

struct EmojiPickerView: View {
    let onSelect: (String) -> Void
    
    // Static emoji list - computed once
    private static let allEmojis: [String] = {
        [
            ("Smileys", ["😀", "😃", "😄", "😁", "😅", "😂", "🤣", "😊", "😇", "🙂", "😉", "😍", "🥰", "😘", "😋", "😜", "🤔", "🤨", "😐", "😑", "😶", "🙄", "😏", "😣", "😥", "😮", "🤐", "😯", "😪", "😫", "🥱", "😴", "😌", "😛", "😝", "🤤", "😒", "😓", "😔", "😕", "🙃", "🤑", "😲", "🙁", "😖", "😞", "😟", "😤", "😢", "😭", "😦", "😧", "😨", "😩", "🤯", "😬", "😰", "😱"]),
            ("Gestures", ["👍", "👎", "👌", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉", "👆", "👇", "☝️", "✋", "🤚", "🖐️", "🖖", "👋", "🤝", "🙏", "✍️", "💪", "👏", "🙌", "👐", "🤲", "🤜", "🤛", "✊", "👊"]),
            ("Objects", ["💻", "🖥️", "📱", "📲", "💾", "💿", "📀", "🎮", "🕹️", "📷", "📸", "📹", "🎥", "📽️", "📺", "📻", "🎙️", "🎚️", "🎛️", "⏱️", "⏲️", "⏰", "🕰️", "📡", "🔋", "🔌", "💡", "🔦", "🕯️", "📚", "📖", "📝", "✏️", "🖊️", "🖋️", "✒️", "📁", "📂", "📅", "📆"]),
            ("Symbols", ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "⭐", "🌟", "✨", "💫", "🔥", "💥", "💢", "💦", "💨", "🎉", "🎊", "✅", "❌", "❓", "❗", "💯", "🔴", "🟠", "🟡", "🟢", "🔵", "🟣", "⚫", "⚪", "🟤"]),
            ("Nature", ["🌸", "🌺", "🌻", "🌼", "🌷", "🌹", "🥀", "🌾", "🌿", "☘️", "🍀", "🍁", "🍂", "🍃", "🌲", "🌳", "🌴", "🌵", "🌱", "🌊", "🌈", "☀️", "🌤️", "⛅", "🌥️", "☁️", "🌦️", "🌧️", "⛈️", "🌩️", "🌨️", "❄️", "☃️", "⛄", "🌬️", "💨", "🌪️", "🌫️", "🌀", "🌙", "⭐", "🌟"]),
            ("Food", ["🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥬", "🥒", "🌶️", "🫑", "🌽", "🥕", "🧄", "🧅", "🥔", "🍠", "🍕", "🍔", "🍟", "🌭", "🥪", "🌮", "🌯", "🥗", "🍜", "🍝"])
        ].flatMap { $0.1 }
    }()
    
    // Static columns calculation - computed once
    private static let columnsPerRow: Int = {
        let totalEmojis = allEmojis.count
        let rows = 14
        return Int(ceil(Double(totalEmojis) / Double(rows)))
    }()
    
    private static let rows = 14
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<Self.rows, id: \.self) { rowIndex in
                    HStack(spacing: 4) {
                        ForEach(0..<Self.columnsPerRow, id: \.self) { colIndex in
                            let emojiIndex = rowIndex * Self.columnsPerRow + colIndex
                            if emojiIndex < Self.allEmojis.count {
                                Button(action: {
                                    onSelect(Self.allEmojis[emojiIndex])
                                }) {
                                    Text(Self.allEmojis[emojiIndex])
                                        .font(.title2)
                                        .frame(width: 32, height: 32)
                                        .background(Color.clear)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help(Self.allEmojis[emojiIndex])
                            } else {
                                // Empty cell to maintain grid structure
                                Color.clear
                                    .frame(width: 32, height: 32)
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
        .frame(width: min(600, CGFloat(Self.columnsPerRow) * 36 + 24), height: CGFloat(Self.rows) * 36 + 24)
    }
}
