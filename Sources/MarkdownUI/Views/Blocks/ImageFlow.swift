import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct ImageFlow: View {
  private enum Item: Hashable {
    case image(RawImageData)
    case text([InlineNode])
    case lineBreak
  }

  private let items: [Indexed<Item>]

  var body: some View {
    TextStyleAttributesReader { attributes in
      let spacing = RelativeSize.rem(0.25).points(relativeTo: attributes.fontProperties)

      FlowLayout(horizontalSpacing: spacing, verticalSpacing: spacing) {
        ForEach(self.items, id: \.self) { item in
          switch item.value {
          case .image(let data):
            ImageView(data: data)
          case .text(let inlines):
            InlineText(inlines)
          case .lineBreak:
            Spacer()
          }
        }
      }
    }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension ImageFlow {
  init?(_ inlines: [InlineNode]) {
    let fragments = inlines.imageFragments()
    guard fragments.contains(where: { if case .image = $0 { return true }; return false }) else { return nil }
    self.items = fragments.map { fragment in
      switch fragment {
      case .image(let data): return Item.image(data)
      case .text(let inlines):
        if inlines == [.lineBreak] { return Item.lineBreak }
        return Item.text(inlines)
      }
    }.indexed()
  }
}
