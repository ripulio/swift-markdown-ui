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
  @Environment(\.isInsideDynamicBlockSequence) private var isInsideDynamicBlockSequence
  @Environment(\.inlineImageFlow) private var inlineImageFlow
  @Environment(\.listLevel) private var listLevel
  @Environment(\.theme) private var theme
  @Environment(\.textStyleAttributes) private var textStyleAttributes

  private let elements: [Data.Element]
  private let content: (Int, Data.Element) -> Content
  private let rawBlocks: [BlockNode]?

  init(
    _ data: Data,
    @ViewBuilder content: @escaping (_ index: Int, _ element: Data.Element) -> Content
  ) {
    self.elements = Array(data)
    self.content = content
    self.rawBlocks = nil
  }

  fileprivate init(
    rawBlocks: [BlockNode],
    @ViewBuilder content: @escaping (_ index: Int, _ element: Data.Element) -> Content
  ) {
    self.elements = []
    self.content = content
    self.rawBlocks = rawBlocks
  }

  private var indexedData: [Indexed<Data.Element>] {
    if let rawBlocks = self.rawBlocks {
      return rawBlocks.indexed() as! [Indexed<Data.Element>]
    }
    return self.elements.indexed()
  }

  private var effectiveMargins: MarkdownBlockMargins? {
    if let staticBlockMargins = self.staticBlockMargins {
      return staticBlockMargins
    }
    guard !self.isInsideDynamicBlockSequence else {
      return nil
    }
    if let rawBlocks = self.rawBlocks {
      guard rawBlocks.allSatisfy({ $0.supportsDeclarativeMargins(in: self.theme) }) else {
        return nil
      }
    } else {
      guard self.elements.allSatisfy({ $0.supportsDeclarativeMargins(in: self.theme) }) else {
        return nil
      }
    }
    return self.theme.resolveDeclarativeMargins(
      relativeTo: self.textStyleAttributes.fontProperties
    )
  }

  var body: some View {
    if let effectiveMargins = self.effectiveMargins {
      if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *),
        self.theme.paragraph.paragraphLineSpacing != nil || self.theme.paragraph.isIdentity,
        let rawBlocks = self.rawBlocks,
        let paragraphs = Self.simpleParagraphBlocks(rawBlocks)
      {
        CompactParagraphSequenceView(
          paragraphs: paragraphs,
          margins: effectiveMargins,
          textAlignment: self.textAlignment,
          tightSpacingEnabled: self.tightSpacingEnabled,
          paragraphLineSpacing: self.theme.paragraph.paragraphLineSpacing
        )
      } else if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *),
        self.listLevel == 0,
        let rawBlocks = self.rawBlocks,
        !rawBlocks.isEmpty,
        let topSpacings = DirectBlockSequenceView.computeTopSpacings(
          rawBlocks: rawBlocks,
          margins: effectiveMargins,
          inlineImageFlow: self.inlineImageFlow,
          tightSpacingEnabled: self.tightSpacingEnabled
        )
      {
        DirectBlockSequenceView(
          rawBlocks: rawBlocks,
          topSpacings: topSpacings,
          margins: effectiveMargins,
          textAlignment: self.textAlignment,
          blockPath: self.blockPath
        )
      } else {
        StaticBlockSequenceContent(
          data: self.indexedData,
          content: self.content,
          margins: effectiveMargins,
          inlineImageFlow: self.inlineImageFlow,
          textAlignment: self.textAlignment,
          tightSpacingEnabled: self.tightSpacingEnabled,
          blockPath: self.blockPath
        )
        .environment(\.usesDeclarativeBlockMargins, true)
      }
    } else {
      DynamicBlockSequenceContent(
        data: self.indexedData,
        content: self.content,
        textAlignment: self.textAlignment,
        tightSpacingEnabled: self.tightSpacingEnabled,
        blockPath: self.blockPath
      )
      .environment(\.isInsideDynamicBlockSequence, true)
      .environment(\.usesDeclarativeBlockMargins, false)
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

  var body: some View {
    if self.data.count == 1 {
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
private struct CompactTextStyleKey: Equatable {
  let attributes: AttributeContainer
  let inlineStylesRevision: UInt64
  let ignoredBackgroundColor: Color?
  let baseURL: URL?
  let softBreakMode: SoftBreak.Mode
  let dynamicTypeSize: DynamicTypeSize
  let legibilityWeight: LegibilityWeight?
  let lineLimit: Int?
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct DirectStyleFingerprint: Equatable {
  let attributes: AttributeContainer
  let inlineStylesRevision: UInt64
  let ignoredBackgroundColor: Color?
  let baseURL: URL?
  let softBreakMode: SoftBreak.Mode
  let dynamicTypeSize: DynamicTypeSize
  let legibilityWeight: LegibilityWeight?
  let lineLimit: Int?
  let environmentLineSpacing: CGFloat
  let displayScale: CGFloat
  let theme: Theme
  let margins: MarkdownBlockMargins
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct EquatableParagraphTextView: View, Equatable {
  let inlines: [InlineNode]
  let styleKey: CompactTextStyleKey
  let inlineStyles: InlineTextStyles

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.inlines == rhs.inlines && lhs.styleKey == rhs.styleKey
  }

  var body: some View {
    let cache = InlineAttributesCache.lookup(
      attributes: self.styleKey.attributes,
      inlineStyles: self.inlineStyles,
      ignoredBackgroundColor: self.styleKey.ignoredBackgroundColor
    )
    self.inlines.renderCompactText(
      baseURL: self.styleKey.baseURL,
      softBreakMode: self.styleKey.softBreakMode,
      cache: cache
    )
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct CompactParagraphSequenceView: View {
  @Environment(\.textStyleAttributes) private var textStyleAttributes
  @Environment(\.rootTextBackgroundColor) private var rootTextBackgroundColor
  @Environment(\.theme.inlineTextStyles) private var inlineStyles
  @Environment(\.baseURL) private var baseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.lineSpacing) private var environmentLineSpacing
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.legibilityWeight) private var legibilityWeight
  @Environment(\.lineLimit) private var lineLimit

  let paragraphs: [[InlineNode]]
  let margins: MarkdownBlockMargins
  let textAlignment: TextAlignment
  let tightSpacingEnabled: Bool
  let paragraphLineSpacing: RelativeSize?

  var body: some View {
    let styleKey = CompactTextStyleKey(
      attributes: self.textStyleAttributes,
      inlineStylesRevision: self.inlineStyles.revision,
      ignoredBackgroundColor: self.rootTextBackgroundColor,
      baseURL: self.baseURL,
      softBreakMode: self.softBreakMode,
      dynamicTypeSize: self.dynamicTypeSize,
      legibilityWeight: self.legibilityWeight,
      lineLimit: self.lineLimit
    )
    let resolvedLineSpacing = self.paragraphLineSpacing?.points(
      relativeTo: self.textStyleAttributes.fontProperties
    )

    if !self.paragraphs.contains(where: { $0.hasMultipleTextChunks(softBreakMode: self.softBreakMode) }) {
      if self.paragraphs.count == 1 {
        let single = EquatableParagraphTextView(
          inlines: self.paragraphs[0],
          styleKey: styleKey,
          inlineStyles: self.inlineStyles
        ).equatable()
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
          spacing: spacing,
          paragraphs: self.paragraphs,
          styleKey: styleKey,
          resolvedLineSpacing: resolvedLineSpacing ?? self.environmentLineSpacing
        ) {
          StaticViewBatch(count: self.paragraphs.count) { index in
            EquatableParagraphTextView(
              inlines: self.paragraphs[index],
              styleKey: styleKey,
              inlineStyles: self.inlineStyles
            ).equatable()
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
      let cache = InlineAttributesCache.lookup(
        attributes: self.textStyleAttributes,
        inlineStyles: self.inlineStyles,
        ignoredBackgroundColor: self.rootTextBackgroundColor
      )
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
        let stack = self.makeParagraphStack(
          itemChunks: itemChunks,
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

  private func makeParagraphStack(
    itemChunks: [[[InlineNode]]],
    spacing: CGFloat,
    cache: PrecomputedInlineAttributes,
    chunkSpacing: CGFloat
  ) -> some View {
    ParagraphStackLayout(
      alignment: self.textAlignment,
      spacing: spacing,
      paragraphs: nil,
      styleKey: nil,
      resolvedLineSpacing: chunkSpacing
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
  let paragraphs: [[InlineNode]]?
  let styleKey: CompactTextStyleKey?
  let resolvedLineSpacing: CGFloat

  struct Cache {
    var key: CacheKey?
    var itemSizes: [CGSize] = []
    var size: CGSize = .zero
    var retainedWidth: CGFloat?
    var retainedStyleKey: CompactTextStyleKey?
    var retainedLineSpacing: CGFloat?
    var retainedParagraphs: [[InlineNode]] = []
    var retainedSizes: [CGSize] = []
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
    cache.key = nil
    cache.itemSizes.removeAll(keepingCapacity: true)
    cache.size = .zero
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

    let canReusePrefix =
      self.paragraphs != nil
      && self.styleKey != nil
      && cache.retainedWidth == normalizedWidth
      && cache.retainedStyleKey == self.styleKey
      && cache.retainedLineSpacing == self.resolvedLineSpacing

    let itemProposal = ProposedViewSize(width: normalizedWidth, height: nil)
    var sizes: [CGSize] = []
    sizes.reserveCapacity(subviews.count)
    var maxWidth: CGFloat = 0
    var totalHeight: CGFloat = 0
    for (index, subview) in subviews.enumerated() {
      let measured: CGSize
      if canReusePrefix,
        let paragraphs = self.paragraphs,
        index < paragraphs.count,
        index < cache.retainedParagraphs.count,
        index < cache.retainedSizes.count,
        cache.retainedParagraphs[index] == paragraphs[index]
      {
        measured = cache.retainedSizes[index]
      } else {
        measured = subview.sizeThatFits(itemProposal)
      }
      sizes.append(measured)
      maxWidth = max(maxWidth, measured.width)
      totalHeight += measured.height
    }
    totalHeight += CGFloat(max(0, subviews.count - 1)) * self.spacing
    cache.key = key
    cache.itemSizes = sizes
    cache.size = CGSize(width: maxWidth, height: totalHeight)
    if let paragraphs = self.paragraphs, let styleKey = self.styleKey, paragraphs.count == sizes.count {
      cache.retainedWidth = normalizedWidth
      cache.retainedStyleKey = styleKey
      cache.retainedLineSpacing = self.resolvedLineSpacing
      cache.retainedParagraphs = paragraphs
      cache.retainedSizes = sizes
    }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct DirectProseBlockView: View, Equatable {
  let inlines: [InlineNode]
  let styleKey: CompactTextStyleKey
  let inlineStyles: InlineTextStyles
  let overrideWeight: Font.Weight?
  let overrideSize: RelativeSize?
  let overrideForegroundColor: Color?
  let lineSpacing: CGFloat
  let needsVerticalFixedSize: Bool
  let anchorID: String?

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.inlines == rhs.inlines
      && lhs.styleKey == rhs.styleKey
      && lhs.overrideWeight == rhs.overrideWeight
      && lhs.overrideSize == rhs.overrideSize
      && lhs.overrideForegroundColor == rhs.overrideForegroundColor
      && lhs.lineSpacing == rhs.lineSpacing
      && lhs.needsVerticalFixedSize == rhs.needsVerticalFixedSize
      && lhs.anchorID == rhs.anchorID
  }

  var body: some View {
    let cache = InlineAttributesCache.lookup(
      attributes: self.styleKey.attributes,
      inlineStyles: self.inlineStyles,
      overrideWeight: self.overrideWeight,
      overrideSize: self.overrideSize,
      overrideForegroundColor: self.overrideForegroundColor,
      ignoredBackgroundColor: self.styleKey.ignoredBackgroundColor
    )
    let text = self.inlines.renderCompactText(
      baseURL: self.styleKey.baseURL,
      softBreakMode: self.styleKey.softBreakMode,
      cache: cache
    )
    if self.needsVerticalFixedSize {
      if let anchorID = self.anchorID {
        text
          .fixedSize(horizontal: false, vertical: true)
          .lineSpacing(self.lineSpacing)
          .id(anchorID)
      } else {
        text
          .fixedSize(horizontal: false, vertical: true)
          .lineSpacing(self.lineSpacing)
      }
    } else if let anchorID = self.anchorID {
      text
        .lineSpacing(self.lineSpacing)
        .id(anchorID)
    } else {
      text.lineSpacing(self.lineSpacing)
    }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct EquatableBulletedListBlockView: View, Equatable {
  let paragraphs: [[InlineNode]]
  let isTight: Bool
  let builtinMarker: BlockStyle<ListMarkerConfiguration>.BuiltinBulletMarker
  let margins: MarkdownBlockMargins
  let paragraphLineSpacing: RelativeSize?
  let styleKey: CompactTextStyleKey
  let displayScale: CGFloat

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.paragraphs == rhs.paragraphs
      && lhs.isTight == rhs.isTight
      && lhs.builtinMarker == rhs.builtinMarker
      && lhs.margins == rhs.margins
      && lhs.paragraphLineSpacing == rhs.paragraphLineSpacing
      && lhs.styleKey == rhs.styleKey
      && lhs.displayScale == rhs.displayScale
  }

  var body: some View {
    CompactBulletedListView(
      paragraphs: self.paragraphs,
      isTight: self.isTight,
      nextListLevel: 1,
      builtinMarker: self.builtinMarker,
      margins: self.margins,
      paragraphLineSpacing: self.paragraphLineSpacing
    )
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct EquatableNestedBulletedListBlockView: View, Equatable {
  let rows: [FlattenedBulletRow]
  let builtinMarker: BlockStyle<ListMarkerConfiguration>.BuiltinBulletMarker
  let paragraphLineSpacing: RelativeSize?
  let styleKey: CompactTextStyleKey
  let displayScale: CGFloat

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.rows == rhs.rows
      && lhs.builtinMarker == rhs.builtinMarker
      && lhs.paragraphLineSpacing == rhs.paragraphLineSpacing
      && lhs.styleKey == rhs.styleKey
      && lhs.displayScale == rhs.displayScale
  }

  var body: some View {
    CompactNestedBulletedListView(
      rows: self.rows,
      builtinMarker: self.builtinMarker,
      paragraphLineSpacing: self.paragraphLineSpacing
    )
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct EquatableNumberedListBlockView: View, Equatable {
  let paragraphs: [[InlineNode]]
  let start: Int
  let isTight: Bool
  let builtinMarker: BlockStyle<ListMarkerConfiguration>.BuiltinNumberedMarker
  let margins: MarkdownBlockMargins
  let paragraphLineSpacing: RelativeSize?
  let styleKey: CompactTextStyleKey

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.paragraphs == rhs.paragraphs
      && lhs.start == rhs.start
      && lhs.isTight == rhs.isTight
      && lhs.builtinMarker == rhs.builtinMarker
      && lhs.margins == rhs.margins
      && lhs.paragraphLineSpacing == rhs.paragraphLineSpacing
      && lhs.styleKey == rhs.styleKey
  }

  var body: some View {
    CompactNumberedListView(
      paragraphs: self.paragraphs,
      start: self.start,
      isTight: self.isTight,
      builtinMarker: self.builtinMarker,
      margins: self.margins,
      paragraphLineSpacing: self.paragraphLineSpacing
    )
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct EquatableTaskListBlockView: View, Equatable {
  let items: [RawTaskListItem]
  let isTight: Bool
  let builtinMarker: BlockStyle<TaskListMarkerConfiguration>.BuiltinTaskMarker
  let margins: MarkdownBlockMargins
  let paragraphLineSpacing: RelativeSize?
  let styleKey: CompactTextStyleKey
  let displayScale: CGFloat

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.items == rhs.items
      && lhs.isTight == rhs.isTight
      && lhs.builtinMarker == rhs.builtinMarker
      && lhs.margins == rhs.margins
      && lhs.paragraphLineSpacing == rhs.paragraphLineSpacing
      && lhs.styleKey == rhs.styleKey
      && lhs.displayScale == rhs.displayScale
  }

  var body: some View {
    if let simpleItems = TaskListView.extractSimpleTaskItems(self.items) {
      CompactTaskListView(
        items: simpleItems,
        isTight: self.isTight,
        builtinMarker: self.builtinMarker,
        margins: self.margins,
        paragraphLineSpacing: self.paragraphLineSpacing
      )
    }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct DirectBlockSequenceView: View {
  fileprivate struct ProseItem {
    let inlines: [InlineNode]
    let overrideWeight: Font.Weight?
    let overrideSize: RelativeSize?
    let overrideForegroundColor: Color?
    let lineSpacing: CGFloat
    let needsVerticalFixedSize: Bool
    let anchorID: String?
  }

  fileprivate enum DirectItem {
    case prose(ProseItem)
    case bulletedList(
      paragraphs: [[InlineNode]],
      isTight: Bool,
      builtinMarker: BlockStyle<ListMarkerConfiguration>.BuiltinBulletMarker
    )
    case nestedBulletedList(
      rows: [FlattenedBulletRow],
      builtinMarker: BlockStyle<ListMarkerConfiguration>.BuiltinBulletMarker
    )
    case numberedList(
      paragraphs: [[InlineNode]],
      start: Int,
      isTight: Bool,
      builtinMarker: BlockStyle<ListMarkerConfiguration>.BuiltinNumberedMarker
    )
    case taskList(
      items: [RawTaskListItem],
      isTight: Bool,
      builtinMarker: BlockStyle<TaskListMarkerConfiguration>.BuiltinTaskMarker
    )
    case codeBlock(fenceInfo: String?, content: String, index: Int)
    case table(columnAlignments: [RawTableColumnAlignment], rows: [RawTableRow], index: Int)
    case thematicBreak(index: Int)
    case other(block: BlockNode, index: Int)

    var isStatelessForSizeCache: Bool {
      switch self {
      case .prose, .bulletedList, .nestedBulletedList, .numberedList, .taskList, .thematicBreak:
        return true
      case .codeBlock, .table, .other:
        return false
      }
    }
  }

  @Environment(\.theme) private var theme
  @Environment(\.textStyleAttributes) private var textStyleAttributes
  @Environment(\.rootTextBackgroundColor) private var rootTextBackgroundColor
  @Environment(\.baseURL) private var baseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.lineSpacing) private var environmentLineSpacing
  @Environment(\.displayScale) private var displayScale
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.legibilityWeight) private var legibilityWeight
  @Environment(\.lineLimit) private var lineLimit

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
    case .numberedList(_, _, let items) where !items.isEmpty:
      if BulletedListView.extractSimpleParagraphItems(items) != nil {
        return margins.list.combined(with: margins.listItem).combined(with: margins.paragraph)
      }
      return block.effectiveMargin(using: margins, inlineImageFlow: inlineImageFlow)
    case .taskList(_, let items) where !items.isEmpty:
      if TaskListView.extractSimpleTaskItems(items) != nil {
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
      self.theme.list.isIdentity
      && (self.theme.listItem.isIdentity || self.theme.listItem.isMarginOnly)
      && canDirectParagraph
    let builtinBullet = self.theme.bulletedListMarker.builtinBulletMarker
    let builtinNumbered = self.theme.numberedListMarker.builtinNumberedMarker
    let builtinTask = self.theme.taskListMarker.builtinTaskMarker

    let styleKey = CompactTextStyleKey(
      attributes: self.textStyleAttributes,
      inlineStylesRevision: inlineStyles.revision,
      ignoredBackgroundColor: self.rootTextBackgroundColor,
      baseURL: self.baseURL,
      softBreakMode: self.softBreakMode,
      dynamicTypeSize: self.dynamicTypeSize,
      legibilityWeight: self.legibilityWeight,
      lineLimit: self.lineLimit
    )
    let styleFingerprint = DirectStyleFingerprint(
      attributes: self.textStyleAttributes,
      inlineStylesRevision: inlineStyles.revision,
      ignoredBackgroundColor: self.rootTextBackgroundColor,
      baseURL: self.baseURL,
      softBreakMode: self.softBreakMode,
      dynamicTypeSize: self.dynamicTypeSize,
      legibilityWeight: self.legibilityWeight,
      lineLimit: self.lineLimit,
      environmentLineSpacing: self.environmentLineSpacing,
      displayScale: self.displayScale,
      theme: self.theme,
      margins: self.margins
    )

    var items: [DirectItem] = []
    items.reserveCapacity(self.rawBlocks.count)
    var statelessFlags: [Bool] = []
    statelessFlags.reserveCapacity(self.rawBlocks.count)
    var allProse = true

    for (index, block) in self.rawBlocks.enumerated() {
      let item: DirectItem
      switch block {
      case .paragraph(let inlines)
      where canDirectParagraph
        && !inlines.contains(where: \.containsImage)
        && !inlines.hasMultipleTextChunks(softBreakMode: self.softBreakMode):
        item = .prose(
          ProseItem(
            inlines: inlines,
            overrideWeight: nil,
            overrideSize: nil,
            overrideForegroundColor: nil,
            lineSpacing: resolvedParagraphLineSpacing ?? self.environmentLineSpacing,
            needsVerticalFixedSize: resolvedParagraphLineSpacing != nil,
            anchorID: nil
          )
        )

      case .heading(let level, let inlines):
        let headingStyle = self.theme.headings[level - 1]
        if (headingStyle.headingSpec != nil || headingStyle.isIdentity),
          !inlines.contains(where: \.containsImage),
          !inlines.hasMultipleTextChunks(softBreakMode: self.softBreakMode)
        {
          let spec = headingStyle.headingSpec
          let resolvedHeadingSpacing =
            spec?.resolvedLineSpacing(relativeTo: fontProperties) ?? self.environmentLineSpacing
          let anchorID =
            (spec?.attachesAnchorID == true) ? inlines.renderPlainText().kebabCased() : nil
          item = .prose(
            ProseItem(
              inlines: inlines,
              overrideWeight: spec?.fontWeight,
              overrideSize: spec?.fontSize,
              overrideForegroundColor: spec?.foregroundColor,
              lineSpacing: resolvedHeadingSpacing,
              needsVerticalFixedSize: false,
              anchorID: anchorID
            )
          )
        } else {
          allProse = false
          item = .other(block: block, index: index)
        }

      case .bulletedList(let isTight, let listItems):
        allProse = false
        if canCompactList, let builtinBullet {
          if let paragraphs = BulletedListView.extractSimpleParagraphItems(listItems) {
            item = .bulletedList(
              paragraphs: paragraphs,
              isTight: isTight,
              builtinMarker: builtinBullet
            )
          } else if let flattened = BulletedListView.extractFlattenedBulletItems(
            listItems,
            isTight: isTight,
            baseListLevel: 1,
            margins: self.margins
          ),
            !flattened.contains(where: { $0.inlines.hasMultipleTextChunks(softBreakMode: self.softBreakMode) })
          {
            item = .nestedBulletedList(
              rows: flattened,
              builtinMarker: builtinBullet
            )
          } else {
            item = .other(block: block, index: index)
          }
        } else {
          item = .other(block: block, index: index)
        }

      case .numberedList(let isTight, let start, let listItems):
        allProse = false
        if canCompactList,
          let builtinNumbered,
          let paragraphs = BulletedListView.extractSimpleParagraphItems(listItems)
        {
          item = .numberedList(
            paragraphs: paragraphs,
            start: start,
            isTight: isTight,
            builtinMarker: builtinNumbered
          )
        } else {
          item = .other(block: block, index: index)
        }

      case .taskList(let isTight, let taskItems):
        allProse = false
        if canCompactList,
          let builtinTask,
          let simpleTasks = TaskListView.extractSimpleTaskItems(taskItems),
          !simpleTasks.contains(where: { $0.inlines.hasMultipleTextChunks(softBreakMode: self.softBreakMode) })
        {
          item = .taskList(
            items: taskItems,
            isTight: isTight,
            builtinMarker: builtinTask
          )
        } else {
          item = .other(block: block, index: index)
        }

      case .codeBlock(let fenceInfo, let content):
        allProse = false
        item = .codeBlock(fenceInfo: fenceInfo, content: content, index: index)

      case .table(let columnAlignments, let rows):
        allProse = false
        item = .table(columnAlignments: columnAlignments, rows: rows, index: index)

      case .thematicBreak:
        allProse = false
        item = .thematicBreak(index: index)

      default:
        allProse = false
        item = .other(block: block, index: index)
      }
      items.append(item)
      statelessFlags.append(item.isStatelessForSizeCache)
    }

    return self.makeSequenceBody(
      items: items,
      statelessFlags: statelessFlags,
      allProse: allProse,
      paragraphLineSpacing: paragraphStyle.paragraphLineSpacing,
      styleKey: styleKey,
      styleFingerprint: styleFingerprint,
      inlineStyles: inlineStyles
    )
  }

  @ViewBuilder private func makeSequenceBody(
    items: [DirectItem],
    statelessFlags: [Bool],
    allProse: Bool,
    paragraphLineSpacing: RelativeSize?,
    styleKey: CompactTextStyleKey,
    styleFingerprint: DirectStyleFingerprint,
    inlineStyles: InlineTextStyles
  ) -> some View {
    if items.count == 1 {
      self.singleItemView(
        items[0],
        paragraphLineSpacing: paragraphLineSpacing,
        styleKey: styleKey,
        inlineStyles: inlineStyles
      )
    } else if allProse {
      BlockSpacedStackLayout(
        alignment: self.textAlignment,
        topSpacings: self.topSpacings,
        rawBlocks: self.rawBlocks,
        statelessFlags: statelessFlags,
        styleFingerprint: styleFingerprint
      ) {
        StaticViewBatch(count: items.count) { index in
          if case .prose(let prose) = items[index] {
            DirectProseBlockView(
              inlines: prose.inlines,
              styleKey: styleKey,
              inlineStyles: inlineStyles,
              overrideWeight: prose.overrideWeight,
              overrideSize: prose.overrideSize,
              overrideForegroundColor: prose.overrideForegroundColor,
              lineSpacing: prose.lineSpacing,
              needsVerticalFixedSize: false,
              anchorID: prose.anchorID
            ).equatable()
          }
        }
      }
    } else {
      BlockSpacedStackLayout(
        alignment: self.textAlignment,
        topSpacings: self.topSpacings,
        rawBlocks: self.rawBlocks,
        statelessFlags: statelessFlags,
        styleFingerprint: styleFingerprint
      ) {
        StaticViewBatch(count: items.count) { index in
          self.mixedItemView(
            items[index],
            paragraphLineSpacing: paragraphLineSpacing,
            styleKey: styleKey,
            inlineStyles: inlineStyles
          )
        }
      }
      .environment(\.usesDeclarativeBlockMargins, true)
    }
  }

  @ViewBuilder private func singleItemView(
    _ item: DirectItem,
    paragraphLineSpacing: RelativeSize?,
    styleKey: CompactTextStyleKey,
    inlineStyles: InlineTextStyles
  ) -> some View {
    switch item {
    case .prose(let prose):
      DirectProseBlockView(
        inlines: prose.inlines,
        styleKey: styleKey,
        inlineStyles: inlineStyles,
        overrideWeight: prose.overrideWeight,
        overrideSize: prose.overrideSize,
        overrideForegroundColor: prose.overrideForegroundColor,
        lineSpacing: prose.lineSpacing,
        needsVerticalFixedSize: prose.needsVerticalFixedSize,
        anchorID: prose.anchorID
      ).equatable()
    default:
      self.mixedItemView(
        item,
        paragraphLineSpacing: paragraphLineSpacing,
        styleKey: styleKey,
        inlineStyles: inlineStyles
      )
      .environment(\.usesDeclarativeBlockMargins, true)
    }
  }

  @ViewBuilder private func mixedItemView(
    _ item: DirectItem,
    paragraphLineSpacing: RelativeSize?,
    styleKey: CompactTextStyleKey,
    inlineStyles: InlineTextStyles
  ) -> some View {
    switch item {
    case .prose(let prose):
      DirectProseBlockView(
        inlines: prose.inlines,
        styleKey: styleKey,
        inlineStyles: inlineStyles,
        overrideWeight: prose.overrideWeight,
        overrideSize: prose.overrideSize,
        overrideForegroundColor: prose.overrideForegroundColor,
        lineSpacing: prose.lineSpacing,
        needsVerticalFixedSize: false,
        anchorID: prose.anchorID
      ).equatable()
    case let .bulletedList(paragraphs, isTight, builtinMarker):
      EquatableBulletedListBlockView(
        paragraphs: paragraphs,
        isTight: isTight,
        builtinMarker: builtinMarker,
        margins: self.margins,
        paragraphLineSpacing: paragraphLineSpacing,
        styleKey: styleKey,
        displayScale: self.displayScale
      ).equatable()
    case let .nestedBulletedList(rows, builtinMarker):
      EquatableNestedBulletedListBlockView(
        rows: rows,
        builtinMarker: builtinMarker,
        paragraphLineSpacing: paragraphLineSpacing,
        styleKey: styleKey,
        displayScale: self.displayScale
      ).equatable()
    case let .numberedList(paragraphs, start, isTight, builtinMarker):
      EquatableNumberedListBlockView(
        paragraphs: paragraphs,
        start: start,
        isTight: isTight,
        builtinMarker: builtinMarker,
        margins: self.margins,
        paragraphLineSpacing: paragraphLineSpacing,
        styleKey: styleKey
      ).equatable()
    case let .taskList(items, isTight, builtinMarker):
      EquatableTaskListBlockView(
        items: items,
        isTight: isTight,
        builtinMarker: builtinMarker,
        margins: self.margins,
        paragraphLineSpacing: paragraphLineSpacing,
        styleKey: styleKey,
        displayScale: self.displayScale
      ).equatable()
    case let .codeBlock(fenceInfo, content, index):
      CodeBlockView(fenceInfo: fenceInfo, content: content)
        .equatable()
        .environment(\.markdownBlockPath, self.blockPath + [index])
    case let .table(columnAlignments, rows, index):
      TableView(columnAlignments: columnAlignments, rows: rows)
        .equatable()
        .environment(\.markdownBlockPath, self.blockPath + [index])
    case let .thematicBreak(index):
      self.theme.thematicBreak.makeBody(configuration: ())
        .environment(\.markdownBlockPath, self.blockPath + [index])
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
  let rawBlocks: [BlockNode]
  let statelessFlags: [Bool]
  let styleFingerprint: DirectStyleFingerprint

  struct Cache {
    var key: CacheKey?
    var itemSizes: [CGSize] = []
    var size: CGSize = .zero
    var retainedWidth: CGFloat?
    var retainedStyleFingerprint: DirectStyleFingerprint?
    var retainedBlocks: [BlockNode] = []
    var retainedSizes: [CGSize] = []
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
    cache.key = nil
    cache.itemSizes.removeAll(keepingCapacity: true)
    cache.size = .zero
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

    let canReusePrefix =
      cache.retainedWidth == normalizedWidth
      && cache.retainedStyleFingerprint == self.styleFingerprint

    let itemProposal = ProposedViewSize(width: normalizedWidth, height: nil)
    var sizes: [CGSize] = []
    sizes.reserveCapacity(subviews.count)
    var maxWidth: CGFloat = 0
    var totalHeight: CGFloat = 0
    for (index, subview) in subviews.enumerated() {
      if index > 0, index < self.topSpacings.count {
        totalHeight += self.topSpacings[index]
      }
      let measured: CGSize
      if canReusePrefix,
        index < self.statelessFlags.count,
        self.statelessFlags[index],
        index < self.rawBlocks.count,
        index < cache.retainedBlocks.count,
        index < cache.retainedSizes.count,
        cache.retainedBlocks[index] == self.rawBlocks[index]
      {
        measured = cache.retainedSizes[index]
      } else {
        measured = subview.sizeThatFits(itemProposal)
      }
      sizes.append(measured)
      maxWidth = max(maxWidth, measured.width)
      totalHeight += measured.height
    }
    cache.key = key
    cache.itemSizes = sizes
    cache.size = CGSize(width: maxWidth, height: totalHeight)
    if self.rawBlocks.count == sizes.count {
      cache.retainedWidth = normalizedWidth
      cache.retainedStyleFingerprint = self.styleFingerprint
      cache.retainedBlocks = self.rawBlocks
      cache.retainedSizes = sizes
    }
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
