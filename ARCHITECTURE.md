# Single-Pass Architecture & Performance Invariants

This document explains how `ripulio/swift-markdown-ui` achieves single-pass SwiftUI layout (`Δ 0.0 pt` height jumps) and 4×–6× faster cold host sizing while remaining 100% source-compatible with upstream `MarkdownUI 2.4.1`.

---

## Why Upstream `2.4.1` Stutters in `List` & Streaming Chats

Upstream `MarkdownUI 2.4.1` relies on three patterns that create expensive multi-pass work when hosted inside `List`, `LazyVStack`, or `UICollectionView` cells:

1. **Dynamic `PreferenceKey` margin resolution:** Each block publishes its top/bottom margin via `BlockMarginsPreference`, causing `BlockSequence` to lay out once with default padding, receive preferences asynchronously, mutate `@State`, and re-lay out a second time—producing visible scroll jumps and doubling cold row cost.
2. **Per-item SwiftUI wrapper overhead:** Every bulleted list item builds a `Label` + width `PreferenceKey`, every table cell wraps a `GeometryReader` + bounds preference + `Rectangle` border grid, and mixed block sequences stack `ForEach` + `AnyView` + per-block `.padding`.
3. **Per-run `AttributedString` bridging:** Plain, bold, and italic text runs construct and bridge `Foundation.AttributedString` attribute dictionaries on every layout, and deep recursive `Text + Text` concatenation hangs on newline-heavy paragraphs (`#312`).

---

## Optimization Passes (1–7)

All passes activate automatically whenever the active `Theme` uses declarative or identity block styles (including built-in `.basic`, `.gitHub`, `.docC`, and `.chat`). Any custom `.markdownBlockStyle(...)` closure falls back cleanly to the general dynamic path.

### Passes 1–3 — Single-Pass Settled Heights
- **Declarative tree margins (`markdownBlockMargins(_:)` / `RelativeBlockMargin`):** Block spacing is resolved directly from the parsed `BlockNode` tree on pass 1 without `BlockMarginsPreference` `@State` updates, preserving descendant max-margin collapsing and tight-list rules.
- **Zero-preference list markers:** Bulleted lists and single-item numbered lists skip marker-width preference measurement, and built-in bullet markers (`disc`, `circle`, `square`, `discCircleSquare`) size in one pass.
- **Layout-driven adaptive tables:** `TableLayoutStyle.adaptive(availableWidth:minimumColumnWidth:maximumColumnWidth:overflow:onMeasureWidth:)` reads its viewport width directly from the enclosing `Layout` proposal on pass 1 and caches unwrapped cell measurements (`canReuseUnwrappedCellHeights`).

### Pass 4 — Lightweight Blocks & Shape-Batched Tables
- Pre-collects `AttributeContainer` directly in `EnvironmentValues.textStyleAttributes` and resolves inline `Font` runs in a single pass.
- Flattens single-chunk stateless `InlineText`, single-child `BlockSequence`, and single-paragraph list items without `AnyView` wrappers.
- Replaces adaptive tables' per-cell `TableCellBoundsPreference` anchors, `GeometryReader`s, and `Rectangle` border grids with non-overlapping layout-resolved `Shape` batches (`TableRowCellsShape` and `TableBorderGroupShape`).

### Pass 5 — Compact Layouts & `Equatable` Themes
- Conforms `Theme`, `BlockStyle` (via monotone revision IDs), and `InlineTextStyles` to `Equatable` and stores `AttributeContainer` directly without boxing an `any TextStyle` existential—preventing unrelated SwiftUI/UIKit environment updates from re-evaluating `Markdown`.
- Single-paragraph bulleted lists render bare icon/text pairs inside `BulletedListLayout`; adaptive tables place bare `Text` cells inside `AdaptiveTableLayout`; pure paragraph sequences use `ParagraphStackLayout`.

### Pass 6 — Direct `Text(verbatim:)` Runs & Bullet Probe Cache
- Replaces per-run `Foundation.AttributedString` bridging with `DirectTextStyle` (`Text(verbatim:)` segments with direct `Font` / `Color` / `kerning` / `tracking` / `baselineOffset` modifiers and balanced binary concatenation) for plain, strong, and emphasis spans, retaining `AttributedString` only for spans needing background color, links, underline, or strikethrough.
- Caches `BulletedListLayout`'s hidden `Label` cap-center probe metrics in `BulletProbeMetricsCache` and maintains a 6-slot width cache per layout instance so multi-width parent proposals do not thrash.

### Pass 7 — Direct Block Sequences & Static View Batches
- Top-level mixed block sequences (`listLevel == 0`) render through `DirectBlockSequenceView` and `BlockSpacedStackLayout`, bypassing `VStack`, `ForEach`, `AnyView`, and per-block `.padding`.
- `StaticViewBatch` unrolls homogeneous batches under 32 items into static binary tuples (and 16-item chunks at or above 32), avoiding `DynamicViewList` overhead.
- `InlineAttributesCache` shares `PrecomputedInlineAttributes` across headings, paragraphs, lists, and cells; `MarkdownContent` tracks `hasImages` at parse time so image-free documents skip image filtering.

### 2.5.0–2.5.1 — Built-In Fast Themes, `Theme.chat`, `Sendable`, & iOS Link Hit-Testing
- `Theme.basic`, `Theme.gitHub`, and `Theme.docC` declare their margins and headings declaratively and are pixel-parity tested against upstream `2.4.1` closures (`BuiltInThemesFastPathTests`).
- `Theme.chat` activates every fast path plus `ChatAdaptiveTableView` and language-header code cards out of the box.
- `MarkdownContent` (and `BlockNode` / `InlineNode`) conform to `Sendable` for safe off-main parsing; `Theme` conforms to `@unchecked Sendable`.
- On iOS, lists containing a link above another list item or sibling block disable `.textSelection` on that list (`hasOccludedListLink`) to avoid SwiftUI's `±16 pt` expanded `TextSelectionInteractionView` responder eclipsing taps on the link above.

---

## Safety Invariants for Contributors

Keep these invariants intact when modifying layout or theming code:

1. **Automatic fallback on custom styles:** Fast paths must check `paragraphLineSpacing` / `isIdentity`, `headingSpec` / `isIdentity`, `list.isIdentity`, `listItem.isIdentity`, `builtinBulletMarker`, and `tableCellStyle != nil`. Any custom `BlockStyle` closure must fall back seamlessly to the general path.
2. **`Theme` equality completeness:** `Theme.==` must compare `textRevision`, `inlineStylesRevision`, and every stored `BlockStyle` (including all 6 `headings`). Omitting a stored property can suppress legitimate SwiftUI view updates.
3. **`Layout` placement width proposals:** `ParagraphStackLayout` and `BlockSpacedStackLayout` must propose `ProposedViewSize(width: proposalWidth, height: itemSize.height)` (not `itemSize.width`) in `placeSubviews` so child `BulletedListLayout`, `AdaptiveTableLayout`, and `Text` views hit their `availableWidth`-keyed caches rather than re-measuring at shrunk widths.
4. **Nested list baseline alignment:** Keep `DirectBlockSequenceView` / `BlockSpacedStackLayout` gated to `listLevel == 0`. Inside nested multi-block list items (`ListItemView`, `TaskListItemView`), `BlockSequence` sits inside `Label`'s title, which aligns markers to `VStack`'s `.firstTextBaseline`.
5. **Heading line-spacing resolution:** `HeadingStyleSpec.lineSpacing` resolves relative `.em(...)` units against the *outer* `textStyleAttributes.fontProperties` unless `scalesLineSpacingToHeadingFont` is set (matching upstream `.markdownTextStyle` + `.relativeLineSpacing` behavior).
6. **Never merge multiple paragraphs into one `SwiftUI.Text`:** `SwiftUICore` builds one uniform `NSParagraphStyle` from `EnvironmentValues.lineSpacing` and overwrites `AttributedString.paragraphStyle`. Merging separate paragraphs into one `Text` cannot preserve distinct intra-paragraph line spacing and inter-paragraph margins without inserting fake blank lines that corrupt `.textSelection(.enabled)` copy output.
7. **Always propagate child height changes in `sizeThatFits`:** `BlockSpacedStackLayout.sizeThatFits` must measure subviews with `forceMeasure: true` so descendant `@State` height changes (such as async images or interactive disclosures) propagate upward reliably.
