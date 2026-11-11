import SwiftUI

struct HeadingView: View {
  @Environment(\.theme.headings) private var headings
  @Environment(\.theme.inlineTextStyles) private var inlineStyles
  @Environment(\.textStyleAttributes) private var textStyleAttributes
  @Environment(\.baseURL) private var baseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.lightweightBlocks) private var lightweightBlocks
  @Environment(\.compactLayout) private var compactLayout
  @Environment(\.directBlocks) private var directBlocks

  private let level: Int
  private let content: [InlineNode]

  init(level: Int, content: [InlineNode]) {
    self.level = level
    self.content = content
  }

  var body: some View {
    let style = self.headings[self.level - 1]
    if self.directBlocks,
      self.compactLayout,
      self.lightweightBlocks,
      style.headingSpec != nil || style.isIdentity,
      !self.content.contains(where: \.containsImage),
      !self.content.hasMultipleTextChunks(softBreakMode: self.softBreakMode)
    {
      let spec = style.headingSpec
      let cache = InlineAttributesCache.lookup(
        attributes: self.textStyleAttributes,
        inlineStyles: self.inlineStyles,
        overrideWeight: spec?.fontWeight,
        overrideSize: spec?.fontSize
      )
      let text = self.content.renderCompactText(
        baseURL: self.baseURL,
        softBreakMode: self.softBreakMode,
        cache: cache
      )
      if let lineSpacing = spec?.lineSpacing {
        text.lineSpacing(lineSpacing.points(relativeTo: self.textStyleAttributes.fontProperties))
      } else {
        text
      }
    } else {
      style.makeBody(
        configuration: .init(
          label: .init(InlineText(self.content)),
          content: .init(block: .heading(level: self.level, content: self.content))
        )
      )
      .id(content.renderPlainText().kebabCased())
    }
  }
}
