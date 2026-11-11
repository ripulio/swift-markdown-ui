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

  let paragraphs: [[InlineNode]]
  let margins: MarkdownBlockMargins
  let textAlignment: TextAlignment
  let tightSpacingEnabled: Bool
  let paragraphLineSpacing: RelativeSize?

  var body: some View {
    let cache = PrecomputedInlineAttributes(
      attributes: self.textStyleAttributes,
      inlineStyles: self.inlineStyles
    )
    let resolvedLineSpacing = self.paragraphLineSpacing?.points(
      relativeTo: self.textStyleAttributes.fontProperties
    )

    if self.paragraphs.count == 1 {
      let single = self.paragraphItem(
        at: 0,
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
      let stack = ParagraphStackLayout(
        alignment: self.textAlignment,
        spacing: spacing
      ) {
        ForEach(self.paragraphs.indices, id: \.self) { index in
          self.paragraphItem(
            at: index,
            cache: cache,
            chunkSpacing: resolvedLineSpacing ?? self.environmentLineSpacing
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
  }

  @ViewBuilder private func paragraphItem(
    at index: Int,
    cache: PrecomputedInlineAttributes,
    chunkSpacing: CGFloat
  ) -> some View {
    let inlines = self.paragraphs[index]
    let chunks = inlines.textChunks(softBreakMode: self.softBreakMode)
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
    self.resolve(proposalWidth: proposal.width, subviews: subviews, cache: &cache)
    return cache.size
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) {
    if cache.key?.subviewCount != subviews.count
      || abs(cache.size.width - bounds.width) >= 0.01
      || abs(cache.size.height - bounds.height) >= 0.01
    {
      self.resolve(proposalWidth: proposal.width ?? bounds.width, subviews: subviews, cache: &cache)
    }
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

  private func resolve(proposalWidth: CGFloat?, subviews: Subviews, cache: inout Cache) {
    let normalizedWidth: CGFloat? =
      if let w = proposalWidth, w.isFinite { w } else { nil }
    let key = CacheKey(
      subviewCount: subviews.count,
      availableWidth: normalizedWidth,
      spacing: self.spacing,
      alignment: self.alignment
    )
    if cache.key == key {
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
