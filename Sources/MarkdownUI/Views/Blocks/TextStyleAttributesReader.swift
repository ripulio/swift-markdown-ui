import SwiftUI

struct TextStyleAttributesReader<Content: View>: View {
  @Environment(\.lightweightBlocks) private var lightweightBlocks
  @Environment(\.textStyle) private var textStyle
  @Environment(\.textStyleAttributes) private var precollectedAttributes

  private let content: (AttributeContainer) -> Content

  init(@ViewBuilder content: @escaping (_ attributes: AttributeContainer) -> Content) {
    self.content = content
  }

  var body: some View {
    self.content(self.attributes)
  }

  private var attributes: AttributeContainer {
    if self.lightweightBlocks {
      return self.precollectedAttributes
    }
    var attributes = AttributeContainer()
    self.textStyle._collectAttributes(in: &attributes)
    return attributes
  }
}
