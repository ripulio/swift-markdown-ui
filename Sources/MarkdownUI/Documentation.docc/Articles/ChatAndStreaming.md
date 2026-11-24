# Chat Interfaces, Streaming & Performance

Use ``Theme/chat``, single-pass block layout, adaptive GFM tables, and `Sendable` off-main parsing for responsive AI and messaging UIs.

## Overview

Built-in themes (``Theme/chat``, ``Theme/basic``, ``Theme/gitHub``, and ``Theme/docC``) automatically resolve block margins, bulleted/nested/numbered/task lists, and `.automatic`/`.adaptive` GFM tables on pass 1, eliminating the `PreferenceKey` height corrections that cause scroll jumps inside `List`, `LazyVStack`, and `UICollectionView`. During live token streaming, completed prefix blocks are memoized via `Equatable` wrappers and prefix-stable view batches so only the trailing block re-lays out.

![Theme.chat rendering headings, lists, callout quotes, fenced code blocks, and an adaptive GFM table](ThemeChat)

## Using `Theme.chat`

Apply ``Theme/chat`` for proportioned headings, rounded callout blockquotes, language-header code cards, compact bullet lists, and viewport-aware horizontal-scrolling GFM tables:

```swift
import MarkdownUI
import SwiftUI

struct AssistantMessageView: View {
  let content: MarkdownContent

  var body: some View {
    Markdown(self.content)
      .markdownTheme(.chat)
      .textSelection(.enabled)
  }
}
```

## Parsing Off the Main Thread

``MarkdownContent`` conforms to `Sendable` and `Equatable`. Parse incoming Markdown chunks on a background actor or task so scrolling views perform zero parsing on the main thread:

```swift
let parsed = await Task.detached(priority: .userInitiated) {
  MarkdownContent(rawMarkdown)
}.value
```

## Preserving State During Live Streaming

MarkdownUI keys block views by their structural position in the document tree rather than by full block text. Inside custom block styles, read `EnvironmentValues.markdownBlockPath` (or ``CodeBlockConfiguration/blockPath`` for fenced code blocks) to scope per-block UI state—such as copy confirmations, collapsed sections, or per-table width controls—without resetting when new tokens arrive.

```swift
.markdownBlockStyle(\.codeBlock) { configuration in
  MyCodeCard(
    language: configuration.language,
    blockPath: configuration.blockPath,
    label: configuration.label
  )
}
```

## Adaptive GFM Tables

On iOS 16+ / macOS 13+, ``Theme/chat`` automatically wraps tables in a horizontal `ScrollView` backed by ``TableLayoutStyle/adaptive(availableWidth:minimumColumnWidth:maximumColumnWidth:overflow:)``. To enable adaptive sizing in a custom theme, wrap the table in a horizontal scroll view and apply `markdownTableLayout(_:)`:

```swift
.markdownBlockStyle(\.table) { configuration in
  ScrollView(.horizontal, showsIndicators: true) {
    configuration.label
      .markdownTableLayout(
        .adaptive(
          availableWidth: 360,
          minimumColumnWidth: 80,
          maximumColumnWidth: 360,
          overflow: .minimum
        )
      )
  }
}
```

## Custom Themes on the Single-Pass Fast Path

If you build your own theme and want single-pass margins without `PreferenceKey` re-layouts, supply declarative ``MarkdownBlockMargins`` with `markdownBlockMargins(_:)` and use `Theme.paragraph(lineSpacing:)` and `Theme.headings(fontWeight:fontSize:lineSpacing:)`. Any custom `.markdownBlockStyle(...)` closure continues to work identically and falls back to dynamic margin measurement automatically.

## Inline Images & Native `AttributedString` Export

- Apply `markdownInlineImageFlow()` to flow fitted, linked images alongside text in headings and table cells as well as paragraphs.
- Call ``MarkdownContent/renderAttributedString(softBreaks:baseURL:)`` to export a full-document `AttributedString` preserving inline styles, links, lists, and tab-separated tables.
