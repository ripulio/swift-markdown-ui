import SwiftUI

struct BulletedListView: View {
  @Environment(\.theme.list) private var list
  @Environment(\.theme.listItem) private var listItem
  @Environment(\.theme.paragraph) private var paragraph
  @Environment(\.theme.bulletedListMarker) private var bulletedListMarker
  @Environment(\.listLevel) private var listLevel
  @Environment(\.lightweightListMarkers) private var lightweightListMarkers
  @Environment(\.lightweightBlocks) private var lightweightBlocks
  @Environment(\.compactLayout) private var compactLayout
  @Environment(\.markdownBlockMargins) private var staticBlockMargins

  private let isTight: Bool
  private let items: [RawListItem]

  init(isTight: Bool, items: [RawListItem]) {
    self.isTight = isTight
    self.items = items
  }

  var body: some View {
    if self.lightweightBlocks, self.list.isIdentity {
      if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *),
        self.compactLayout,
        self.lightweightListMarkers,
        self.listItem.isIdentity,
        let builtin = self.bulletedListMarker.builtinBulletMarker,
        let margins = self.staticBlockMargins,
        self.paragraph.paragraphLineSpacing != nil || self.paragraph.isIdentity,
        let paragraphs = self.simpleParagraphItems
      {
        CompactBulletedListView(
          paragraphs: paragraphs,
          isTight: self.isTight,
          nextListLevel: self.listLevel + 1,
          builtinMarker: builtin,
          margins: margins,
          paragraphLineSpacing: self.paragraph.paragraphLineSpacing
        )
      } else {
        self.label
      }
    } else {
      self.list.makeBody(
        configuration: .init(
          label: .init(self.label),
          content: .init(block: .bulletedList(isTight: self.isTight, items: self.items))
        )
      )
    }
  }

  /// Extracts inline arrays when every list item is a single non-image paragraph.
  private var simpleParagraphItems: [[InlineNode]]? {
    var result: [[InlineNode]] = []
    result.reserveCapacity(self.items.count)
    for item in self.items {
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

  private var label: some View {
    ListItemSequence(
      items: self.items,
      markerStyle: self.bulletedListMarker,
      readsMarkerWidth: !self.lightweightListMarkers
    )
    .environment(\.listLevel, self.listLevel + 1)
    .environment(\.tightSpacingEnabled, self.isTight)
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct CompactBulletedListView: View {
  @Environment(\.textStyleAttributes) private var textStyleAttributes
  @Environment(\.theme.inlineTextStyles) private var inlineStyles
  @Environment(\.baseURL) private var baseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.lineSpacing) private var environmentLineSpacing
  @Environment(\.multilineTextAlignment) private var textAlignment

  let paragraphs: [[InlineNode]]
  let isTight: Bool
  let nextListLevel: Int
  let builtinMarker: BlockStyle<ListMarkerConfiguration>.BuiltinBulletMarker
  let margins: MarkdownBlockMargins
  let paragraphLineSpacing: RelativeSize?

  var body: some View {
    let fontSize =
      self.textStyleAttributes.fontProperties?.scaledSize ?? FontProperties.defaultSize
    let bulletImage = ListBullet.builtinImage(for: self.builtinMarker, listLevel: self.nextListLevel)
    let bulletFont = Font.system(size: round(fontSize / 3))
    let minBulletWidth = round(1.5 * fontSize)
    let effectiveItemMargin = self.margins.listItem.combined(with: self.margins.paragraph)
    let itemSpacing =
      BlockMargin.max(
        effectiveItemMargin.top,
        self.isTight ? 0 : effectiveItemMargin.bottom
      ) ?? 0
    let cache = PrecomputedInlineAttributes(
      attributes: self.textStyleAttributes,
      inlineStyles: self.inlineStyles
    )

    let listBody = BulletedListLayout(
      minBulletWidth: minBulletWidth,
      itemSpacing: itemSpacing
    ) {
      Label {
        Text(AttributedString("A", attributes: cache.resolvedBase))
      } icon: {
        bulletImage
          .font(bulletFont)
          .frame(minWidth: minBulletWidth, minHeight: 100, alignment: .topTrailing)
      }
      .hidden()
      ForEach(self.paragraphs.indices, id: \.self) { index in
        bulletImage.font(bulletFont)
        self.itemText(at: index, cache: cache)
      }
    }

    if let paragraphLineSpacing = self.paragraphLineSpacing {
      listBody.lineSpacing(
        paragraphLineSpacing.points(relativeTo: self.textStyleAttributes.fontProperties)
      )
    } else {
      listBody
    }
  }

  @ViewBuilder private func itemText(
    at index: Int,
    cache: PrecomputedInlineAttributes
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
