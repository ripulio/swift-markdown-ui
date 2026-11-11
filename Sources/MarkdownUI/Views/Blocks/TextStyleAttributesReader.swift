import SwiftUI

struct TextStyleAttributesReader<Content: View>: View {
  @Environment(\.textStyleAttributes) private var attributes

  private let content: (AttributeContainer) -> Content

  init(@ViewBuilder content: @escaping (_ attributes: AttributeContainer) -> Content) {
    self.content = content
  }

  var body: some View {
    self.content(self.attributes)
  }
}
