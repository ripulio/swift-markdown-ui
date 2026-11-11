import SwiftUI

extension RandomAccessCollection where Element == InlineNode {
  func renderCompactText(
    baseURL: URL?,
    softBreakMode: SoftBreak.Mode,
    cache: PrecomputedInlineAttributes
  ) -> Text {
    if self.count == 1, let first = self.first, case .text(let content) = first {
      return content.isEmpty
        ? Text("")
        : Text(AttributedString(content, attributes: cache.resolvedBase))
    }
    var renderer = CompactInlineRenderer(
      baseURL: baseURL,
      softBreakMode: softBreakMode,
      cache: cache
    )
    for inline in self {
      renderer.render(inline)
    }
    return renderer.result
  }
}

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

private struct CompactInlineRenderer {
  private let baseURL: URL?
  private let softBreakMode: SoftBreak.Mode
  private let cache: PrecomputedInlineAttributes
  private var pendingPlain = ""
  private var shouldSkipNextWhitespace = false

  init(
    baseURL: URL?,
    softBreakMode: SoftBreak.Mode,
    cache: PrecomputedInlineAttributes
  ) {
    self.baseURL = baseURL
    self.softBreakMode = softBreakMode
    self.cache = cache
  }

  var result: Text {
    mutating get {
      self.flushPending()
      return self.accumulated.characters.isEmpty ? Text("") : Text(self.accumulated)
    }
  }

  private var accumulated = AttributedString()

  mutating func render(_ inline: InlineNode) {
    switch inline {
    case .text(let content):
      if self.shouldSkipNextWhitespace {
        self.shouldSkipNextWhitespace = false
        if content.first?.isWhitespace == true {
          self.pendingPlain += content.drop(while: \.isWhitespace)
          return
        }
      }
      self.pendingPlain += content

    case .softBreak:
      switch self.softBreakMode {
      case .space where self.shouldSkipNextWhitespace:
        self.shouldSkipNextWhitespace = false
      case .space:
        self.pendingPlain.append(" ")
      case .lineBreak:
        self.shouldSkipNextWhitespace = true
        self.pendingPlain.append("\n")
      }

    case .lineBreak:
      self.shouldSkipNextWhitespace = false
      self.pendingPlain.append("\n")

    case .html(let html):
      if HTMLTag(html)?.name.lowercased() == "br" {
        self.pendingPlain.append("\n")
        self.shouldSkipNextWhitespace = true
      } else {
        if self.shouldSkipNextWhitespace {
          self.shouldSkipNextWhitespace = false
          if html.first?.isWhitespace == true {
            self.pendingPlain += html.drop(while: \.isWhitespace)
            return
          }
        }
        self.pendingPlain += html
      }

    case .code(let code):
      self.shouldSkipNextWhitespace = false
      self.flushPending()
      self.appendRun(code, attributes: self.cache.resolvedCode())

    case .strong(let children) where children.count == 1:
      self.shouldSkipNextWhitespace = false
      self.flushPending()
      if case .text(let s) = children[0] {
        self.appendRun(s, attributes: self.cache.resolvedStrong())
      } else {
        self.renderComplex(inline)
      }

    case .emphasis(let children) where children.count == 1:
      self.shouldSkipNextWhitespace = false
      self.flushPending()
      if case .text(let s) = children[0] {
        self.appendRun(s, attributes: self.cache.resolvedEmphasis())
      } else {
        self.renderComplex(inline)
      }

    case .strikethrough(let children) where children.count == 1:
      self.shouldSkipNextWhitespace = false
      self.flushPending()
      if case .text(let s) = children[0] {
        self.appendRun(s, attributes: self.cache.resolvedStrikethrough())
      } else {
        self.renderComplex(inline)
      }

    case .link(let destination, let children) where children.count == 1:
      self.shouldSkipNextWhitespace = false
      self.flushPending()
      if case .text(let s) = children[0] {
        var attrs = self.cache.resolvedLink()
        attrs.link = URL(string: destination, relativeTo: self.baseURL)
        self.appendRun(s, attributes: attrs)
      } else {
        self.renderComplex(inline)
      }

    default:
      self.shouldSkipNextWhitespace = false
      self.flushPending()
      self.renderComplex(inline)
    }
  }

  private mutating func flushPending() {
    guard !self.pendingPlain.isEmpty else { return }
    let run = AttributedString(self.pendingPlain, attributes: self.cache.resolvedBase)
    self.pendingPlain.removeAll(keepingCapacity: true)
    if self.accumulated.characters.isEmpty {
      self.accumulated = run
    } else {
      self.accumulated += run
    }
  }

  private mutating func appendRun(_ text: String, attributes: AttributeContainer) {
    guard !text.isEmpty else { return }
    let run = AttributedString(text, attributes: attributes)
    if self.accumulated.characters.isEmpty {
      self.accumulated = run
    } else {
      self.accumulated += run
    }
  }

  private mutating func renderComplex(_ inline: InlineNode) {
    var fallback = AttributedStringInlineRenderer(
      baseURL: self.baseURL,
      textStyles: self.cache.inlineStyles,
      softBreakMode: self.softBreakMode,
      attributes: self.cache.base,
      preResolvedAttributes: self.cache.resolvedBase,
      resolvesFontsInline: true
    )
    fallback.render(inline)
    let rendered = fallback.result
    guard !rendered.characters.isEmpty else { return }
    if self.accumulated.characters.isEmpty {
      self.accumulated = rendered
    } else {
      self.accumulated += rendered
    }
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
