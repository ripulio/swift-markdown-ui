import SwiftUI

struct FlattenedBulletRow: Equatable, Hashable {
  let inlines: [InlineNode]
  let indent: Int
  let listLevel: Int
  let topSpacing: CGFloat
}

struct BulletedListView: View {
  @Environment(\.theme) private var theme
  @Environment(\.listLevel) private var listLevel
  @Environment(\.markdownBlockMargins) private var staticBlockMargins
  @Environment(\.isInsideDynamicBlockSequence) private var isInsideDynamicBlockSequence
  @Environment(\.textStyleAttributes) private var textStyleAttributes
  @Environment(\.softBreakMode) private var softBreakMode

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
        self.theme.paragraph.paragraphLineSpacing != nil || self.theme.paragraph.isIdentity
      {
        if let paragraphs = self.simpleParagraphItems {
          CompactBulletedListView(
            paragraphs: paragraphs,
            isTight: self.isTight,
            nextListLevel: self.listLevel + 1,
            builtinMarker: builtin,
            margins: margins,
            paragraphLineSpacing: self.theme.paragraph.paragraphLineSpacing
          )
        } else if let flattened = Self.extractFlattenedBulletItems(
          self.items,
          isTight: self.isTight,
          baseListLevel: self.listLevel + 1,
          margins: margins
        ),
          !flattened.contains(where: { $0.inlines.hasMultipleTextChunks(softBreakMode: self.softBreakMode) })
        {
          CompactNestedBulletedListView(
            rows: flattened,
            builtinMarker: builtin,
            paragraphLineSpacing: self.theme.paragraph.paragraphLineSpacing
          )
        } else {
          self.label
        }
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

  /// Flattens a nested bulleted list tree where every item is either `[.paragraph]` or
  /// `[.paragraph, .bulletedList(...)]` (recursively, with no images) into a flat list
  /// of indented rows with exact collapsed margins matching `BlockSequence`.
  static func extractFlattenedBulletItems(
    _ items: [RawListItem],
    isTight: Bool,
    baseListLevel: Int,
    margins: MarkdownBlockMargins
  ) -> [FlattenedBulletRow]? {
    guard !items.isEmpty else { return nil }
    var rows: [FlattenedBulletRow] = []
    rows.reserveCapacity(items.count * 2)

    func appendList(
      _ listItems: [RawListItem],
      listTight: Bool,
      indent: Int,
      parentBlockTopSpacing: CGFloat?
    ) -> BlockMargin? {
      var combinedListMargin = margins.list
      var prevItemMargin: BlockMargin?

      for (itemIndex, item) in listItems.enumerated() {
        guard !item.children.isEmpty,
          case .paragraph(let inlines) = item.children[0],
          !inlines.contains(where: \.containsImage)
        else {
          return nil
        }

        let nestedList: (isTight: Bool, items: [RawListItem])?
        if item.children.count == 1 {
          nestedList = nil
        } else if item.children.count == 2,
          case let .bulletedList(subTight, subItems) = item.children[1],
          !subItems.isEmpty
        {
          nestedList = (subTight, subItems)
        } else {
          return nil
        }

        let paraMargin = margins.paragraph
        let nestedEffective = nestedList != nil
          ? margins.list.combined(with: margins.listItem).combined(with: paraMargin)
          : BlockMargin.unspecified
        let itemEffectiveMargin = margins.listItem
          .combined(with: paraMargin)
          .combined(with: nestedEffective)

        let rowTop: CGFloat
        if itemIndex == 0 {
          rowTop = parentBlockTopSpacing ?? 0
        } else if let prev = prevItemMargin {
          rowTop = BlockMargin.max(itemEffectiveMargin.top, listTight ? 0 : prev.bottom) ?? 0
        } else {
          rowTop = 0
        }

        rows.append(
          FlattenedBulletRow(
            inlines: inlines,
            indent: indent,
            listLevel: baseListLevel + indent,
            topSpacing: rowTop
          )
        )

        var resolvedItemMargin = margins.listItem.combined(with: paraMargin)
        if let nested = nestedList {
          let subTopSpacing = BlockMargin.max(
            nestedEffective.top,
            listTight ? 0 : paraMargin.bottom
          ) ?? 0
          guard let subMargin = appendList(
            nested.items,
            listTight: nested.isTight,
            indent: indent + 1,
            parentBlockTopSpacing: subTopSpacing
          ) else {
            return nil
          }
          resolvedItemMargin = resolvedItemMargin.combined(with: subMargin)
        }

        prevItemMargin = resolvedItemMargin
        combinedListMargin = combinedListMargin.combined(with: resolvedItemMargin)
      }

      return combinedListMargin
    }

    guard appendList(items, listTight: isTight, indent: 0, parentBlockTopSpacing: nil) != nil else {
      return nil
    }
    return rows
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
    .disableTextSelectionForOccludedListLinks(self.items.hasOccludedListLink)
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct CompactBulletedListView: View {
  @Environment(\.textStyleAttributes) private var textStyleAttributes
  @Environment(\.rootTextBackgroundColor) private var rootTextBackgroundColor
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
      inlineStyles: self.inlineStyles,
      ignoredBackgroundColor: self.rootTextBackgroundColor
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

    let disablesSelection = self.paragraphs.dropLast().contains {
      $0.contains(where: \.containsLink)
    }

    if let paragraphLineSpacing = self.paragraphLineSpacing {
      listBody
        .lineSpacing(
          paragraphLineSpacing.points(relativeTo: fontProperties)
        )
        .disableTextSelectionForOccludedListLinks(disablesSelection)
    } else {
      listBody
        .disableTextSelectionForOccludedListLinks(disablesSelection)
    }
  }

  static func symbolVariant(
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

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct CompactNestedBulletedListView: View {
  @Environment(\.textStyleAttributes) private var textStyleAttributes
  @Environment(\.rootTextBackgroundColor) private var rootTextBackgroundColor
  @Environment(\.theme.inlineTextStyles) private var inlineStyles
  @Environment(\.baseURL) private var baseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.displayScale) private var displayScale

  let rows: [FlattenedBulletRow]
  let builtinMarker: BlockStyle<ListMarkerConfiguration>.BuiltinBulletMarker
  let paragraphLineSpacing: RelativeSize?

  private struct VariantProbeSetup {
    let rowVariantIndices: [Int]
    let variantKeys: [BulletProbeKey]
    let variantProbes: [BulletProbeMetrics?]
    let missingLevels: [Int]
  }

  private func computeVariantProbes(
    fontSize: CGFloat,
    minBulletWidth: CGFloat,
    fontProperties: FontProperties?
  ) -> VariantProbeSetup {
    var distinctLevels: [Int] = []
    var variantMap: [Int: Int] = [:]
    var rowVariantIndices: [Int] = []
    rowVariantIndices.reserveCapacity(self.rows.count)
    for row in self.rows {
      let variant = CompactBulletedListView.symbolVariant(
        for: self.builtinMarker,
        listLevel: row.listLevel
      )
      if let existing = variantMap[variant] {
        rowVariantIndices.append(existing)
      } else {
        let idx = distinctLevels.count
        variantMap[variant] = idx
        distinctLevels.append(row.listLevel)
        rowVariantIndices.append(idx)
      }
    }

    let variantKeys: [BulletProbeKey] = distinctLevels.map { level in
      BulletProbeKey(
        symbolVariant: CompactBulletedListView.symbolVariant(
          for: self.builtinMarker,
          listLevel: level
        ),
        fontSize: fontSize,
        minBulletWidth: minBulletWidth,
        fontProperties: fontProperties,
        baselineOffset: self.textStyleAttributes.baselineOffset,
        displayScale: self.displayScale
      )
    }
    let variantProbes: [BulletProbeMetrics?] = variantKeys.map { BulletProbeMetricsCache.lookup($0) }
    var missingLevels: [Int] = []
    for (idx, probe) in variantProbes.enumerated() where probe == nil {
      missingLevels.append(distinctLevels[idx])
    }
    return VariantProbeSetup(
      rowVariantIndices: rowVariantIndices,
      variantKeys: variantKeys,
      variantProbes: variantProbes,
      missingLevels: missingLevels
    )
  }

  var body: some View {
    let fontProperties = self.textStyleAttributes.fontProperties
    let fontSize = fontProperties?.scaledSize ?? FontProperties.defaultSize
    let bulletFont = Font.system(size: round(fontSize / 3))
    let minBulletWidth = round(1.5 * fontSize)
    let cache = InlineAttributesCache.lookup(
      attributes: self.textStyleAttributes,
      inlineStyles: self.inlineStyles,
      ignoredBackgroundColor: self.rootTextBackgroundColor
    )
    let setup = self.computeVariantProbes(
      fontSize: fontSize,
      minBulletWidth: minBulletWidth,
      fontProperties: fontProperties
    )
    let indents = self.rows.map(\.indent)
    let topSpacings = self.rows.map(\.topSpacing)
    let disablesSelection = self.rows.dropLast().contains {
      $0.inlines.contains(where: \.containsLink)
    }

    let listBody = BulletedListLayout(
      minBulletWidth: minBulletWidth,
      itemSpacing: 0,
      hasLeadingProbeSubview: !setup.missingLevels.isEmpty,
      rowIndents: indents,
      rowTopSpacings: topSpacings,
      rowVariantIndices: setup.rowVariantIndices,
      variantProbes: setup.variantProbes,
      variantProbeKeys: setup.variantKeys,
      leadingProbeCount: setup.missingLevels.count * 2
    ) {
      ForEach(setup.missingLevels.indices, id: \.self) { mIdx in
        let img = ListBullet.builtinImage(for: self.builtinMarker, listLevel: setup.missingLevels[mIdx])
        Label {
          cache.directBase.makeText("A")
        } icon: {
          img
            .font(bulletFont)
            .frame(minWidth: minBulletWidth, minHeight: 100, alignment: .topTrailing)
        }
        .hidden()
        img.font(bulletFont).hidden()
      }
      StaticViewBatch(count: self.rows.count) { index in
        ListBullet.builtinImage(for: self.builtinMarker, listLevel: self.rows[index].listLevel)
          .font(bulletFont)
        self.rows[index].inlines.renderCompactText(
          baseURL: self.baseURL,
          softBreakMode: self.softBreakMode,
          cache: cache
        )
      }
    }

    if let paragraphLineSpacing = self.paragraphLineSpacing {
      listBody
        .lineSpacing(paragraphLineSpacing.points(relativeTo: fontProperties))
        .disableTextSelectionForOccludedListLinks(disablesSelection)
    } else {
      listBody
        .disableTextSelectionForOccludedListLinks(disablesSelection)
    }
  }
}
