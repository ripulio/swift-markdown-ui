import SwiftUI

struct HeadingView: View {
  @Environment(\.theme.headings) private var headings
  @Environment(\.theme.inlineTextStyles) private var inlineStyles
  @Environment(\.textStyleAttributes) private var textStyleAttributes
  @Environment(\.baseURL) private var baseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.markdownBlockMargins) private var staticBlockMargins
  @Environment(\.usesDeclarativeBlockMargins) private var usesDeclarativeBlockMargins

  private let level: Int
  private let content: [InlineNode]

  init(level: Int, content: [InlineNode]) {
    self.level = level
    self.content = content
  }

  var body: some View {
    let style = self.headings[self.level - 1]
    let canSkipMarginPreference = self.staticBlockMargins != nil || self.usesDeclarativeBlockMargins
    if style.headingSpec != nil || style.isIdentity,
      canSkipMarginPreference || style.blockMargin == nil,
      !self.content.contains(where: \.containsImage),
      !self.content.hasMultipleTextChunks(softBreakMode: self.softBreakMode)
    {
      let spec = style.headingSpec
      let cache = InlineAttributesCache.lookup(
        attributes: self.textStyleAttributes,
        inlineStyles: self.inlineStyles,
        overrideWeight: spec?.fontWeight,
        overrideSize: spec?.fontSize,
        overrideForegroundColor: spec?.foregroundColor
      )
      let text = self.content.renderCompactText(
        baseURL: self.baseURL,
        softBreakMode: self.softBreakMode,
        cache: cache
      )
      self.styledHeading(text: text, spec: spec)
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

  @ViewBuilder private func styledHeading(
    text: Text,
    spec: BlockStyle<BlockConfiguration>.HeadingStyleSpec?
  ) -> some View {
    let resolvedLineSpacing = spec?.resolvedLineSpacing(
      relativeTo: self.textStyleAttributes.fontProperties
    )
    if let resolvedLineSpacing {
      if spec?.attachesAnchorID == true {
        text
          .lineSpacing(resolvedLineSpacing)
          .id(self.content.renderPlainText().kebabCased())
      } else {
        text.lineSpacing(resolvedLineSpacing)
      }
    } else if spec?.attachesAnchorID == true {
      text.id(self.content.renderPlainText().kebabCased())
    } else {
      text
    }
  }
}
