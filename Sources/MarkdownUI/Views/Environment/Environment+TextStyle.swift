import SwiftUI

extension View {
  /// Sets the default text style for the Markdown inlines in a view hierarchy.
  ///
  /// Use this modifier inside a ``BlockStyle`` `body` block to customize
  /// the default text style for the block's Markdown inlines.
  ///
  /// - Parameter textStyle: A text style builder that returns the text style to use.
  public func markdownTextStyle<S: TextStyle>(
    @TextStyleBuilder textStyle: @escaping () -> S
  ) -> some View {
    self.transformEnvironment(\.textStyleAttributes) { attributes in
      textStyle()._collectAttributes(in: &attributes)
    }
  }

  func textStyleFont() -> some View {
    TextStyleAttributesReader { attributes in
      self.font(attributes.fontProperties.map(Font.withProperties))
    }
  }

  func textStyleForegroundColor() -> some View {
    TextStyleAttributesReader { attributes in
      self.foregroundColor(attributes.foregroundColor)
    }
  }

  func textStyle(_ textStyle: TextStyle) -> some View {
    self.transformEnvironment(\.textStyleAttributes) { attributes in
      textStyle._collectAttributes(in: &attributes)
    }
  }
}

extension EnvironmentValues {
  var textStyleAttributes: AttributeContainer {
    get { self[TextStyleAttributesKey.self] }
    set { self[TextStyleAttributesKey.self] = newValue }
  }
}

private struct TextStyleAttributesKey: EnvironmentKey {
  static let defaultValue: AttributeContainer = {
    var attributes = AttributeContainer()
    FontProperties()._collectAttributes(in: &attributes)
    return attributes
  }()
}
