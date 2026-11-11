import SwiftUI

struct DirectTextStyle {
  let font: Font?
  let foregroundColor: Color?
  let kern: CGFloat?
  let tracking: CGFloat?
  let baselineOffset: CGFloat?
  let fallbackAttributes: AttributeContainer?

  init(resolved: AttributeContainer) {
    var probe = resolved
    probe.font = nil
    probe.foregroundColor = nil
    probe.kern = nil
    probe.tracking = nil
    probe.baselineOffset = nil
    if probe == AttributeContainer() {
      self.font = resolved.font
      self.foregroundColor = resolved.foregroundColor
      self.kern = resolved.kern
      self.tracking = resolved.tracking
      self.baselineOffset = resolved.baselineOffset
      self.fallbackAttributes = nil
    } else {
      self.font = nil
      self.foregroundColor = nil
      self.kern = nil
      self.tracking = nil
      self.baselineOffset = nil
      self.fallbackAttributes = resolved
    }
  }

  func makeText(_ content: String) -> Text {
    guard !content.isEmpty else { return Text(verbatim: "") }
    if let fallbackAttributes {
      return Text(AttributedString(content, attributes: fallbackAttributes))
    }
    var text = Text(verbatim: content)
    if let font {
      text = text.font(font)
    }
    if let foregroundColor {
      text = text.foregroundColor(foregroundColor)
    }
    if let kern {
      text = text.kerning(kern)
    }
    if let tracking {
      text = text.tracking(tracking)
    }
    if let baselineOffset {
      text = text.baselineOffset(baselineOffset)
    }
    return text
  }
}

final class PrecomputedInlineAttributes {
  let base: AttributeContainer
  let resolvedBase: AttributeContainer
  let directBase: DirectTextStyle
  let inlineStyles: InlineTextStyles

  private var cachedCode: AttributeContainer?
  private var cachedDirectCode: DirectTextStyle?
  private var cachedStrong: AttributeContainer?
  private var cachedDirectStrong: DirectTextStyle?
  private var cachedEmphasis: AttributeContainer?
  private var cachedDirectEmphasis: DirectTextStyle?
  private var cachedStrikethrough: AttributeContainer?
  private var cachedDirectStrikethrough: DirectTextStyle?
  private var cachedLink: AttributeContainer?

  init(attributes: AttributeContainer, inlineStyles: InlineTextStyles) {
    self.base = attributes
    let resolvedBase = AttributedStringInlineRenderer.resolvingFont(in: attributes)
    self.resolvedBase = resolvedBase
    self.directBase = DirectTextStyle(resolved: resolvedBase)
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

  func directCode() -> DirectTextStyle {
    if let cached = self.cachedDirectCode { return cached }
    let direct = DirectTextStyle(resolved: self.resolvedCode())
    self.cachedDirectCode = direct
    return direct
  }

  func resolvedStrong() -> AttributeContainer {
    if let cached = self.cachedStrong { return cached }
    let resolved = AttributedStringInlineRenderer.resolvingFont(
      in: self.inlineStyles.strong.mergingAttributes(self.base)
    )
    self.cachedStrong = resolved
    return resolved
  }

  func directStrong() -> DirectTextStyle {
    if let cached = self.cachedDirectStrong { return cached }
    let direct = DirectTextStyle(resolved: self.resolvedStrong())
    self.cachedDirectStrong = direct
    return direct
  }

  func resolvedEmphasis() -> AttributeContainer {
    if let cached = self.cachedEmphasis { return cached }
    let resolved = AttributedStringInlineRenderer.resolvingFont(
      in: self.inlineStyles.emphasis.mergingAttributes(self.base)
    )
    self.cachedEmphasis = resolved
    return resolved
  }

  func directEmphasis() -> DirectTextStyle {
    if let cached = self.cachedDirectEmphasis { return cached }
    let direct = DirectTextStyle(resolved: self.resolvedEmphasis())
    self.cachedDirectEmphasis = direct
    return direct
  }

  func resolvedStrikethrough() -> AttributeContainer {
    if let cached = self.cachedStrikethrough { return cached }
    let resolved = AttributedStringInlineRenderer.resolvingFont(
      in: self.inlineStyles.strikethrough.mergingAttributes(self.base)
    )
    self.cachedStrikethrough = resolved
    return resolved
  }

  func directStrikethrough() -> DirectTextStyle {
    if let cached = self.cachedDirectStrikethrough { return cached }
    let direct = DirectTextStyle(resolved: self.resolvedStrikethrough())
    self.cachedDirectStrikethrough = direct
    return direct
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
