import SwiftUI

final class PrecomputedInlineAttributes {
  let base: AttributeContainer
  let resolvedBase: AttributeContainer
  let inlineStyles: InlineTextStyles

  private var cachedCode: AttributeContainer?
  private var cachedStrong: AttributeContainer?
  private var cachedEmphasis: AttributeContainer?
  private var cachedStrikethrough: AttributeContainer?
  private var cachedLink: AttributeContainer?

  init(attributes: AttributeContainer, inlineStyles: InlineTextStyles) {
    self.base = attributes
    self.resolvedBase = AttributedStringInlineRenderer.resolvingFont(in: attributes)
    self.inlineStyles = inlineStyles
  }

  func resolvedCode() -> AttributeContainer {
    if let cached = self.cachedCode { return cached }
    let resolved = AttributedStringInlineRenderer.resolvingFont(
      in: self.inlineStyles.code.mergingAttributes(self.base)
    )
    self.cachedCode = resolved
    return resolved
  }

  func resolvedStrong() -> AttributeContainer {
    if let cached = self.cachedStrong { return cached }
    let resolved = AttributedStringInlineRenderer.resolvingFont(
      in: self.inlineStyles.strong.mergingAttributes(self.base)
    )
    self.cachedStrong = resolved
    return resolved
  }

  func resolvedEmphasis() -> AttributeContainer {
    if let cached = self.cachedEmphasis { return cached }
    let resolved = AttributedStringInlineRenderer.resolvingFont(
      in: self.inlineStyles.emphasis.mergingAttributes(self.base)
    )
    self.cachedEmphasis = resolved
    return resolved
  }

  func resolvedStrikethrough() -> AttributeContainer {
    if let cached = self.cachedStrikethrough { return cached }
    let resolved = AttributedStringInlineRenderer.resolvingFont(
      in: self.inlineStyles.strikethrough.mergingAttributes(self.base)
    )
    self.cachedStrikethrough = resolved
    return resolved
  }

  func resolvedLink() -> AttributeContainer {
    if let cached = self.cachedLink { return cached }
    let resolved = AttributedStringInlineRenderer.resolvingFont(
      in: self.inlineStyles.link.mergingAttributes(self.base)
    )
    self.cachedLink = resolved
    return resolved
  }
}

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
    preResolvedAttributes: AttributeContainer? = nil,
    resolvesFontsInline: Bool = false
  ) {
    self.baseURL = baseURL
    self.textStyles = textStyles
    self.softBreakMode = softBreakMode
    self.resolvesFontsInline = resolvesFontsInline
    self.attributes = attributes
    if let preResolvedAttributes {
      self.resolvedAttributes = preResolvedAttributes
    } else {
      self.resolvedAttributes = resolvesFontsInline ? Self.resolvingFont(in: attributes) : attributes
    }
  }

  static func resolvingFont(in attributes: AttributeContainer) -> AttributeContainer {
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
        text = String(text.drop(while: \.isWhitespace))
      }
    }

    self.appendAttributed(.init(text, attributes: self.resolvedAttributes))
  }

  private mutating func renderSoftBreak() {
    switch softBreakMode {
    case .space where self.shouldSkipNextWhitespace:
      self.shouldSkipNextWhitespace = false
    case .space:
      self.appendAttributed(.init(" ", attributes: self.resolvedAttributes))
    case .lineBreak:
      self.renderLineBreak()
    }
  }

  private mutating func renderLineBreak() {
    self.appendAttributed(.init("\n", attributes: self.resolvedAttributes))
  }

  private mutating func renderCode(_ code: String) {
    self.shouldSkipNextWhitespace = false
    let merged = self.textStyles.code.mergingAttributes(self.attributes)
    let attrs = self.resolvesFontsInline ? Self.resolvingFont(in: merged) : merged
    self.appendAttributed(.init(code, attributes: attrs))
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

  private mutating func appendAttributed(_ run: AttributedString) {
    guard !run.characters.isEmpty else { return }
    if self.result.characters.isEmpty {
      self.result = run
    } else {
      self.result += run
    }
  }
}

extension TextStyle {
  func mergingAttributes(_ attributes: AttributeContainer) -> AttributeContainer {
    var newAttributes = attributes
    self._collectAttributes(in: &newAttributes)
    return newAttributes
  }
}
