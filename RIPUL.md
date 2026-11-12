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
`swift test --skip FontPropertiesTests` runs the remaining 80 tests, including the
new regression, static-margin, and pixel-parity tests. The macOS hosted
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

## Layout and measurement performance passes (November 2026)

Passes 1–7 run automatically by default whenever the active `Theme` uses
declarative or identity block styles, keeping SwiftUI's native `Text` and
preserving exact first-pass/settled heights and rendered pixels
(`StaticBlockMarginsTests`, `LightweightListMarkersTests`,
`LightweightBlocksTests`, and `BulletedListConvergenceTests` on macOS, plus
Ripul's 35-snapshot UIKit cross-revision SHA-256 check against `c6d0fcc`). Any
custom `BlockStyle` closure automatically falls back to the general path.

- **Passes 1–3 (`97cd258`..`c1bf001`) — Single-pass settled heights:**
  - `markdownBlockMargins(_:)` spaces blocks from the parsed `BlockNode` tree on
    the first layout pass without `BlockMarginsPreference` state or preference
    updates, preserving descendant max-margin reduction and tight-list rules.
  - Bulleted lists and single-item numbered lists skip marker-width preference
    measurement, and built-in bullet markers size in a single text-style pass
    (`builtinBulletMarker`).
  - `TableLayoutStyle.adaptive(availableWidth:minimumColumnWidth:maximumColumnWidth:overflow:onMeasureWidth:)`
    adds closure-driven width resolution, layout-pass measurement caching, and
    `canReuseUnwrappedCellHeights` so scroll-wrapped tables read their proposed
    width straight from an enclosing `Layout` on pass 1 and measure unwrapped
    cells once.
- **Pass 4 (`c6d0fcc`) — Lightweight blocks and shape-batched tables:**
  - Paired with `Theme.paragraph(lineSpacing:)` and `markdownTableCellStyle(_:)`,
    pre-collects `AttributeContainer` in `EnvironmentValues.textStyleAttributes`,
    resolves inline `Font` runs in one renderer pass without per-node
    `resolvingFonts()`, flattens single-chunk stateless `InlineText`,
    single-child `BlockSequence` and single-paragraph list items without
    `AnyView` wrappers, and replaces adaptive tables' per-cell
    `TableCellBoundsPreference` anchors, `GeometryReader`s and `Rectangle` grids
    with layout-resolved non-overlapping `Shape` batches (`TableRowCellsShape`
    and `TableBorderGroupShape`).
- **Pass 5 (`942cb35`) — Compact layouts and equatable themes:**
  - Adds `Equatable` conformances on `Theme`, `BlockStyle` (monotone revision IDs)
    and `InlineTextStyles`, and stores `AttributeContainer` directly in
    `EnvironmentValues.textStyleAttributes` without boxing an `any TextStyle`
    existential so unrelated UIKit/SwiftUI environment updates do not
    re-evaluate `Markdown` or child views.
  - Single-paragraph bulleted lists lay out bare icon/text pairs inside
    `BulletedListLayout` instead of per-item `Label`/`HStack`s, adaptive tables
    place bare `Text` cells with padding and column alignment inside
    `AdaptiveTableLayout`, paragraph-only sequences use `ParagraphStackLayout`,
    and inline runs share `PrecomputedInlineAttributes`.
- **Pass 6 (`83cd82d`, convergence fix `281f61b`) — Direct `Text(verbatim:)` runs
  and bullet probe cache:**
  - Eliminates per-run `Foundation.AttributedString` allocation and
    `AttributedStringTextStorage` Objective-C dictionary bridging for plain,
    strong and emphasis inline runs via `DirectTextStyle` (`Text(verbatim:)`
    segments with direct `Font`/`Color`/`kerning`/`tracking`/`baselineOffset`
    modifiers and balanced binary concatenation, retaining `AttributedString`
    only for spans with background colour, links, underlines or strikethrough).
  - Caches `BulletedListLayout`'s `Label` cap-centre bullet probe metrics across
    lists (`BulletProbeMetricsCache`), checks `BulletProbeMetricsCache.lookup`
    and `BulletedListLayout.Cache.probe` inside `measure` so cold-mounted lists
    never re-measure the hidden `Label` subview or re-store probe metrics across
    layout passes, and keeps a 6-slot width cache in `BulletedListLayout.Cache`
    so multi-width parent layouts do not thrash single-width cached metrics.
- **Pass 7 (`f53b0d5`, height propagation fix `68dd3f9`) — Direct block sequences:**
  - Paired with `Theme.headings(fontWeight:fontSize:lineSpacing:)` /
    `BlockStyle.heading(fontWeight:fontSize:lineSpacing:)`, top-level mixed block
    sequences (`listLevel == 0`) bypass `VStack`, `ForEach`, per-block
    `.padding(.top, ...)`, `BlockNode` enum conditional chains, `ParagraphView`,
    `HeadingView` (`AnyView` and `.id(kebabCased())`) and redundant
    `markdownBlockPath` writes via `DirectBlockSequenceView` and
    `BlockSpacedStackLayout` (with a homogeneous `Text` fast path for pure
    heading-and-paragraph runs, and `forceMeasure: true` in `sizeThatFits` so
    descendant `@State` height changes propagate upward).
  - `StaticViewBatch` unrolls homogeneous batches under 32 items into static
    binary tuples instead of `ForEach` / `DynamicViewList` (and 16-item chunks at
    or above 32).
  - `InlineAttributesCache` shares pre-warmed `PrecomputedInlineAttributes`
    across headings, paragraphs, lists and table cells; `MarkdownContent` tracks
    `hasImages` at parse time so image-free documents skip
    `filterImagesMatching`; and `hasMultipleTextChunks` checks line-break
    chunking without array allocation.

### Safety invariants for future fork changes

- **Automatic fallback on custom styles:** Fast paths check `paragraphLineSpacing`
  / `isIdentity`, `headingSpec` / `isIdentity`, `list.isIdentity`,
  `listItem.isIdentity`, `builtinBulletMarker`, and `tableCellStyle != nil`. Any
  custom `BlockStyle` closure automatically falls back to the general path.
- **`Theme` and style equality:** `Theme.==` must compare `textRevision`,
  `inlineStylesRevision`, and every stored `BlockStyle` (including `headings`);
  never omit a property or two distinct themes will compare equal and suppress
  legitimate updates.
- **`Layout` placement width proposals:** `ParagraphStackLayout` and
  `BlockSpacedStackLayout` must pass
  `ProposedViewSize(width: proposalWidth, height: itemSize.height)` (not
  `itemSize.width`) in `placeSubviews` so child `BulletedListLayout`,
  `AdaptiveTableLayout` and `Text` hit their `availableWidth`-keyed caches rather
  than re-measuring at shrunk widths.
- **Nested list baseline alignment:** Keep `DirectBlockSequenceView` /
  `BlockSpacedStackLayout` gated to `listLevel == 0`. Inside nested multi-block
  list items (`ListItemView` and `TaskListItemView`), `BlockSequence` sits inside
  `Label`'s title, which aligns bullet icons to `VStack`'s `.firstTextBaseline`.
- **Heading line-spacing resolution:** `HeadingStyleSpec.lineSpacing` resolves
  relative `.em(...)` units against the *outer*
  `textStyleAttributes.fontProperties` (matching `.markdownTextStyle { ... }`
  inside `.relativeLineSpacing(...)`).
- **Do not merge multiple paragraphs into one `SwiftUI.Text`:** `SwiftUICore`
  (`Text.ResolvedProperties.Paragraph`) builds one uniform `NSParagraphStyle`
  from `EnvironmentValues.lineSpacing` and overwrites `AttributedString`
  `paragraphStyle`. A single `Text` cannot simultaneously apply intra-paragraph
  line spacing and larger inter-paragraph block spacing without inserting fake
  blank lines that shift heights and corrupt `.textSelection(.enabled)` copy
  output.
