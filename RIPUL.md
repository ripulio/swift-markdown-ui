# Ripul's MarkdownUI fork

Based on upstream MarkdownUI **2.4.1**, commit `5f613358148239d0292c0cef674a3c2314737f9e`.
The upstream MIT licence and attribution remain in `LICENSE`.

The `ripul` branch keeps the parser and public theme API. Its small patch set:

- Key block views and their measured margins by position, so streaming text does
  not discard a code block's controls or accumulate one margin entry per edit.
- Expose `CodeBlockConfiguration.blockPath`, including nested list and quote
  positions, for independent state in an application's custom code block view.
- Expose the current `markdownBlockPath` as a read-only public environment value
  for other block controls, including per-table width choices.
- Pass the first word of a fence's info string as its highlighting language.
- Offer opt-in adaptive table sizing through `markdownTableLayout(.adaptive(...))`.
  Measure styled cells, keep short columns compact, wrap longer columns to fit
  the viewport, and retain readable widths when horizontal scrolling is needed.
  The optional `.minimum` overflow policy limits scroll distance by wrapping
  columns at their readable minimums when the requested width cannot fit them.
- Expose `TableCellConfiguration.alignment` for text alignment and read table
  environment modifiers inside the styled label. Cells can fill their entire
  row with top-aligned contents and consistent borders/backgrounds.

Ripul's typography, table appearance, colours and controls belong in the app's theme, not
in this package. Single line breaks use the existing `markdownSoftBreakMode` API.
Consumers should pin a release tag or commit, rather than the moving branch.

For upstream updates, rebase this branch and run `swift test`. On macOS 27 with
Xcode 27.1, the unchanged upstream `FontPropertiesTests` fails eight opaque SwiftUI
`Font` equality assertions (reproduced on the unmodified 2.4.1 tag).
`swift test --skip FontPropertiesTests` runs the remaining 68 tests, including the
new regression tests. The macOS hosted
view tests check actual view reuse while the Markdown changes; parser fixtures
cover longer fences, nested code and document-wide reference links. Hosted table
checks cover actual wrapping, column widths, text alignment, full row bounds,
horizontal overflow, empty cells, header-only tables and right-to-left order. No snapshots
are required for these checks.

The feedback regression pass (2.4.2-ripul.4):

- Clear the line-start whitespace state after styled inlines, fixing upstream
  [#402](https://github.com/gonzalezreal/swift-markdown-ui/issues/402).
- Accumulate attributed text between images and balance image/text concatenation,
  avoiding a deeply nested `Text + Text` tree for newline-heavy paragraphs
  ([#312](https://github.com/gonzalezreal/swift-markdown-ui/issues/312), also
  discussed in upstream PRs 438 and 444). Very long paragraphs are split at
  authored rendered line breaks into bounded native Text views; this also fixes
  the measured accessibility snapshot bottleneck with 1,200 links.
- Flow images together with surrounding styled text, including linked and nested
  images. Images use the image provider's fitting layout, retain their links and
  expose alt text as accessibility images (#420/#439). The image theme/provider
  now applies to mixed image paragraphs as well as image-only paragraphs.
- Provide `MarkdownContent.renderAttributedString` for continuous native text
  selection, keeping inline presentation intents, links, line breaks and lists;
  tables copy as tab-separated cells. Consumers choose native fonts and colours.

`Examples/RegressionLab` is an independently runnable iOS app. Five UI checks
passed on iOS 27.1: exact whitespace, interaction after a 1,200-line linked
paragraph, seven-level lists, image bounds/link activation/nested alt labels,
and Dynamic Type scaling compared with native body text. No screenshots were
used. These are scoped regression results, not a claim that every upstream
performance report is reproduced or that VoiceOver speech was manually approved.

2.4.2-ripul.5 adds opt-in `markdownInlineImageFlow()` to extend fitting, linked
image views to headings and table cells, including images nested in styles.
The default retains the inline image provider for those contexts. A sixth iOS
UI check verifies heading alt labels, actual table image bounds and link taps.
All 68 applicable package tests still pass.
