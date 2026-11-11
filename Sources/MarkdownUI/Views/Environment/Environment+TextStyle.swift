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
    self.transformEnvironment(\.textStyleEntry) { entry in
      let next = textStyle()
      entry.style = entry.style.appending(next)
      next._collectAttributes(in: &entry.attributes)
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
    self.transformEnvironment(\.textStyleEntry) { entry in
      entry.style = entry.style.appending(textStyle)
      textStyle._collectAttributes(in: &entry.attributes)
    }
  }
}

extension TextStyle {
  @TextStyleBuilder fileprivate func appending<S: TextStyle>(
    _ textStyle: S
  ) -> some TextStyle {
    self
    textStyle
  }
}

struct TextStyleEntry {
  var style: TextStyle
  var attributes: AttributeContainer
}

extension EnvironmentValues {
  fileprivate var textStyleEntry: TextStyleEntry {
    get { self[TextStyleKey.self] }
    set { self[TextStyleKey.self] = newValue }
  }

  var textStyle: TextStyle {
    self[TextStyleKey.self].style
  }

  var textStyleAttributes: AttributeContainer {
    self[TextStyleKey.self].attributes
  }
}

private struct TextStyleKey: EnvironmentKey {
  static let defaultValue: TextStyleEntry = {
    let base = FontProperties()
    var attributes = AttributeContainer()
    base._collectAttributes(in: &attributes)
    return TextStyleEntry(style: base, attributes: attributes)
  }()
}
