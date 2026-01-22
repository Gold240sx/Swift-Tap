import SwiftUI

/// A standalone, embeddable markdown editor widget for use in any SwiftUI app.
struct EmbeddableMarkdownEditor: View {
    @Binding var content: String

    let configuration: Configuration
    let onChange: ((String) -> Void)?

    @State private var editorMode: EditorMode
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @Environment(\.colorScheme) private var colorScheme

    init(
        content: Binding<String>,
        configuration: Configuration = .default,
        onChange: ((String) -> Void)? = nil
    ) {
        self._content = content
        self.configuration = configuration
        self.onChange = onChange
        self._editorMode = State(initialValue: configuration.defaultMode)
    }

    private var theme: EditorTheme {
        switch configuration.theme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .sepia:
            return .sepia
        case .system:
            return colorScheme == .dark ? .dark : .light
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if configuration.showToolbar {
                toolbar
            }

            GeometryReader { geometry in
                editorContent(geometry: geometry)
            }

            if configuration.showStatusBar {
                statusBar
            }
        }
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: configuration.cornerRadius)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .onChange(of: content) { _, newValue in
            onChange?(newValue)
        }
    }

    @ViewBuilder
    private func editorContent(geometry: GeometryProxy) -> some View {
        switch editorMode {
        case .source:
            sourceView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .preview:
            previewView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .split:
            HStack(spacing: 0) {
                sourceView
                    .frame(width: geometry.size.width / 2)

                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 1)

                previewView
                    .frame(width: geometry.size.width / 2)
            }
        }
    }

    private var sourceView: some View {
        ZStack(alignment: .topLeading) {
            if content.isEmpty && !configuration.placeholder.isEmpty {
                Text(configuration.placeholder)
                    .font(.system(size: configuration.fontSize, design: .monospaced))
                    .foregroundColor(theme.text.opacity(0.4))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            #if os(macOS)
            SelectableTextEditor(
                text: $content,
                selectedRange: $selectedRange,
                font: .monospacedSystemFont(ofSize: configuration.fontSize, weight: .regular),
                textColor: NSColor(theme.text),
                backgroundColor: NSColor(theme.background)
            )
            #else
            SelectableTextEditor(
                text: $content,
                selectedRange: $selectedRange,
                font: .monospacedSystemFont(ofSize: configuration.fontSize, weight: .regular),
                textColor: UIColor(theme.text),
                backgroundColor: UIColor(theme.background)
            )
            #endif
        }
        .background(theme.background)
    }

    private var previewView: some View {
        RichMarkdownPreview(
            content: content,
            theme: theme,
            fontSize: configuration.fontSize,
            lineHeight: configuration.lineHeight
        )
    }

    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // Text formatting
                Group {
                    compactToolbarButton(icon: "bold") {
                        applyWrap(prefix: "**", suffix: "**")
                    }

                    compactToolbarButton(icon: "italic") {
                        applyWrap(prefix: "_", suffix: "_")
                    }

                    compactToolbarButton(icon: "strikethrough") {
                        applyWrap(prefix: "~~", suffix: "~~")
                    }

                    compactToolbarButton(icon: "highlighter") {
                        applyWrap(prefix: "==", suffix: "==")
                    }
                }

                Divider().frame(height: 16)

                // Color picker
                Menu {
                    ForEach(colorOptions, id: \.name) { option in
                        Button(action: { applyColor(option.name) }) {
                            Label(option.name.capitalized, systemImage: "circle.fill")
                        }
                    }
                } label: {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)

                // Font size picker
                Menu {
                    ForEach(sizeOptions, id: \.self) { size in
                        Button(action: { applySize(size) }) {
                            Text("\(size)pt")
                        }
                    }
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)

                Divider().frame(height: 16)

                // Structure
                Group {
                    compactToolbarButton(icon: "text.badge.plus") {
                        insertAtLineStart("# ")
                    }

                    compactToolbarButton(icon: "link") {
                        applyWrap(prefix: "[", suffix: "](url)")
                    }

                    compactToolbarButton(icon: "chevron.left.forwardslash.chevron.right") {
                        applyWrap(prefix: "`", suffix: "`")
                    }

                    // Code block with language selection
                    Menu {
                        Section("Popular") {
                            ForEach(popularLanguages, id: \.rawValue) { lang in
                                Button(action: { applyCodeBlock(language: lang.rawValue) }) {
                                    Label(lang.displayName, systemImage: "chevron.left.forwardslash.chevron.right")
                                }
                            }
                        }
                        Divider()
                        Button(action: { applyCodeBlock(language: "") }) {
                            Label("Plain Text", systemImage: "text.alignleft")
                        }
                    } label: {
                        Image(systemName: "text.and.command.macwindow")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 24, height: 24)
                    }
                    .menuStyle(.borderlessButton)
                }

                Divider().frame(height: 16)

                // Lists
                Group {
                    compactToolbarButton(icon: "list.bullet") {
                        insertAtLineStart("- ")
                    }

                    compactToolbarButton(icon: "checklist") {
                        insertAtLineStart("- [ ] ")
                    }
                }

                Spacer()

                Picker("", selection: $editorMode) {
                    ForEach(EditorMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color(white: 0.5).opacity(0.08))
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
        [10, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48]
    }

    private var popularLanguages: [Language] {
        [.swift, .python, .javascript, .typescript, .java, .kotlin,
         .go, .rust, .c, .cpp, .ruby, .php, .sql, .bash, .html, .css, .json, .yaml]
    }

    private func compactToolbarButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary.opacity(0.7))
    }

    private var statusBar: some View {
        HStack {
            let words = content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
            Text("\(words) words")
            Text("•").foregroundColor(.secondary)
            Text("\(content.count) chars")
            Spacer()
        }
        .font(.caption2)
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(white: 0.5).opacity(0.05))
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

        if selectedRange.length > 0 && selectedRange.location + selectedRange.length <= nsString.length {
            let selectedText = nsString.substring(with: selectedRange)
            let before = nsString.substring(to: selectedRange.location)
            let after = nsString.substring(from: selectedRange.location + selectedRange.length)

            content = before + "```\(langSuffix)\n" + selectedText + "\n```" + after
            let offset = 4 + langSuffix.count
            selectedRange = NSRange(location: selectedRange.location + offset, length: selectedText.count)
        } else {
            let insertPosition = selectedRange.location != NSNotFound ? selectedRange.location : nsString.length
            let before = nsString.substring(to: min(insertPosition, nsString.length))
            let after = insertPosition < nsString.length ? nsString.substring(from: insertPosition) : ""

            let codeBlock = "\n```\(langSuffix)\n\n```\n"
            content = before + codeBlock + after
            let offset = 5 + langSuffix.count
            selectedRange = NSRange(location: before.count + offset, length: 0)
        }
    }
}

// MARK: - Configuration

extension EmbeddableMarkdownEditor {
    struct Configuration {
        var defaultMode: EditorMode
        var fontSize: CGFloat
        var lineHeight: CGFloat
        var theme: Theme
        var showToolbar: Bool
        var showStatusBar: Bool
        var placeholder: String
        var cornerRadius: CGFloat

        static let `default` = Configuration()

        static let minimal = Configuration(
            showToolbar: false,
            showStatusBar: false,
            cornerRadius: 0
        )

        static let compact = Configuration(
            fontSize: 13,
            showStatusBar: false,
            cornerRadius: 6
        )

        init(
            defaultMode: EditorMode = .split,
            fontSize: CGFloat = 15,
            lineHeight: CGFloat = 1.5,
            theme: Theme = .system,
            showToolbar: Bool = true,
            showStatusBar: Bool = true,
            placeholder: String = "Start writing...",
            cornerRadius: CGFloat = 8
        ) {
            self.defaultMode = defaultMode
            self.fontSize = fontSize
            self.lineHeight = lineHeight
            self.theme = theme
            self.showToolbar = showToolbar
            self.showStatusBar = showStatusBar
            self.placeholder = placeholder
            self.cornerRadius = cornerRadius
        }
    }

    enum Theme {
        case light
        case dark
        case sepia
        case system
    }
}

// MARK: - View Modifier for Easy Integration

extension View {
    func markdownEditorSheet(
        isPresented: Binding<Bool>,
        content: Binding<String>,
        configuration: EmbeddableMarkdownEditor.Configuration = .default
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            NavigationStack {
                EmbeddableMarkdownEditor(content: content, configuration: configuration)
                    .padding()
                    .navigationTitle("Edit")
                    #if !os(macOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                isPresented.wrappedValue = false
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Previews

#Preview("Default") {
    @Previewable @State var content = "# Welcome\n\nThis is a **markdown** editor with {color:blue}colors{/color}.\n\n```swift\nlet x = 42\nprint(x)\n```"

    EmbeddableMarkdownEditor(content: $content)
        .frame(width: 700, height: 400)
        .padding()
}

#Preview("Minimal") {
    @Previewable @State var content = "# Hello World"

    EmbeddableMarkdownEditor(
        content: $content,
        configuration: .minimal
    )
    .frame(width: 500, height: 300)
    .padding()
}

#Preview("Dark Theme") {
    @Previewable @State var content = "# Dark Mode\n\nLooks great with {color:cyan}colors{/color}!"

    EmbeddableMarkdownEditor(
        content: $content,
        configuration: .init(theme: .dark)
    )
    .frame(width: 600, height: 350)
    .padding()
    .background(Color.black)
}

#Preview("Compact") {
    @Previewable @State var content = "Quick note"

    EmbeddableMarkdownEditor(
        content: $content,
        configuration: .compact
    )
    .frame(width: 400, height: 200)
    .padding()
}
