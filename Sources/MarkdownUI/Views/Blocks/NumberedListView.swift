import SwiftUI

struct NumberedListView: View {
  @Environment(\.theme) private var theme
  @Environment(\.listLevel) private var listLevel
  @Environment(\.markdownBlockMargins) private var staticBlockMargins
  @Environment(\.isInsideDynamicBlockSequence) private var isInsideDynamicBlockSequence
  @Environment(\.textStyleAttributes) private var textStyleAttributes

  @State private var markerWidth: CGFloat?

  private let isTight: Bool
  private let start: Int
  private let items: [RawListItem]

  init(isTight: Bool, start: Int, items: [RawListItem]) {
    self.isTight = isTight
    self.start = start
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
        let builtin = self.theme.numberedListMarker.builtinNumberedMarker,
        let margins = self.effectiveMargins,
        self.theme.paragraph.paragraphLineSpacing != nil || self.theme.paragraph.isIdentity,
        let paragraphs = BulletedListView.extractSimpleParagraphItems(self.items)
      {
        CompactNumberedListView(
          paragraphs: paragraphs,
          start: self.start,
          isTight: self.isTight,
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
          content: .init(
            block: .numberedList(
              isTight: self.isTight,
              start: self.start,
              items: self.items
            )
          )
        )
      )
    }
  }

  @ViewBuilder private var label: some View {
    let needsWidthSync = self.items.count > 1
    let sequence = ListItemSequence(
      items: self.items,
      start: self.start,
      markerStyle: self.theme.numberedListMarker,
      markerWidth: needsWidthSync ? self.markerWidth : nil,
      readsMarkerWidth: needsWidthSync
    )
    .environment(\.listLevel, self.listLevel + 1)
    .environment(\.tightSpacingEnabled, self.isTight)

    if needsWidthSync {
      sequence
        .onColumnWidthChange { columnWidths in
          self.markerWidth = columnWidths[0]
        }
        .disableTextSelectionForOccludedListLinks(self.items.hasOccludedListLink)
    } else {
      sequence
        .disableTextSelectionForOccludedListLinks(self.items.hasOccludedListLink)
    }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct CompactNumberedListView: View {
  @Environment(\.textStyleAttributes) private var textStyleAttributes
  @Environment(\.rootTextBackgroundColor) private var rootTextBackgroundColor
  @Environment(\.theme.inlineTextStyles) private var inlineStyles
  @Environment(\.baseURL) private var baseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.lineSpacing) private var environmentLineSpacing
  @Environment(\.multilineTextAlignment) private var textAlignment

  let paragraphs: [[InlineNode]]
  let start: Int
  let isTight: Bool
  let builtinMarker: BlockStyle<ListMarkerConfiguration>.BuiltinNumberedMarker
  let margins: MarkdownBlockMargins
  let paragraphLineSpacing: RelativeSize?

  var body: some View {
    let fontProperties = self.textStyleAttributes.fontProperties
    let fontSize = fontProperties?.scaledSize ?? FontProperties.defaultSize
    let minMarkerWidth = round(1.5 * fontSize)
    let markerFont = fontProperties.map(Font.withProperties)
    let effectiveItemMargin = self.margins.listItem.combined(with: self.margins.paragraph)
    let itemSpacing =
      BlockMargin.max(
        effectiveItemMargin.top,
        self.isTight ? 0 : effectiveItemMargin.bottom
      ) ?? 0
    let cache = InlineAttributesCache.lookup(
      attributes: self.textStyleAttributes,
      inlineStyles: self.inlineStyles,
      ignoredBackgroundColor: self.rootTextBackgroundColor
    )
    let disablesSelection = self.paragraphs.dropLast().contains {
      $0.contains(where: \.containsLink)
    }

    let listBody = self.makeListBody(
      minMarkerWidth: minMarkerWidth,
      itemSpacing: itemSpacing,
      markerFont: markerFont,
      cache: cache
    )

    if let paragraphLineSpacing = self.paragraphLineSpacing {
      listBody
        .lineSpacing(paragraphLineSpacing.points(relativeTo: fontProperties))
        .disableTextSelectionForOccludedListLinks(disablesSelection)
    } else {
      listBody
        .disableTextSelectionForOccludedListLinks(disablesSelection)
    }
  }

  @ViewBuilder private func makeListBody(
    minMarkerWidth: CGFloat,
    itemSpacing: CGFloat,
    markerFont: Font?,
    cache: PrecomputedInlineAttributes
  ) -> some View {
    if !self.paragraphs.contains(where: { $0.hasMultipleTextChunks(softBreakMode: self.softBreakMode) }) {
      NumberedListLayout(
        minMarkerWidth: minMarkerWidth,
        itemSpacing: itemSpacing
      ) {
        StaticViewBatch(count: self.paragraphs.count) { index in
          self.markerView(number: self.start + index, font: markerFont)
          self.paragraphs[index].renderCompactText(
            baseURL: self.baseURL,
            softBreakMode: self.softBreakMode,
            cache: cache
          )
        }
      }
    } else {
      let itemChunks = self.paragraphs.map { $0.textChunks(softBreakMode: self.softBreakMode) }
      NumberedListLayout(
        minMarkerWidth: minMarkerWidth,
        itemSpacing: itemSpacing
      ) {
        ForEach(itemChunks.indices, id: \.self) { index in
          self.markerView(number: self.start + index, font: markerFont)
          self.chunkedItemText(chunks: itemChunks[index], cache: cache)
        }
      }
    }
  }

  @ViewBuilder private func markerView(number: Int, font: Font?) -> some View {
    let text = Text(verbatim: self.builtinMarker.text(for: number))
    if self.builtinMarker.usesMonospacedDigit {
      text.monospacedDigit().font(font)
    } else {
      text.font(font)
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
