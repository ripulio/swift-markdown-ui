# Changelog

All notable changes to `ripulio/swift-markdown-ui` are documented in this file.

This fork tracks Semantic Versioning from upstream [`gonzalezreal/swift-markdown-ui` `2.4.1`](https://github.com/gonzalezreal/swift-markdown-ui/releases/tag/2.4.1) (`5f61335`).

## [2.5.1] — 2026-11-24

### Fixed
- **iOS list link hit-testing:** On iOS, SwiftUI's `.textSelection(.enabled)` expands each selectable `Text` hit-test responder by `±16 pt` while only accepting taps within its exact glyph bounds, causing a following list item to eclipse links on the item above it. `BulletedListView`, `CompactBulletedListView`, `NumberedListView`, and `TaskListView` now disable `.textSelection` on iOS only for lists containing a link followed by another item or sibling block, leaving link-free lists, trailing-link lists, and prose unchanged.
- **Swift 6 concurrency support:** Added `Sendable` conformance to `MarkdownContent` (and its underlying `BlockNode` AST types) and `@unchecked Sendable` conformance to `Theme` (incorporating upstream `#351`).
- **Documentation & example polish:** Fixed DocC doc-comment typos (upstream `#354`), expanded DocC coverage for `Theme.chat` and 2.5 APIs, upgraded `Examples/BenchmarkApp` to measure attached `UIWindow`/`NSWindow` hosts against an actual Upstream `2.4.1` baseline, cleaned up `Examples/RegressionLab` and `Examples/Demo`, and added `CONTRIBUTING.md`, `CHANGELOG.md`, and `ARCHITECTURE.md`.

## [2.5.0] — 2026-11-12

### Added
- **`Theme.chat` preset:** Purpose-built SwiftUI Markdown theme for AI assistants and messaging apps—proportioned headings, rounded callout blockquotes, language-labelled scrollable code cards, single-pass `BulletedListLayout`, and viewport-aware horizontal-scrolling GFM tables (`AdaptiveTableLayout` with shape-batched borders and alternating stripes).
- **Zero-config single-pass built-in themes:** Upgraded `Theme.basic`, `Theme.gitHub`, and `Theme.docC` to declarative `RelativeBlockMargin` and `HeadingStyleSpec`, unlocking single-pass layout automatically with pixel and height parity against upstream `2.4.1` (and automatic fallback for custom `.markdownBlockStyle(...)` closures).
- **Direct block sequences & inline fast paths (Passes 1–7):**
  - Declarative `markdownBlockMargins(_:)` for zero-jitter first-pass heights (`Δ 0.0 pt`).
  - `DirectBlockSequenceView`, `BlockSpacedStackLayout`, `ParagraphStackLayout`, and `StaticViewBatch` to eliminate `VStack` / `ForEach` / `AnyView` overhead.
  - Direct `Text(verbatim:)` inline runs with cached `Font` / `PrecomputedInlineAttributes` lookup, avoiding per-run `AttributedString` dictionary bridging.
  - `BulletedListLayout` with cached cap-center bullet probe metrics (`BulletProbeMetricsCache`) and multi-width caching.
  - `Equatable` conformances on `Theme`, `BlockStyle`, and `InlineTextStyles`.
- **Interactive `Examples/BenchmarkApp`:** iOS & macOS benchmark suite, 120 Hz streaming simulator, and built-in theme gallery.

## [2.4.2-ripul.5] — 2026-10-26

### Added
- Opt-in `markdownInlineImageFlow(_:)` modifier extending fitting, linked image flow to headings and table cells.

## [2.4.2-ripul.4] — 2026-10-26

### Fixed
- Cleared line-start whitespace state after styled inline runs (upstream [`#402`](https://github.com/gonzalezreal/swift-markdown-ui/issues/402)).
- Balanced inline `Text` concatenation and split very long paragraphs at authored rendered line breaks into bounded `Text` views, fixing main-thread hangs and accessibility snapshot stalls (upstream [`#312`](https://github.com/gonzalezreal/swift-markdown-ui/issues/312)).
- Flowed images alongside styled text (including linked and nested images with alt-text accessibility labels), applying the configured `ImageProvider` outside image-only paragraphs (upstream [`#420`](https://github.com/gonzalezreal/swift-markdown-ui/issues/420) / [`#439`](https://github.com/gonzalezreal/swift-markdown-ui/issues/439)).

### Added
- `MarkdownContent.renderAttributedString(softBreaks:baseURL:)` for continuous native `AttributedString` export/selection.
- `Examples/RegressionLab` standalone iOS UI regression harness.

## [2.4.2-ripul.1 – 2.4.2-ripul.3] — 2026-10-26

### Added
- Positional block identity (`markdownBlockPath` environment value and `CodeBlockConfiguration.blockPath`) so token-by-token streaming preserves child state and code-block controls.
- First-word fence info-string language extraction.
- Opt-in `markdownTableLayout(.adaptive(...))` with `.natural` / `.minimum` overflow policies and `TableCellConfiguration.alignment`.

## [2.4.1] — 2024-10-11 (Upstream Base)

- Base commit `5f613358148239d0292c0cef674a3c2314737f9e` from [`gonzalezreal/swift-markdown-ui`](https://github.com/gonzalezreal/swift-markdown-ui).
