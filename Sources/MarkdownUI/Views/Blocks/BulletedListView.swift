import SwiftUI

struct BulletedListView: View {
  @Environment(\.theme) private var theme
  @Environment(\.listLevel) private var listLevel
  @Environment(\.markdownBlockMargins) private var staticBlockMargins
  @Environment(\.isInsideDynamicBlockSequence) private var isInsideDynamicBlockSequence
  @Environment(\.textStyleAttributes) private var textStyleAttributes

  private let isTight: Bool
  private let items: [RawListItem]

  init(isTight: Bool, items: [RawListItem]) {
    self.isTight = isTight
    self.items = items
  }

  private var effectiveMargins: MarkdownBlockMargins? {
    if let staticBlockMargins = self.staticBlockMargins {
      return staticBlockMargins
    }
    guard !self.isInsideDynamicBlockSequence,
      self.theme.list.hasDeclarativeMargin,
      self.items.allSatisfy({ $0.supportsDeclarativeMargins(in: self.theme) })
    else {
      return nil
    }
    return self.theme.resolveDeclarativeMargins(
      relativeTo: self.textStyleAttributes.fontProperties
    )
  }

  var body: some View {
    if self.theme.list.isIdentity {
      if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *),
        self.theme.listItem.isIdentity || self.theme.listItem.isMarginOnly,
        let builtin = self.theme.bulletedListMarker.builtinBulletMarker,
        let margins = self.effectiveMargins,
        self.theme.paragraph.paragraphLineSpacing != nil || self.theme.paragraph.isIdentity,
        let paragraphs = self.simpleParagraphItems
      {
        CompactBulletedListView(
          paragraphs: paragraphs,
          isTight: self.isTight,
          nextListLevel: self.listLevel + 1,
          builtinMarker: builtin,
          margins: margins,
          paragraphLineSpacing: self.theme.paragraph.paragraphLineSpacing
        )
      } else {
        self.label
      }
    } else {
      self.theme.list.makeBody(
        configuration: .init(
          label: .init(self.label),
          content: .init(block: .bulletedList(isTight: self.isTight, items: self.items))
        )
      )
    }
  }

  /// Extracts inline arrays when every list item is a single non-image paragraph.
  static func extractSimpleParagraphItems(_ items: [RawListItem]) -> [[InlineNode]]? {
    var result: [[InlineNode]] = []
    result.reserveCapacity(items.count)
    for item in items {
      guard item.children.count == 1,
        case .paragraph(let inlines) = item.children[0],
        !inlines.contains(where: \.containsImage)
      else {
        return nil
      }
      result.append(inlines)
    }
    return result
  }

  private var simpleParagraphItems: [[InlineNode]]? {
    Self.extractSimpleParagraphItems(self.items)
  }

  private var label: some View {
    ListItemSequence(
      items: self.items,
      markerStyle: self.theme.bulletedListMarker,
      readsMarkerWidth: false
    )
    .environment(\.listLevel, self.listLevel + 1)
    .environment(\.tightSpacingEnabled, self.isTight)
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct CompactBulletedListView: View {
  @Environment(\.textStyleAttributes) private var textStyleAttributes
  @Environment(\.theme.inlineTextStyles) private var inlineStyles
  @Environment(\.baseURL) private var baseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.lineSpacing) private var environmentLineSpacing
  @Environment(\.multilineTextAlignment) private var textAlignment
  @Environment(\.displayScale) private var displayScale

  let paragraphs: [[InlineNode]]
  let isTight: Bool
  let nextListLevel: Int
  let builtinMarker: BlockStyle<ListMarkerConfiguration>.BuiltinBulletMarker
  let margins: MarkdownBlockMargins
  let paragraphLineSpacing: RelativeSize?

  var body: some View {
    let fontProperties = self.textStyleAttributes.fontProperties
    let fontSize = fontProperties?.scaledSize ?? FontProperties.defaultSize
    let bulletImage = ListBullet.builtinImage(for: self.builtinMarker, listLevel: self.nextListLevel)
    let bulletFont = Font.system(size: round(fontSize / 3))
    let minBulletWidth = round(1.5 * fontSize)
    let effectiveItemMargin = self.margins.listItem.combined(with: self.margins.paragraph)
    let itemSpacing =
      BlockMargin.max(
        effectiveItemMargin.top,
        self.isTight ? 0 : effectiveItemMargin.bottom
      ) ?? 0
    let cache = InlineAttributesCache.lookup(
      attributes: self.textStyleAttributes,
      inlineStyles: self.inlineStyles
    )
    let probeKey = BulletProbeKey(
      symbolVariant: Self.symbolVariant(for: self.builtinMarker, listLevel: self.nextListLevel),
      fontSize: fontSize,
      minBulletWidth: minBulletWidth,
      fontProperties: fontProperties,
      baselineOffset: self.textStyleAttributes.baselineOffset,
      displayScale: self.displayScale
    )
    let cachedProbe = BulletProbeMetricsCache.lookup(probeKey)

    let listBody = self.makeListBody(
      bulletImage: bulletImage,
      bulletFont: bulletFont,
      minBulletWidth: minBulletWidth,
      itemSpacing: itemSpacing,
      cache: cache,
      probeKey: probeKey,
      cachedProbe: cachedProbe
    )

    if let paragraphLineSpacing = self.paragraphLineSpacing {
      listBody.lineSpacing(
        paragraphLineSpacing.points(relativeTo: fontProperties)
      )
    } else {
      listBody
    }
  }

  private static func symbolVariant(
    for marker: BlockStyle<ListMarkerConfiguration>.BuiltinBulletMarker,
    listLevel: Int
  ) -> Int {
    switch marker {
    case .disc:
      return 0
    case .circle:
      return 1
    case .square:
      return 2
    case .discCircleSquare:
      switch min(listLevel, 3) {
      case 1: return 0
      case 2: return 1
      default: return 2
      }
    }
  }

  @ViewBuilder private func makeListBody(
    bulletImage: Image,
    bulletFont: Font,
    minBulletWidth: CGFloat,
    itemSpacing: CGFloat,
    cache: PrecomputedInlineAttributes,
    probeKey: BulletProbeKey,
    cachedProbe: BulletProbeMetrics?
  ) -> some View {
    if !self.paragraphs.contains(where: { $0.hasMultipleTextChunks(softBreakMode: self.softBreakMode) }) {
      if let cachedProbe {
        BulletedListLayout(
          minBulletWidth: minBulletWidth,
          itemSpacing: itemSpacing,
          probeKey: probeKey,
          cachedProbe: cachedProbe,
          hasLeadingProbeSubview: false
        ) {
          StaticViewBatch(count: self.paragraphs.count) { index in
            bulletImage.font(bulletFont)
            self.paragraphs[index].renderCompactText(
              baseURL: self.baseURL,
              softBreakMode: self.softBreakMode,
              cache: cache
            )
          }
        }
      } else {
        BulletedListLayout(
          minBulletWidth: minBulletWidth,
          itemSpacing: itemSpacing,
          probeKey: probeKey,
          cachedProbe: nil,
          hasLeadingProbeSubview: true
        ) {
          Label {
            cache.directBase.makeText("A")
          } icon: {
            bulletImage
              .font(bulletFont)
              .frame(minWidth: minBulletWidth, minHeight: 100, alignment: .topTrailing)
          }
          .hidden()
          StaticViewBatch(count: self.paragraphs.count) { index in
            bulletImage.font(bulletFont)
            self.paragraphs[index].renderCompactText(
              baseURL: self.baseURL,
              softBreakMode: self.softBreakMode,
              cache: cache
            )
          }
        }
      }
    } else {
      let itemChunks = self.paragraphs.map { $0.textChunks(softBreakMode: self.softBreakMode) }
      self.makeListLayout(
        bulletImage: bulletImage,
        bulletFont: bulletFont,
        minBulletWidth: minBulletWidth,
        itemSpacing: itemSpacing,
        cache: cache,
        probeKey: probeKey,
        cachedProbe: cachedProbe,
        itemChunks: itemChunks
      )
    }
  }

  @ViewBuilder private func makeListLayout(
    bulletImage: Image,
    bulletFont: Font,
    minBulletWidth: CGFloat,
    itemSpacing: CGFloat,
    cache: PrecomputedInlineAttributes,
    probeKey: BulletProbeKey,
    cachedProbe: BulletProbeMetrics?,
    itemChunks: [[[InlineNode]]]
  ) -> some View {
    if let cachedProbe {
      BulletedListLayout(
        minBulletWidth: minBulletWidth,
        itemSpacing: itemSpacing,
        probeKey: probeKey,
        cachedProbe: cachedProbe,
        hasLeadingProbeSubview: false
      ) {
        ForEach(itemChunks.indices, id: \.self) { index in
          bulletImage.font(bulletFont)
          self.chunkedItemText(chunks: itemChunks[index], cache: cache)
        }
      }
    } else {
      BulletedListLayout(
        minBulletWidth: minBulletWidth,
        itemSpacing: itemSpacing,
        probeKey: probeKey,
        cachedProbe: nil,
        hasLeadingProbeSubview: true
      ) {
        Label {
          cache.directBase.makeText("A")
        } icon: {
          bulletImage
            .font(bulletFont)
            .frame(minWidth: minBulletWidth, minHeight: 100, alignment: .topTrailing)
        }
        .hidden()
        ForEach(itemChunks.indices, id: \.self) { index in
          bulletImage.font(bulletFont)
          self.chunkedItemText(chunks: itemChunks[index], cache: cache)
        }
      }
    }
  }

  @ViewBuilder private func chunkedItemText(
    chunks: [[InlineNode]],
    cache: PrecomputedInlineAttributes
  ) -> some View {
    if chunks.count == 1 {
      chunks[0].renderCompactText(
        baseURL: self.baseURL,
        softBreakMode: self.softBreakMode,
        cache: cache
      )
    } else {
      VStack(
        alignment: self.textAlignment.alignment.horizontal,
        spacing: self.paragraphLineSpacing?.points(relativeTo: self.textStyleAttributes.fontProperties)
          ?? self.environmentLineSpacing
      ) {
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
