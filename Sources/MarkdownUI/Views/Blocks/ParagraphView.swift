import SwiftUI

struct ParagraphView: View {
  @Environment(\.theme.paragraph) private var paragraph
  @Environment(\.lightweightBlocks) private var lightweightBlocks
  @Environment(\.textStyleAttributes) private var textStyleAttributes

  private let content: [InlineNode]

  init(content: String) {
    self.init(
      content: [
        .text(content.hasSuffix("\n") ? String(content.dropLast()) : content)
      ]
    )
  }

  init(content: [InlineNode]) {
    self.content = content
  }

  var body: some View {
    if self.lightweightBlocks, let lineSpacing = self.paragraph.paragraphLineSpacing {
      self.label
        .fixedSize(horizontal: false, vertical: true)
        .lineSpacing(lineSpacing.points(relativeTo: self.textStyleAttributes.fontProperties))
    } else if self.lightweightBlocks, self.paragraph.isIdentity {
      self.label
    } else {
      self.paragraph.makeBody(
        configuration: .init(
          label: .init(self.label),
          content: .init(block: .paragraph(content: self.content))
        )
      )
    }
  }

  @ViewBuilder private var label: some View {
    if let imageView = ImageView(content) {
      imageView
    } else if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *),
      let imageFlow = ImageFlow(content)
    {
      imageFlow
    } else {
      InlineText(content)
    }
  }
}
