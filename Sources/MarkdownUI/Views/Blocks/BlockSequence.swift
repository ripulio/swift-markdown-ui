import SwiftUI

struct BlockSequence<Data, Content>: View
where
  Data: Sequence,
  Data.Element: BlockMarginElement,
  Content: View
{
  @Environment(\.multilineTextAlignment) private var textAlignment
  @Environment(\.tightSpacingEnabled) private var tightSpacingEnabled
  @Environment(\.markdownBlockPath) private var blockPath
  @Environment(\.markdownBlockMargins) private var staticBlockMargins
  @Environment(\.inlineImageFlow) private var inlineImageFlow
  @Environment(\.lightweightBlocks) private var lightweightBlocks
  @Environment(\.compactLayout) private var compactLayout
  @Environment(\.directBlocks) private var directBlocks
  @Environment(\.listLevel) private var listLevel
  @Environment(\.theme.paragraph) private var paragraph

  private let data: [Indexed<Data.Element>]
  private let content: (Int, Data.Element) -> Content
  private let rawBlocks: [BlockNode]?

  init(
    _ data: Data,
    @ViewBuilder content: @escaping (_ index: Int, _ element: Data.Element) -> Content
  ) {
    self.data = data.indexed()
    self.content = content
    self.rawBlocks = nil
  }

  fileprivate init(
    rawBlocks: [BlockNode],
    @ViewBuilder content: @escaping (_ index: Int, _ element: Data.Element) -> Content
  ) {
    self.data = rawBlocks.indexed() as! [Indexed<Data.Element>]
    self.content = content
    self.rawBlocks = rawBlocks
  }

  var body: some View {
    if let staticBlockMargins = self.staticBlockMargins {
      if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *),
        self.compactLayout,
        self.lightweightBlocks,
        self.paragraph.paragraphLineSpacing != nil || self.paragraph.isIdentity,
        let rawBlocks = self.rawBlocks,
        let paragraphs = Self.simpleParagraphBlocks(rawBlocks)
      {
        CompactParagraphSequenceView(
          paragraphs: paragraphs,
          margins: staticBlockMargins,
          textAlignment: self.textAlignment,
          tightSpacingEnabled: self.tightSpacingEnabled,
          paragraphLineSpacing: self.paragraph.paragraphLineSpacing
        )
      } else if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *),
        self.directBlocks,
        self.compactLayout,
        self.lightweightBlocks,
        self.listLevel == 0,
        let rawBlocks = self.rawBlocks,
        !rawBlocks.isEmpty,
        let topSpacings = DirectBlockSequenceView.computeTopSpacings(
          rawBlocks: rawBlocks,
          margins: staticBlockMargins,
          inlineImageFlow: self.inlineImageFlow,
          tightSpacingEnabled: self.tightSpacingEnabled
        )
      {
        DirectBlockSequenceView(
          rawBlocks: rawBlocks,
          topSpacings: topSpacings,
          margins: staticBlockMargins,
          textAlignment: self.textAlignment,
          blockPath: self.blockPath
        )
      } else {
        StaticBlockSequenceContent(
          data: self.data,
          content: self.content,
          margins: staticBlockMargins,
          inlineImageFlow: self.inlineImageFlow,
          textAlignment: self.textAlignment,
          tightSpacingEnabled: self.tightSpacingEnabled,
          blockPath: self.blockPath,
          lightweightBlocks: self.lightweightBlocks
        )
      }
    } else {
      DynamicBlockSequenceContent(
        data: self.data,
        content: self.content,
        textAlignment: self.textAlignment,
        tightSpacingEnabled: self.tightSpacingEnabled,
        blockPath: self.blockPath
      )
    }
  }

  private static func simpleParagraphBlocks(_ blocks: [BlockNode]) -> [[InlineNode]]? {
    guard !blocks.isEmpty else { return nil }
    var result: [[InlineNode]] = []
    result.reserveCapacity(blocks.count)
    for block in blocks {
      guard case .paragraph(let inlines) = block,
        !inlines.contains(where: \.containsImage)
      else {
        return nil
      }
      result.append(inlines)
    }
    return result
  }
}

private struct StaticBlockSequenceContent<Element: BlockMarginElement, Content: View>: View {
  let data: [Indexed<Element>]
  let content: (Int, Element) -> Content
  let margins: MarkdownBlockMargins
  let inlineImageFlow: Bool
  let textAlignment: TextAlignment
  let tightSpacingEnabled: Bool
  let blockPath: [Int]
  let lightweightBlocks: Bool

  var body: some View {
    if self.lightweightBlocks, self.data.count == 1 {
      self.content(0, self.data[0].value)
        .environment(\.markdownBlockPath, self.blockPath + [0])
    } else {
      let resolved = self.data.map {
        $0.value.effectiveMargin(using: self.margins, inlineImageFlow: self.inlineImageFlow)
      }
      VStack(alignment: self.textAlignment.alignment.horizontal, spacing: 0) {
        ForEach(self.data, id: \.index) { element in
          self.content(element.index, element.value)
            .environment(\.markdownBlockPath, self.blockPath + [element.index])
            .padding(.top, self.topPaddingLength(at: element.index, margins: resolved))
        }
      }
    }
  }

  private func topPaddingLength(at index: Int, margins: [BlockMargin]) -> CGFloat? {
    guard index > 0 else {
      return 0
    }
    let topSpacing = margins[index].top
    let predecessorBottomSpacing =
      self.tightSpacingEnabled ? 0 : margins[index - 1].bottom
    return BlockMargin.max(topSpacing, predecessorBottomSpacing)
  }
}

private struct DynamicBlockSequenceContent<Element: Hashable, Content: View>: View {
  @State private var blockMargins: [Int: BlockMargin] = [:]

  let data: [Indexed<Element>]
  let content: (Int, Element) -> Content
  let textAlignment: TextAlignment
  let tightSpacingEnabled: Bool
  let blockPath: [Int]

  var body: some View {
    VStack(alignment: self.textAlignment.alignment.horizontal, spacing: 0) {
      // A streamed edit changes a block's value, not its position. Keying by the
      // entire value recreates the view (and its local state) for every token.
      ForEach(self.data, id: \.index) { element in
        self.content(element.index, element.value)
          .environment(\.markdownBlockPath, self.blockPath + [element.index])
          .onPreferenceChange(BlockMarginsPreference.self) { value in
            self.blockMargins[element.index] = value
          }
          .padding(.top, self.topPaddingLength(for: element))
      }
    }
  }

  private func topPaddingLength(for element: Indexed<Element>) -> CGFloat? {
    guard element.index > 0 else {
      return 0
    }

    let topSpacing = self.blockMargins[element.index]?.top
    let predecessor = self.data[element.index - 1]
    let predecessorBottomSpacing =
      self.tightSpacingEnabled ? 0 : self.blockMargins[predecessor.index]?.bottom

    return BlockMargin.max(topSpacing, predecessorBottomSpacing)
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct CompactParagraphSequenceView: View {
  @Environment(\.textStyleAttributes) private var textStyleAttributes
  @Environment(\.theme.inlineTextStyles) private var inlineStyles
  @Environment(\.baseURL) private var baseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.lineSpacing) private var environmentLineSpacing
  @Environment(\.directBlocks) private var directBlocks

  let paragraphs: [[InlineNode]]
  let margins: MarkdownBlockMargins
  let textAlignment: TextAlignment
  let tightSpacingEnabled: Bool
  let paragraphLineSpacing: RelativeSize?

  var body: some View {
    let cache =
      self.directBlocks
      ? InlineAttributesCache.lookup(
        attributes: self.textStyleAttributes,
        inlineStyles: self.inlineStyles
      )
      : PrecomputedInlineAttributes(
        attributes: self.textStyleAttributes,
        inlineStyles: self.inlineStyles
      )
    let resolvedLineSpacing = self.paragraphLineSpacing?.points(
      relativeTo: self.textStyleAttributes.fontProperties
    )

    if self.directBlocks,
      !self.paragraphs.contains(where: { $0.hasMultipleTextChunks(softBreakMode: self.softBreakMode) })
    {
      if self.paragraphs.count == 1 {
        let single = self.paragraphs[0].renderCompactText(
          baseURL: self.baseURL,
          softBreakMode: self.softBreakMode,
          cache: cache
        )
        if let resolvedLineSpacing {
          single
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(resolvedLineSpacing)
        } else {
          single
        }
      } else {
        let spacing =
          BlockMargin.max(
            self.margins.paragraph.top,
            self.tightSpacingEnabled ? 0 : self.margins.paragraph.bottom
          ) ?? 0
        let stack = ParagraphStackLayout(
          alignment: self.textAlignment,
          spacing: spacing
        ) {
          StaticViewBatch(count: self.paragraphs.count) { index in
            self.paragraphs[index].renderCompactText(
              baseURL: self.baseURL,
              softBreakMode: self.softBreakMode,
              cache: cache
            )
          }
        }
        if let resolvedLineSpacing {
          stack
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(resolvedLineSpacing)
        } else {
          stack
        }
      }
    } else {
      let itemChunks = self.paragraphs.map { $0.textChunks(softBreakMode: self.softBreakMode) }

      if itemChunks.count == 1 {
        let single = self.paragraphItem(
          chunks: itemChunks[0],
          cache: cache,
          chunkSpacing: resolvedLineSpacing ?? self.environmentLineSpacing
        )
        if let resolvedLineSpacing {
          single
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(resolvedLineSpacing)
        } else {
          single
        }
      } else {
        let spacing =
          BlockMargin.max(
            self.margins.paragraph.top,
            self.tightSpacingEnabled ? 0 : self.margins.paragraph.bottom
          ) ?? 0
        let allSingleChunk = itemChunks.allSatisfy { $0.count == 1 }
        let stack = self.makeParagraphStack(
          itemChunks: itemChunks,
          allSingleChunk: allSingleChunk,
          spacing: spacing,
          cache: cache,
          chunkSpacing: resolvedLineSpacing ?? self.environmentLineSpacing
        )
        if let resolvedLineSpacing {
          stack
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(resolvedLineSpacing)
        } else {
          stack
        }
      }
    }
  }

  @ViewBuilder private func makeParagraphStack(
    itemChunks: [[[InlineNode]]],
    allSingleChunk: Bool,
    spacing: CGFloat,
    cache: PrecomputedInlineAttributes,
    chunkSpacing: CGFloat
  ) -> some View {
    if allSingleChunk {
      ParagraphStackLayout(
        alignment: self.textAlignment,
        spacing: spacing
      ) {
        ForEach(itemChunks.indices, id: \.self) { index in
          itemChunks[index][0].renderCompactText(
            baseURL: self.baseURL,
            softBreakMode: self.softBreakMode,
            cache: cache
          )
        }
      }
    } else {
      ParagraphStackLayout(
        alignment: self.textAlignment,
        spacing: spacing
      ) {
        ForEach(itemChunks.indices, id: \.self) { index in
          self.paragraphItem(
            chunks: itemChunks[index],
            cache: cache,
            chunkSpacing: chunkSpacing
          )
        }
      }
    }
  }

  @ViewBuilder private func paragraphItem(
    chunks: [[InlineNode]],
    cache: PrecomputedInlineAttributes,
    chunkSpacing: CGFloat
  ) -> some View {
    if chunks.count == 1 {
      chunks[0].renderCompactText(
        baseURL: self.baseURL,
        softBreakMode: self.softBreakMode,
        cache: cache
      )
    } else {
      VStack(alignment: self.textAlignment.alignment.horizontal, spacing: chunkSpacing) {
        ForEach(chunks.indices, id: \.self) { chunkIndex in
          chunks[chunkIndex].renderCompactText(
            baseURL: self.baseURL,
            softBreakMode: self.softBreakMode,
            cache: cache
          )
        }
      }
    }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct ParagraphStackLayout: Layout {
  let alignment: TextAlignment
  let spacing: CGFloat

  struct Cache {
    var key: CacheKey?
    var itemSizes: [CGSize] = []
    var size: CGSize = .zero
  }

  struct CacheKey: Equatable {
    let subviewCount: Int
    let availableWidth: CGFloat?
    let spacing: CGFloat
    let alignment: TextAlignment
  }

  func makeCache(subviews: Subviews) -> Cache {
    Cache()
  }

  func updateCache(_ cache: inout Cache, subviews: Subviews) {
    cache = Cache()
  }

  func explicitAlignment(
    of guide: HorizontalAlignment,
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) -> CGFloat? {
    nil
  }

  func explicitAlignment(
    of guide: VerticalAlignment,
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) -> CGFloat? {
    nil
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
    self.resolve(
      proposalWidth: proposal.width,
      subviews: subviews,
      cache: &cache,
      forceMeasure: true
    )
    return cache.size
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) {
    self.resolve(
      proposalWidth: proposal.width ?? bounds.width,
      subviews: subviews,
      cache: &cache,
      forceMeasure: abs(cache.size.height - bounds.height) >= 0.01
    )
    let proposalWidth = cache.key?.availableWidth
    var y = bounds.minY
    for (index, subview) in subviews.enumerated() {
      let itemSize = cache.itemSizes[index]
      let itemProposal = ProposedViewSize(width: proposalWidth, height: itemSize.height)
      switch self.alignment {
      case .leading:
        subview.place(
          at: CGPoint(x: bounds.minX, y: y),
          anchor: .topLeading,
          proposal: itemProposal
        )
      case .center:
        subview.place(
          at: CGPoint(x: bounds.midX, y: y),
          anchor: .top,
          proposal: itemProposal
        )
      case .trailing:
        subview.place(
          at: CGPoint(x: bounds.maxX, y: y),
          anchor: .topTrailing,
          proposal: itemProposal
        )
      }
      y += itemSize.height + self.spacing
    }
  }

  private func resolve(
    proposalWidth: CGFloat?,
    subviews: Subviews,
    cache: inout Cache,
    forceMeasure: Bool
  ) {
    let normalizedWidth: CGFloat? =
      if let w = proposalWidth, w.isFinite { w } else { nil }
    let key = CacheKey(
      subviewCount: subviews.count,
      availableWidth: normalizedWidth,
      spacing: self.spacing,
      alignment: self.alignment
    )
    if !forceMeasure, cache.key == key {
      return
    }
    guard !subviews.isEmpty else {
      cache.key = key
      cache.itemSizes = []
      cache.size = .zero
      return
    }
    let itemProposal = ProposedViewSize(width: normalizedWidth, height: nil)
    var sizes: [CGSize] = []
    sizes.reserveCapacity(subviews.count)
    var maxWidth: CGFloat = 0
    var totalHeight: CGFloat = 0
    for subview in subviews {
      let measured = subview.sizeThatFits(itemProposal)
      sizes.append(measured)
      maxWidth = max(maxWidth, measured.width)
      totalHeight += measured.height
    }
    totalHeight += CGFloat(max(0, subviews.count - 1)) * self.spacing
    cache.key = key
    cache.itemSizes = sizes
    cache.size = CGSize(width: maxWidth, height: totalHeight)
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct DirectBlockSequenceView: View {
  fileprivate struct ProseItem {
    let text: Text
    let lineSpacing: CGFloat
    let needsVerticalFixedSize: Bool
  }

  fileprivate enum DirectItem {
    case prose(ProseItem)
    case bulletedList(
      paragraphs: [[InlineNode]],
      isTight: Bool,
      builtinMarker: BlockStyle<ListMarkerConfiguration>.BuiltinBulletMarker
    )
    case codeBlock(fenceInfo: String?, content: String, index: Int)
    case table(columnAlignments: [RawTableColumnAlignment], rows: [RawTableRow], index: Int)
    case thematicBreak
    case other(block: BlockNode, index: Int)
  }

  @Environment(\.theme) private var theme
  @Environment(\.textStyleAttributes) private var textStyleAttributes
  @Environment(\.baseURL) private var baseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.lineSpacing) private var environmentLineSpacing
  @Environment(\.lightweightListMarkers) private var lightweightListMarkers

  let rawBlocks: [BlockNode]
  let topSpacings: [CGFloat]
  let margins: MarkdownBlockMargins
  let textAlignment: TextAlignment
  let blockPath: [Int]

  static func computeTopSpacings(
    rawBlocks: [BlockNode],
    margins: MarkdownBlockMargins,
    inlineImageFlow: Bool,
    tightSpacingEnabled: Bool
  ) -> [CGFloat]? {
    guard !rawBlocks.isEmpty else { return [] }
    if rawBlocks.count == 1 {
      return [0]
    }
    var spacings: [CGFloat] = []
    spacings.reserveCapacity(rawBlocks.count)
    spacings.append(0)
    var previousMargin = Self.fastEffectiveMargin(
      for: rawBlocks[0],
      margins: margins,
      inlineImageFlow: inlineImageFlow
    )
    for index in 1..<rawBlocks.count {
      let currentMargin = Self.fastEffectiveMargin(
        for: rawBlocks[index],
        margins: margins,
        inlineImageFlow: inlineImageFlow
      )
      let prevBottom = tightSpacingEnabled ? 0 : previousMargin.bottom
      guard let spacing = BlockMargin.max(currentMargin.top, prevBottom) else {
        return nil
      }
      spacings.append(spacing)
      previousMargin = currentMargin
    }
    return spacings
  }

  private static func fastEffectiveMargin(
    for block: BlockNode,
    margins: MarkdownBlockMargins,
    inlineImageFlow: Bool
  ) -> BlockMargin {
    switch block {
    case .bulletedList(_, let items) where !items.isEmpty:
      if BulletedListView.extractSimpleParagraphItems(items) != nil {
        return margins.list.combined(with: margins.listItem).combined(with: margins.paragraph)
      }
      return block.effectiveMargin(using: margins, inlineImageFlow: inlineImageFlow)
    default:
      return block.effectiveMargin(using: margins, inlineImageFlow: inlineImageFlow)
    }
  }

  var body: some View {
    let inlineStyles = self.theme.inlineTextStyles
    let fontProperties = self.textStyleAttributes.fontProperties
    let paragraphStyle = self.theme.paragraph
    let canDirectParagraph = paragraphStyle.paragraphLineSpacing != nil || paragraphStyle.isIdentity
    let resolvedParagraphLineSpacing = paragraphStyle.paragraphLineSpacing?.points(
      relativeTo: fontProperties
    )
    let canCompactList =
      self.lightweightListMarkers
      && self.theme.list.isIdentity
      && self.theme.listItem.isIdentity
      && canDirectParagraph
    let builtinBullet = self.theme.bulletedListMarker.builtinBulletMarker

    var lazyBodyCache: PrecomputedInlineAttributes?
    func getBodyCache() -> PrecomputedInlineAttributes {
      if let cached = lazyBodyCache { return cached }
      let built = InlineAttributesCache.lookup(
        attributes: self.textStyleAttributes,
        inlineStyles: inlineStyles
      )
      lazyBodyCache = built
      return built
    }

    var items: [DirectItem] = []
    items.reserveCapacity(self.rawBlocks.count)
    var allProse = true

    for (index, block) in self.rawBlocks.enumerated() {
      switch block {
      case .paragraph(let inlines)
      where canDirectParagraph
        && !inlines.contains(where: \.containsImage)
        && !inlines.hasMultipleTextChunks(softBreakMode: self.softBreakMode):
        let text = inlines.renderCompactText(
          baseURL: self.baseURL,
          softBreakMode: self.softBreakMode,
          cache: getBodyCache()
        )
        items.append(
          .prose(
            ProseItem(
              text: text,
              lineSpacing: resolvedParagraphLineSpacing ?? self.environmentLineSpacing,
              needsVerticalFixedSize: resolvedParagraphLineSpacing != nil
            )
          )
        )

      case .heading(let level, let inlines):
        let headingStyle = self.theme.headings[level - 1]
        if (headingStyle.headingSpec != nil || headingStyle.isIdentity),
          !inlines.contains(where: \.containsImage),
          !inlines.hasMultipleTextChunks(softBreakMode: self.softBreakMode)
        {
          let spec = headingStyle.headingSpec
          let cache =
            (spec?.fontWeight == nil && spec?.fontSize == nil)
            ? getBodyCache()
            : InlineAttributesCache.lookup(
              attributes: self.textStyleAttributes,
              inlineStyles: inlineStyles,
              overrideWeight: spec?.fontWeight,
              overrideSize: spec?.fontSize
            )
          let text = inlines.renderCompactText(
            baseURL: self.baseURL,
            softBreakMode: self.softBreakMode,
            cache: cache
          )
          let resolvedHeadingSpacing =
            spec?.lineSpacing?.points(relativeTo: fontProperties) ?? self.environmentLineSpacing
          items.append(
            .prose(
              ProseItem(
                text: text,
                lineSpacing: resolvedHeadingSpacing,
                needsVerticalFixedSize: false
              )
            )
          )
        } else {
          allProse = false
          items.append(.other(block: block, index: index))
        }

      case .bulletedList(let isTight, let listItems):
        allProse = false
        if canCompactList,
          let builtinBullet,
          let paragraphs = BulletedListView.extractSimpleParagraphItems(listItems)
        {
          items.append(
            .bulletedList(
              paragraphs: paragraphs,
              isTight: isTight,
              builtinMarker: builtinBullet
            )
          )
        } else {
          items.append(.other(block: block, index: index))
        }

      case .codeBlock(let fenceInfo, let content):
        allProse = false
        items.append(.codeBlock(fenceInfo: fenceInfo, content: content, index: index))

      case .table(let columnAlignments, let rows):
        allProse = false
        items.append(.table(columnAlignments: columnAlignments, rows: rows, index: index))

      case .thematicBreak:
        allProse = false
        items.append(.thematicBreak)

      default:
        allProse = false
        items.append(.other(block: block, index: index))
      }
    }

    return self.makeSequenceBody(
      items: items,
      allProse: allProse,
      paragraphLineSpacing: paragraphStyle.paragraphLineSpacing
    )
  }

  @ViewBuilder private func makeSequenceBody(
    items: [DirectItem],
    allProse: Bool,
    paragraphLineSpacing: RelativeSize?
  ) -> some View {
    if items.count == 1 {
      self.singleItemView(items[0], paragraphLineSpacing: paragraphLineSpacing)
    } else if allProse {
      BlockSpacedStackLayout(
        alignment: self.textAlignment,
        topSpacings: self.topSpacings
      ) {
        StaticViewBatch(count: items.count) { index in
          if case .prose(let prose) = items[index] {
            prose.text.lineSpacing(prose.lineSpacing)
          }
        }
      }
    } else {
      BlockSpacedStackLayout(
        alignment: self.textAlignment,
        topSpacings: self.topSpacings
      ) {
        StaticViewBatch(count: items.count) { index in
          self.mixedItemView(items[index], paragraphLineSpacing: paragraphLineSpacing)
        }
      }
    }
  }

  @ViewBuilder private func singleItemView(
    _ item: DirectItem,
    paragraphLineSpacing: RelativeSize?
  ) -> some View {
    switch item {
    case .prose(let prose):
      if prose.needsVerticalFixedSize {
        prose.text
          .fixedSize(horizontal: false, vertical: true)
          .lineSpacing(prose.lineSpacing)
      } else {
        prose.text.lineSpacing(prose.lineSpacing)
      }
    default:
      self.mixedItemView(item, paragraphLineSpacing: paragraphLineSpacing)
    }
  }

  @ViewBuilder private func mixedItemView(
    _ item: DirectItem,
    paragraphLineSpacing: RelativeSize?
  ) -> some View {
    switch item {
    case .prose(let prose):
      prose.text.lineSpacing(prose.lineSpacing)
    case let .bulletedList(paragraphs, isTight, builtinMarker):
      CompactBulletedListView(
        paragraphs: paragraphs,
        isTight: isTight,
        nextListLevel: 1,
        builtinMarker: builtinMarker,
        margins: self.margins,
        paragraphLineSpacing: paragraphLineSpacing
      )
    case let .codeBlock(fenceInfo, content, index):
      CodeBlockView(fenceInfo: fenceInfo, content: content)
        .environment(\.markdownBlockPath, self.blockPath + [index])
    case let .table(columnAlignments, rows, index):
      TableView(columnAlignments: columnAlignments, rows: rows)
        .environment(\.markdownBlockPath, self.blockPath + [index])
    case .thematicBreak:
      self.theme.thematicBreak.makeBody(configuration: ())
    case let .other(block, index):
      block
        .environment(\.markdownBlockPath, self.blockPath + [index])
    }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct BlockSpacedStackLayout: Layout {
  let alignment: TextAlignment
  let topSpacings: [CGFloat]

  struct Cache {
    var key: CacheKey?
    var itemSizes: [CGSize] = []
    var size: CGSize = .zero
  }

  struct CacheKey: Equatable {
    let subviewCount: Int
    let availableWidth: CGFloat?
    let topSpacings: [CGFloat]
    let alignment: TextAlignment
  }

  func makeCache(subviews: Subviews) -> Cache {
    Cache()
  }

  func updateCache(_ cache: inout Cache, subviews: Subviews) {
    cache = Cache()
  }

  func explicitAlignment(
    of guide: HorizontalAlignment,
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) -> CGFloat? {
    nil
  }

  func explicitAlignment(
    of guide: VerticalAlignment,
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) -> CGFloat? {
    nil
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
    self.resolve(
      proposalWidth: proposal.width,
      subviews: subviews,
      cache: &cache,
      forceMeasure: true
    )
    return cache.size
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) {
    self.resolve(
      proposalWidth: proposal.width ?? bounds.width,
      subviews: subviews,
      cache: &cache,
      forceMeasure: abs(cache.size.height - bounds.height) >= 0.01
    )
    let proposalWidth = cache.key?.availableWidth
    var y = bounds.minY
    for (index, subview) in subviews.enumerated() {
      if index > 0, index < self.topSpacings.count {
        y += self.topSpacings[index]
      }
      let itemSize = cache.itemSizes[index]
      let itemProposal = ProposedViewSize(width: proposalWidth, height: itemSize.height)
      switch self.alignment {
      case .leading:
        subview.place(
          at: CGPoint(x: bounds.minX, y: y),
          anchor: .topLeading,
          proposal: itemProposal
        )
      case .center:
        subview.place(
          at: CGPoint(x: bounds.midX, y: y),
          anchor: .top,
          proposal: itemProposal
        )
      case .trailing:
        subview.place(
          at: CGPoint(x: bounds.maxX, y: y),
          anchor: .topTrailing,
          proposal: itemProposal
        )
      }
      y += itemSize.height
    }
  }

  private func resolve(
    proposalWidth: CGFloat?,
    subviews: Subviews,
    cache: inout Cache,
    forceMeasure: Bool
  ) {
    let normalizedWidth: CGFloat? =
      if let w = proposalWidth, w.isFinite { w } else { nil }
    let key = CacheKey(
      subviewCount: subviews.count,
      availableWidth: normalizedWidth,
      topSpacings: self.topSpacings,
      alignment: self.alignment
    )
    if !forceMeasure, cache.key == key {
      return
    }
    guard !subviews.isEmpty else {
      cache.key = key
      cache.itemSizes = []
      cache.size = .zero
      return
    }
    let itemProposal = ProposedViewSize(width: normalizedWidth, height: nil)
    var sizes: [CGSize] = []
    sizes.reserveCapacity(subviews.count)
    var maxWidth: CGFloat = 0
    var totalHeight: CGFloat = 0
    for (index, subview) in subviews.enumerated() {
      if index > 0, index < self.topSpacings.count {
        totalHeight += self.topSpacings[index]
      }
      let measured = subview.sizeThatFits(itemProposal)
      sizes.append(measured)
      maxWidth = max(maxWidth, measured.width)
      totalHeight += measured.height
    }
    cache.key = key
    cache.itemSizes = sizes
    cache.size = CGSize(width: maxWidth, height: totalHeight)
  }
}

extension BlockSequence where Data == [BlockNode], Content == BlockNode {
  init(_ blocks: [BlockNode]) {
    self.init(rawBlocks: blocks) { $1 }
  }
}

extension TextAlignment {
  var alignment: Alignment {
    switch self {
    case .leading:
      return .leading
    case .center:
      return .center
    case .trailing:
      return .trailing
    }
  }
}
