# Ripul's MarkdownUI fork

Based on upstream MarkdownUI **2.4.1**, commit `5f613358148239d0292c0cef674a3c2314737f9e`.
The upstream MIT licence and attribution remain in `LICENSE`.

The `ripul` branch keeps the parser and public theme API. Its small patch set:

- Key block views and their measured margins by position, so streaming text does
  not discard a code block's controls or accumulate one margin entry per edit.
- Expose `CodeBlockConfiguration.blockPath`, including nested list and quote
  positions, for independent state in an application's custom code block view.
- Pass the first word of a fence's info string as its highlighting language.
- Offer opt-in adaptive table sizing through `markdownTableLayout(.adaptive(...))`.
  Measure styled cells, keep short columns compact, wrap longer columns to fit
  the viewport, and retain readable widths when horizontal scrolling is needed.
- Expose `TableCellConfiguration.alignment` for text alignment and read table
  environment modifiers inside the styled label. Cells can fill their entire
  row with top-aligned contents and consistent borders/backgrounds.

Ripul's typography, table appearance, colours and controls belong in the app's theme, not
in this package. Single line breaks use the existing `markdownSoftBreakMode` API.
Consumers should pin a release tag or commit, rather than the moving branch.

For upstream updates, rebase this branch and run `swift test`. On macOS 27 with
Xcode 27.1, the unchanged upstream `FontPropertiesTests` fails eight opaque SwiftUI
`Font` equality assertions (reproduced on the unmodified 2.4.1 tag).
`swift test --skip FontPropertiesTests` runs the remaining 57 tests, including the
new regression tests. The macOS hosted
view tests check actual view reuse while the Markdown changes; parser fixtures
cover longer fences, nested code and document-wide reference links. Hosted table
checks cover actual wrapping, column widths, text alignment, full row bounds,
horizontal overflow, empty cells, header-only tables and right-to-left order. No snapshots
are required for these checks.
