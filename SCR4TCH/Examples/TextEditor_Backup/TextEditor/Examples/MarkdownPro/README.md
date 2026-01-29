# MarkdownPro

A powerful, feature-rich markdown editor for macOS built with SwiftUI and SwiftData. MarkdownPro combines a beautiful writing experience with advanced markdown features, making it perfect for writers, developers, and anyone who works with markdown documents.

## Features

### 📝 Core Editing Features

- **Triple View Modes**
  - **Source Mode**: Edit raw markdown with syntax highlighting
  - **Preview Mode**: See rendered markdown output
  - **Split Mode**: Side-by-side source and preview for real-time editing

- **Rich Markdown Support**
  - Headings (H1-H6) with customizable sizes (H1: 48pt, H2: 36pt, H3: 28pt)
  - **Bold**, *italic*, ~~strikethrough~~, <u>underline</u>, and ==highlight== text formatting
  - Inline code and code blocks with syntax highlighting
  - Blockquotes
  - Ordered and unordered lists
  - Checkbox lists
  - Horizontal rules
  - Links and images with custom dimensions

### 🎨 Advanced Markdown Features

- **Tables**
  - Full table support with headers, rows, and column alignment
  - Custom header rows and columns
  - Table markers: `{table}` and `{/table}`
  - Markdown table syntax support

- **Columns Layout**
  - Multi-column layouts for side-by-side content
  - Column separators using `{---}`
  - Column markers: `{columns}` and `{/columns}`

- **Collapsible Sections (Toggle Blocks)**
  - Create collapsible content sections
  - Syntax: `>>># Heading Title` ... `<<<`
  - Nested content support
  - Expandable/collapsible with chevron indicators

- **Text Alignment**
  - Left, center, and right alignment for paragraphs
  - Syntax: `{align:left}`, `{align:center}`, `{align:right}`

### 🛠️ Editor Features

- **Undo/Redo System**
  - Full undo/redo history (up to 50 states)
  - Keyboard shortcuts: `⌘Z` (undo), `⌘⇧Z` (redo)
  - Toolbar buttons with visual feedback

- **Rich Toolbar**
  - Text formatting buttons (bold, italic, strikethrough, underline, highlight)
  - Text color picker with predefined colors
  - Font size selector
  - Heading insertion (H1-H6)
  - List insertion (bulleted, numbered, checkbox)
  - Image insertion with URL, alt text, and dimensions
  - Emoji picker
  - Table insertion
  - Column layout insertion
  - Toggle block insertion
  - Horizontal rule insertion

- **Syntax Highlighting**
  - Code block syntax highlighting for multiple languages
  - Customizable syntax themes (light/dark)
  - Monospaced font for code blocks

- **Word Count & Statistics**
  - Real-time word count
  - Character count
  - Status bar display

### 🎨 Themes & Customization

- **Multiple Themes**
  - Light theme
  - Dark theme
  - Sepia theme
  - System theme (follows macOS appearance)

- **Customizable Settings**
  - Font size (default: 16pt)
  - Line height (default: 1.5)
  - Font family
  - Editor width constraints
  - Paragraph spacing
  - Show/hide line numbers
  - Enable/disable spell checking
  - Auto-save settings

### 📚 Document Management

- **SwiftData Integration**
  - Native SwiftData document storage
  - Document metadata tracking
  - Last accessed timestamps
  - Document organization

- **Tags System**
  - Tag documents for organization
  - Tag picker interface
  - Filter documents by tags

- **Auto-Save**
  - Automatic document saving
  - Configurable auto-save interval (default: 30 seconds)
  - Manual save option

### 🔧 Technical Features

- **Editable Preview**
  - Inline editing in preview mode
  - Click-to-edit blocks
  - Real-time markdown parsing

- **Embeddable Component**
  - Reusable `MarkdownEditor` component
  - `EmbeddableMarkdownEditor` for integration into other apps
  - Configurable appearance and behavior

- **Performance**
  - Lazy loading for large documents
  - Efficient markdown parsing
  - Optimized rendering

## Markdown Syntax Reference

### Basic Formatting

```markdown
**bold text**
*italic text*
~~strikethrough~~
<u>underline</u>
==highlight==
`inline code`
```

### Headings

```markdown
# Heading 1 (48pt)
## Heading 2 (36pt)
### Heading 3 (28pt)
#### Heading 4
##### Heading 5
###### Heading 6
```

### Lists

```markdown
- Bullet list item
- Another item

1. Numbered list item
2. Another item

- [ ] Unchecked checkbox
- [x] Checked checkbox
```

### Code Blocks

````markdown
```swift
func hello() {
    print("Hello, World!")
}
```
````

### Tables

```markdown
{table}
| Header 1 | Header 2 | Header 3 |
|:---------|:--------:|---------:|
| Cell 1   | Cell 2   | Cell 3   |
| Cell 4   | Cell 5   | Cell 6   |
{/table}
```

### Columns

```markdown
{columns}
Column 1 content goes here.
{---}
Column 2 content goes here.
{/columns}
```

### Toggle Blocks (Collapsible Sections)

```markdown
>>># Section Title

Content inside the collapsible section.

More content here.

<<<
```

### Images

```markdown
![Alt text](https://example.com/image.png)
![Alt text](https://example.com/image.png =800x600)
```

### Text Alignment

```markdown
{align:center}
This text is centered.
{/align}

{align:right}
This text is right-aligned.
{/align}
```

## Keyboard Shortcuts

- `⌘Z` - Undo
- `⌘⇧Z` - Redo
- `⌘B` - Bold
- `⌘I` - Italic
- `⌘S` - Save (if save handler provided)

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Architecture

MarkdownPro is built with:

- **SwiftUI** - Modern UI framework
- **SwiftData** - Data persistence
- **Combine** - Reactive programming
- **Custom Markdown Parser** - Built-in markdown parsing engine

### Key Components

- `MarkdownEditor` - Main editor component
- `RichMarkdownPreview` - Rich preview renderer
- `EditableRichMarkdownPreview` - Editable preview with inline editing
- `MarkdownParser` - Markdown parsing engine
- `ContentUndoManager` - Undo/redo management
- `Document` - SwiftData document model
- `EditorSettings` - User preferences and settings

## Installation

1. Clone the repository
2. Open `MarkdownPro.xcodeproj` in Xcode
3. Build and run (⌘R)

## Usage

### Basic Usage

```swift
import SwiftUI

struct ContentView: View {
    @State private var content = "# Hello, World!"
    @State private var mode: EditorMode = .split
    
    var body: some View {
        MarkdownEditor(
            content: $content,
            editorMode: $mode,
            theme: "system",
            fontSize: 16
        )
    }
}
```

### Embeddable Editor

```swift
EmbeddableMarkdownEditor(
    content: $content,
    configuration: .default
) { newContent in
    print("Content changed: \(newContent)")
}
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

[Add your license here]

## Acknowledgments

Built with ❤️ using SwiftUI and SwiftData.
