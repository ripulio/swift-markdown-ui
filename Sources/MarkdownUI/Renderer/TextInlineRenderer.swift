import SwiftUI

extension Sequence where Element == InlineNode {
  func renderText(
    baseURL: URL?,
    textStyles: InlineTextStyles,
    images: [String: Image],
    softBreakMode: SoftBreak.Mode,
    attributes: AttributeContainer,
    preResolveFonts: Bool = false
  ) -> Text {
    var renderer = TextInlineRenderer(
      baseURL: baseURL,
      textStyles: textStyles,
      images: images,
      softBreakMode: softBreakMode,
      attributes: attributes,
      preResolveFonts: preResolveFonts
    )
    renderer.render(self)
    return renderer.result
  }
}

private struct TextInlineRenderer {
  // One Text per run between images, rather than a recursively nested Text for
  // every word/style/line break. Long streamed paragraphs otherwise overflow
  // SwiftUI's text storage and can intermittently lose inline attributes.
  private var text = AttributedString()
  private var components: [Text] = []
  private var runRenderer: AttributedStringInlineRenderer?

  var result: Text {
    var components = self.components
    if let run = self.runRenderer?.result, !run.characters.isEmpty {
      components.append(Text(run))
    } else if !self.text.characters.isEmpty {
      components.append(Text(self.text))
    }
    return Self.combine(components[...])
  }

  private static func combine(_ components: ArraySlice<Text>) -> Text {
    guard !components.isEmpty else { return Text("") }
    guard components.count > 1 else { return components.first! }
    let middle = components.index(components.startIndex, offsetBy: components.count / 2)
    return combine(components[..<middle]) + combine(components[middle...])
  }

  private let baseURL: URL?
  private let textStyles: InlineTextStyles
  private let images: [String: Image]
  private let softBreakMode: SoftBreak.Mode
  private let attributes: AttributeContainer
  private var shouldSkipNextWhitespace = false

  init(
    baseURL: URL?,
    textStyles: InlineTextStyles,
    images: [String: Image],
    softBreakMode: SoftBreak.Mode,
    attributes: AttributeContainer,
    preResolveFonts: Bool = false
  ) {
    self.baseURL = baseURL
    self.textStyles = textStyles
    self.images = images
    self.softBreakMode = softBreakMode
    self.attributes = attributes
    if preResolveFonts {
      self.runRenderer = AttributedStringInlineRenderer(
        baseURL: baseURL,
        textStyles: textStyles,
        softBreakMode: softBreakMode,
        attributes: attributes,
        resolvesFontsInline: true
      )
    }
  }

  mutating func render<S: Sequence>(_ inlines: S) where S.Element == InlineNode {
    for inline in inlines {
      self.render(inline)
    }
  }

  private mutating func render(_ inline: InlineNode) {
    switch inline {
    case .text(let content):
      self.renderText(content)
    case .softBreak:
      self.renderSoftBreak()
    case .html(let content):
      self.renderHTML(content)
    case .image(let source, _):
      self.shouldSkipNextWhitespace = false
      self.renderImage(source)
    default:
      // A styled span consumes the start of the line too. Leaving this set
      // strips the meaningful space *after* a leading link/bold/code span.
      self.shouldSkipNextWhitespace = false
      self.defaultRender(inline)
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

    self.defaultRender(.text(text))
  }

  private mutating func renderSoftBreak() {
    switch self.softBreakMode {
    case .space where self.shouldSkipNextWhitespace:
      self.shouldSkipNextWhitespace = false
    case .space:
      self.defaultRender(.softBreak)
    case .lineBreak:
      self.shouldSkipNextWhitespace = true
      self.defaultRender(.lineBreak)
    }
  }

  private mutating func renderHTML(_ html: String) {
    let tag = HTMLTag(html)

    switch tag?.name.lowercased() {
    case "br":
      self.defaultRender(.lineBreak)
      self.shouldSkipNextWhitespace = true
    default:
      self.defaultRender(.html(html))
    }
  }

  private mutating func renderImage(_ source: String) {
    if let image = self.images[source] {
      if self.runRenderer != nil {
        let current = self.runRenderer!.takeResult()
        if !current.characters.isEmpty {
          self.components.append(Text(current))
        }
      } else if !self.text.characters.isEmpty {
        self.components.append(Text(self.text))
        self.text = AttributedString()
      }
      self.components.append(Text(image))
    }
  }

  private mutating func defaultRender(_ inline: InlineNode) {
    if self.runRenderer != nil {
      self.runRenderer!.resetWhitespaceState()
      self.runRenderer!.render(inline)
    } else {
      self.text += inline.renderAttributedString(
        baseURL: self.baseURL,
        textStyles: self.textStyles,
        softBreakMode: self.softBreakMode,
        attributes: self.attributes
      )
    }
  }
}
