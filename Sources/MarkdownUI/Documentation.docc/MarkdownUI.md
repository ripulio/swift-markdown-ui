# ``MarkdownUI``

Display and customize GitHub Flavored Markdown natively in SwiftUI—with single-pass layout, zero scroll jumps, and 120 Hz AI/LLM streaming.

## Overview

MarkdownUI is a native SwiftUI library for displaying and customizing [GitHub Flavored Markdown](https://github.github.com/gfm/), including headings, paragraphs, bulleted/numbered/task lists, blockquotes, fenced code blocks, adaptive tables, images, links, and thematic breaks.

Actively maintained by [Ripul](https://ripul.io) as a 100% source-compatible continuation of `gonzalezreal/swift-markdown-ui`, MarkdownUI 2.5 resolves block spacing on pass 1 (`Δ 0.0 pt`), keeps child view identity stable during token-by-token streaming, and includes ``Theme/chat`` for AI and messaging apps.

![A MarkdownUI view that displays a heading, paragraph, code block, and table using different themes](MarkdownUI)

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ChatAndStreaming>

### Upgrade guides

- <doc:MigratingToVersion2>

### Displaying Markdown

- ``Markdown``

### Customizing Appearance

- ``Theme``
- ``TextStyle``
- ``ForegroundColor``
- ``BackgroundColor``
- ``FontFamily``
- ``FontSize``
- ``FontStyle``
- ``FontWeight``
- ``FontWidth``
- ``StrikethroughStyle``
- ``UnderlineStyle``
- ``FontFamilyVariant``
- ``FontCapsVariant``
- ``FontDigitVariant``
- ``TextKerning``
- ``TextTracking``
- ``BlockStyle``
- ``BlockConfiguration``
- ``BlockMargin``
- ``MarkdownBlockMargins``
- ``CodeBlockConfiguration``
- ``ListMarkerConfiguration``
- ``TaskListMarkerConfiguration``
- ``TableBackgroundStyle``
- ``TableBorderStyle``
- ``TableCellConfiguration``
- ``TableLayoutStyle``
- ``MarkdownTableCellStyle``

### Formatting content

- ``MarkdownContent``
- ``Paragraph``
- ``Heading``
- ``Blockquote``
- ``CodeBlock``
- ``BulletedList``
- ``NumberedList``
- ``ListItem``
- ``TaskList``
- ``TaskListItem``
- ``TextTable``
- ``ThematicBreak``
- ``InlineContent``
- ``Code``
- ``Emphasis``
- ``Strong``
- ``Strikethrough``
- ``InlineImage``
- ``InlineLink``

### Extensibility

- ``ImageProvider``
- ``DefaultImageProvider``
- ``AssetImageProvider``
- ``CodeSyntaxHighlighter``
- ``PlainTextCodeSyntaxHighlighter``
