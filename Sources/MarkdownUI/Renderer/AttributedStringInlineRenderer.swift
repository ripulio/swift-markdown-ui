import SwiftUI

extension InlineNode {
  func renderAttributedString(
    baseURL: URL?,
    textStyles: InlineTextStyles,
    softBreakMode: SoftBreak.Mode,
    attributes: AttributeContainer
  ) -> AttributedString {
    var renderer = AttributedStringInlineRenderer(
      baseURL: baseURL,
      textStyles: textStyles,
      softBreakMode: softBreakMode,
      attributes: attributes,
      resolvesFontsInline: false
    )
    renderer.render(self)
    return renderer.result.resolvingFonts()
  }
}

struct AttributedStringInlineRenderer {
  var result = AttributedString()

  private let baseURL: URL?
  private let textStyles: InlineTextStyles
  private let softBreakMode: SoftBreak.Mode
  private let resolvesFontsInline: Bool
  private var attributes: AttributeContainer
  private var resolvedAttributes: AttributeContainer
  private var shouldSkipNextWhitespace = false

  init(
    baseURL: URL?,
    textStyles: InlineTextStyles,
    softBreakMode: SoftBreak.Mode,
    attributes: AttributeContainer,
    resolvesFontsInline: Bool = false
  ) {
    self.baseURL = baseURL
    self.textStyles = textStyles
    self.softBreakMode = softBreakMode
    self.resolvesFontsInline = resolvesFontsInline
    self.attributes = attributes
    self.resolvedAttributes = resolvesFontsInline ? Self.resolvingFont(in: attributes) : attributes
  }

  private static func resolvingFont(in attributes: AttributeContainer) -> AttributeContainer {
    guard let fontProperties = attributes.fontProperties else { return attributes }
    var resolved = attributes
    resolved.font = .withProperties(fontProperties)
    resolved.fontProperties = nil
    return resolved
  }

  mutating func resetWhitespaceState() {
    self.shouldSkipNextWhitespace = false
  }

  mutating func takeResult() -> AttributedString {
    let current = self.result
    self.result = AttributedString()
    return current
  }

  mutating func render(_ inline: InlineNode) {
    switch inline {
    case .text(let content):
      self.renderText(content)
    case .softBreak:
      self.renderSoftBreak()
    case .lineBreak:
      self.renderLineBreak()
    case .code(let content):
      self.renderCode(content)
    case .html(let content):
      self.renderHTML(content)
    case .emphasis(let children):
      self.renderEmphasis(children: children)
    case .strong(let children):
      self.renderStrong(children: children)
    case .strikethrough(let children):
      self.renderStrikethrough(children: children)
    case .link(let destination, let children):
      self.renderLink(destination: destination, children: children)
    case .image(let source, let children):
      self.renderImage(source: source, children: children)
    }
  }

  private mutating func renderText(_ text: String) {
    var text = text

    if self.shouldSkipNextWhitespace {
      self.shouldSkipNextWhitespace = false
      if text.first?.isWhitespace == true {
        text = text.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
      }
    }

    self.result += .init(text, attributes: self.resolvedAttributes)
  }

  private mutating func renderSoftBreak() {
    switch softBreakMode {
    case .space where self.shouldSkipNextWhitespace:
      self.shouldSkipNextWhitespace = false
    case .space:
      self.result += .init(" ", attributes: self.resolvedAttributes)
    case .lineBreak:
      self.renderLineBreak()
    }
  }

  private mutating func renderLineBreak() {
    self.result += .init("\n", attributes: self.resolvedAttributes)
  }

  private mutating func renderCode(_ code: String) {
    self.shouldSkipNextWhitespace = false
    let merged = self.textStyles.code.mergingAttributes(self.attributes)
    let attrs = self.resolvesFontsInline ? Self.resolvingFont(in: merged) : merged
    self.result += .init(code, attributes: attrs)
  }

  private mutating func renderHTML(_ html: String) {
    let tag = HTMLTag(html)

    switch tag?.name.lowercased() {
    case "br":
      self.renderLineBreak()
      self.shouldSkipNextWhitespace = true
    default:
      self.renderText(html)
    }
  }

  private mutating func renderEmphasis(children: [InlineNode]) {
    let savedAttributes = self.attributes
    let savedResolved = self.resolvedAttributes
    self.attributes = self.textStyles.emphasis.mergingAttributes(self.attributes)
    self.resolvedAttributes =
      self.resolvesFontsInline ? Self.resolvingFont(in: self.attributes) : self.attributes

    for child in children {
      self.render(child)
    }

    self.attributes = savedAttributes
    self.resolvedAttributes = savedResolved
  }

  private mutating func renderStrong(children: [InlineNode]) {
    let savedAttributes = self.attributes
    let savedResolved = self.resolvedAttributes
    self.attributes = self.textStyles.strong.mergingAttributes(self.attributes)
    self.resolvedAttributes =
      self.resolvesFontsInline ? Self.resolvingFont(in: self.attributes) : self.attributes

    for child in children {
      self.render(child)
    }

    self.attributes = savedAttributes
    self.resolvedAttributes = savedResolved
  }

  private mutating func renderStrikethrough(children: [InlineNode]) {
    let savedAttributes = self.attributes
    let savedResolved = self.resolvedAttributes
    self.attributes = self.textStyles.strikethrough.mergingAttributes(self.attributes)
    self.resolvedAttributes =
      self.resolvesFontsInline ? Self.resolvingFont(in: self.attributes) : self.attributes

    for child in children {
      self.render(child)
    }

    self.attributes = savedAttributes
    self.resolvedAttributes = savedResolved
  }

  private mutating func renderLink(destination: String, children: [InlineNode]) {
    let savedAttributes = self.attributes
    let savedResolved = self.resolvedAttributes
    self.attributes = self.textStyles.link.mergingAttributes(self.attributes)
    self.attributes.link = URL(string: destination, relativeTo: self.baseURL)
    self.resolvedAttributes =
      self.resolvesFontsInline ? Self.resolvingFont(in: self.attributes) : self.attributes

    for child in children {
      self.render(child)
    }

    self.attributes = savedAttributes
    self.resolvedAttributes = savedResolved
  }

  private mutating func renderImage(source: String, children: [InlineNode]) {
    // AttributedString does not support images
  }
}

extension TextStyle {
  fileprivate func mergingAttributes(_ attributes: AttributeContainer) -> AttributeContainer {
    var newAttributes = attributes
    self._collectAttributes(in: &newAttributes)
    return newAttributes
  }
}
