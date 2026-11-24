import SwiftUI

struct TaskListView: View {
  @Environment(\.theme) private var theme
  @Environment(\.listLevel) private var listLevel
  @Environment(\.markdownBlockMargins) private var staticBlockMargins
  @Environment(\.isInsideDynamicBlockSequence) private var isInsideDynamicBlockSequence
  @Environment(\.textStyleAttributes) private var textStyleAttributes
  @Environment(\.softBreakMode) private var softBreakMode

  private let isTight: Bool
  private let items: [RawTaskListItem]

  init(isTight: Bool, items: [RawTaskListItem]) {
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
        let builtin = self.theme.taskListMarker.builtinTaskMarker,
        let margins = self.effectiveMargins,
        self.theme.paragraph.paragraphLineSpacing != nil || self.theme.paragraph.isIdentity,
        let simpleItems = Self.extractSimpleTaskItems(self.items),
        !simpleItems.contains(where: { $0.inlines.hasMultipleTextChunks(softBreakMode: self.softBreakMode) })
      {
        CompactTaskListView(
          items: simpleItems,
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
          content: .init(block: .taskList(isTight: self.isTight, items: self.items))
        )
      )
    }
  }

  static func extractSimpleTaskItems(
    _ items: [RawTaskListItem]
  ) -> [(isCompleted: Bool, inlines: [InlineNode])]? {
    var result: [(isCompleted: Bool, inlines: [InlineNode])] = []
    result.reserveCapacity(items.count)
    for item in items {
      guard item.children.count == 1,
        case .paragraph(let inlines) = item.children[0],
        !inlines.contains(where: \.containsImage)
      else {
        return nil
      }
      result.append((isCompleted: item.isCompleted, inlines: inlines))
    }
    return result
  }

  private var label: some View {
    BlockSequence(self.items) { _, item in
      TaskListItemView(item: item)
    }
    .labelStyle(.titleAndIcon)
    .environment(\.listLevel, self.listLevel + 1)
    .environment(\.tightSpacingEnabled, self.isTight)
    .disableTextSelectionForOccludedListLinks(self.items.hasOccludedListLink)
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct CompactTaskListView: View {
  @Environment(\.textStyleAttributes) private var textStyleAttributes
  @Environment(\.rootTextBackgroundColor) private var rootTextBackgroundColor
  @Environment(\.theme.inlineTextStyles) private var inlineStyles
  @Environment(\.baseURL) private var baseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.displayScale) private var displayScale

  let items: [(isCompleted: Bool, inlines: [InlineNode])]
  let isTight: Bool
  let builtinMarker: BlockStyle<TaskListMarkerConfiguration>.BuiltinTaskMarker
  let margins: MarkdownBlockMargins
  let paragraphLineSpacing: RelativeSize?

  var body: some View {
    let fontProperties = self.textStyleAttributes.fontProperties
    let fontSize = fontProperties?.scaledSize ?? FontProperties.defaultSize
    let minMarkerWidth = round(1.5 * fontSize)
    let baseFont = fontProperties.map(Font.withProperties)
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
    let symbolVariant: Int = {
      switch self.builtinMarker {
      case .checkmarkSquare: return 10
      case .gitHubCheckmark: return 11
      case .discBullet: return 0
      }
    }()
    let probeKey = BulletProbeKey(
      symbolVariant: symbolVariant,
      fontSize: fontSize,
      minBulletWidth: minMarkerWidth,
      fontProperties: fontProperties,
      baselineOffset: self.textStyleAttributes.baselineOffset,
      displayScale: self.displayScale
    )
    let cachedProbe = BulletProbeMetricsCache.lookup(probeKey)
    let disablesSelection = self.items.dropLast().contains {
      $0.inlines.contains(where: \.containsLink)
    }

    let listBody = self.makeListBody(
      fontSize: fontSize,
      baseFont: baseFont,
      minMarkerWidth: minMarkerWidth,
      itemSpacing: itemSpacing,
      cache: cache,
      probeKey: probeKey,
      cachedProbe: cachedProbe
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

  @ViewBuilder private func markerView(
    isCompleted: Bool,
    fontSize: CGFloat,
    baseFont: Font?
  ) -> some View {
    switch self.builtinMarker {
    case .checkmarkSquare:
      Image(systemName: isCompleted ? "checkmark.square.fill" : "square")
        .symbolRenderingMode(.hierarchical)
        .imageScale(.small)
        .font(baseFont)
    case let .gitHubCheckmark(foreground, background):
      Image(systemName: isCompleted ? "checkmark.square.fill" : "square")
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(foreground, background)
        .imageScale(.small)
        .font(baseFont)
    case .discBullet:
      ListBullet.builtinImage(for: .disc, listLevel: 1)
        .font(.system(size: round(fontSize / 3)))
    }
  }

  @ViewBuilder private func makeListBody(
    fontSize: CGFloat,
    baseFont: Font?,
    minMarkerWidth: CGFloat,
    itemSpacing: CGFloat,
    cache: PrecomputedInlineAttributes,
    probeKey: BulletProbeKey,
    cachedProbe: BulletProbeMetrics?
  ) -> some View {
    let perRowWidth = self.builtinMarker != .discBullet
    if let cachedProbe {
      BulletedListLayout(
        minBulletWidth: minMarkerWidth,
        itemSpacing: itemSpacing,
        probeKey: probeKey,
        cachedProbe: cachedProbe,
        hasLeadingProbeSubview: false,
        usesPerRowIconWidth: perRowWidth
      ) {
        StaticViewBatch(count: self.items.count) { index in
          self.markerView(
            isCompleted: self.items[index].isCompleted,
            fontSize: fontSize,
            baseFont: baseFont
          )
          self.items[index].inlines.renderCompactText(
            baseURL: self.baseURL,
            softBreakMode: self.softBreakMode,
            cache: cache
          )
        }
      }
    } else {
      BulletedListLayout(
        minBulletWidth: minMarkerWidth,
        itemSpacing: itemSpacing,
        probeKey: probeKey,
        cachedProbe: nil,
        hasLeadingProbeSubview: true,
        usesPerRowIconWidth: perRowWidth
      ) {
        Label {
          cache.directBase.makeText("A")
        } icon: {
          self.markerView(isCompleted: false, fontSize: fontSize, baseFont: baseFont)
            .frame(minWidth: minMarkerWidth, minHeight: 100, alignment: .topTrailing)
        }
        .hidden()
        StaticViewBatch(count: self.items.count) { index in
          self.markerView(
            isCompleted: self.items[index].isCompleted,
            fontSize: fontSize,
            baseFont: baseFont
          )
          self.items[index].inlines.renderCompactText(
            baseURL: self.baseURL,
            softBreakMode: self.softBreakMode,
            cache: cache
          )
        }
      }
    }
  }
}
