import SwiftUI

extension View {
  /// Fit images in headings and table cells using the image provider and a
  /// wrapping flow, just as in mixed image paragraphs. The default keeps the
  /// original inline-image-provider behaviour for compatibility.
  public func markdownInlineImageFlow(_ enabled: Bool = true) -> some View {
    environment(\.inlineImageFlow, enabled)
  }
}

extension EnvironmentValues {
  var inlineImageFlow: Bool {
    get { self[InlineImageFlowKey.self] }
    set { self[InlineImageFlowKey.self] = newValue }
  }
}

private struct InlineImageFlowKey: EnvironmentKey {
  static let defaultValue = false
}
