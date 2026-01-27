//
//  CodeBlockView.swift
//  TextEditor
//
//  Syntax-highlighted code block view with language selection.
//

import SwiftUI
import SwiftData

struct CodeBlockView: View {
    @Bindable var codeBlock: CodeBlockData
    var note: RichTextNote?
    var onDelete: () -> Void = {}
    @Environment(\.modelContext) var context
    @Environment(\.colorScheme) var colorScheme
    @State private var isEditing = false
    @State private var isHovering = false
    @State private var showLanguagePicker = false
    @State private var editingCode: String = ""

    private var theme: SyntaxTheme {
        colorScheme == .dark ? .dark : .light
    }

    private var highlighter: SyntaxHighlighter {
        SyntaxHighlighter(theme: theme, fontSize: 13)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                // Language picker button
                Button {
                    showLanguagePicker.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(codeBlock.language.displayName)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showLanguagePicker) {
                    CodeLanguagePicker(selectedLanguage: codeBlock.language) { language in
                        codeBlock.language = language
                        // Save the last used language to the note
                        note?.lastUsedCodeLanguage = language.rawValue
                        showLanguagePicker = false
                    }
                }

                Spacer()

                // Action buttons (show on hover)
                HStack(spacing: 8) {
                    // Line numbers toggle
                    Button {
                        codeBlock.showLineNumbers = !(codeBlock.showLineNumbers ?? false)
                    } label: {
                        Image(systemName: (codeBlock.showLineNumbers ?? false) ? "list.number" : "list.bullet")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help((codeBlock.showLineNumbers ?? false) ? "Hide line numbers" : "Show line numbers")

                    // Copy menu with options
                    Menu {
                        Button {
                            #if os(iOS)
                            UIPasteboard.general.string = codeBlock.code ?? ""
                            #else
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(codeBlock.code ?? "", forType: .string)
                            #endif
                        } label: {
                            Label("Copy Code", systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            let markdown = codeBlock.markdownOutput
                            #if os(iOS)
                            UIPasteboard.general.string = markdown
                            #else
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(markdown, forType: .string)
                            #endif
                        } label: {
                            Label("Copy as Markdown", systemImage: "doc.text")
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy code")

                    // Edit/Done button
                    Button {
                        if isEditing {
                            codeBlock.code = editingCode
                        } else {
                            editingCode = codeBlock.code ?? ""
                        }
                        isEditing.toggle()
                    } label: {
                        Image(systemName: isEditing ? "checkmark" : "pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(isEditing ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isEditing ? "Save changes" : "Edit code")

                    // Delete button
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete code block")
                }
                .opacity(isHovering ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.background.opacity(0.5))

            Divider()

            // Code content
            if isEditing {
                // Editable text editor
                TextEditor(text: $editingCode)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(theme.background)
            } else {
                // Syntax highlighted display
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        // Line numbers
                        if codeBlock.showLineNumbers ?? false {
                            VStack(alignment: .trailing, spacing: 0) {
                                ForEach(1...max(1, (codeBlock.code ?? "").components(separatedBy: "\n").count), id: \.self) { lineNum in
                                    Text("\(lineNum)")
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                        .frame(minWidth: 30, alignment: .trailing)
                                }
                            }
                            .padding(.trailing, 12)
                            .padding(.leading, 12)
                            .padding(.vertical, 12)
                            .background(theme.background.opacity(0.5))

                            Divider()
                        }

                        // Highlighted code
                        Text(highlighter.highlight(codeBlock.code ?? "", language: codeBlock.languageString ?? "swift"))
                            .font(.system(size: 13, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(codeBlock.languageString ?? "swift") // Force redraw when language changes
                    }
                }
                .background(theme.background)
            }
        }
        .background(theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Language Picker

struct CodeLanguagePicker: View {
    var selectedLanguage: Language
    var onSelect: (Language) -> Void

    private let popularLanguages: [Language] = [
        .swift, .python, .javascript, .typescript, .html, .css, .json,
        .rust, .go, .java, .c, .cpp, .ruby, .php, .sql, .bash, .yaml
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Select Language")
                .font(.headline)
                .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(popularLanguages, id: \.rawValue) { language in
                        languageButton(language)
                    }

                    Divider()
                        .padding(.vertical, 4)

                    languageButton(.plainText)
                }
            }
            .frame(maxHeight: 300)
        }
        .padding()
        .frame(width: 180)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func languageButton(_ language: Language) -> some View {
        let isSelected = language == selectedLanguage
        Button {
            onSelect(language)
        } label: {
            HStack {
                Text(language.displayName)
                    .font(.system(size: 13))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// Preview requires running app due to SwiftData model dependencies
