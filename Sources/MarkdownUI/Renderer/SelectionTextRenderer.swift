import Foundation

extension MarkdownContent {
  /// A continuous attributed document for native selection and rich copying.
  /// Preserves links and inline presentation intents, block separators, list
  /// markers and tab-separated table cells. Images contribute their alt text.
  /// Consumers supply platform fonts/colours; no HTML or web view is involved.
  public func renderAttributedString(softBreaks: Bool = false, baseURL: URL? = nil) -> AttributedString {
    SelectionTextRenderer(softBreaks: softBreaks, baseURL: baseURL).blocks(self.blocks)
  }
}

private struct SelectionTextRenderer {
  let softBreaks: Bool
  let baseURL: URL?

  func blocks(_ nodes: [BlockNode], separator: String = "\n\n") -> AttributedString {
    joined(nodes.map(block), separator: separator)
  }

  private func block(_ node: BlockNode) -> AttributedString {
    switch node {
    case .paragraph(let content): return inlines(content)
    case .heading(_, let content): return styled(inlines(content), .stronglyEmphasized)
    case .blockquote(let children): return AttributedString("❯ ") + blocks(children)
    case .bulletedList(_, let items):
      return joined(items.map { AttributedString("• ") + blocks($0.children, separator: "\n") }, separator: "\n")
    case .numberedList(_, let start, let items):
      return joined(items.enumerated().map { AttributedString("\(start + $0.offset). ") + blocks($0.element.children, separator: "\n") }, separator: "\n")
    case .taskList(_, let items):
      return joined(items.map { AttributedString($0.isCompleted ? "☑ " : "☐ ") + blocks($0.children, separator: "\n") }, separator: "\n")
    case .codeBlock(_, let content):
      return styled(AttributedString(content.hasSuffix("\n") ? String(content.dropLast()) : content), .code)
    case .htmlBlock(let content): return AttributedString(content)
    case .thematicBreak: return AttributedString("―")
    case .table(_, let rows):
      return joined(rows.enumerated().map { index, row in
        let text = joined(row.cells.map { inlines($0.content) }, separator: "\t")
        return index == 0 ? styled(text, .stronglyEmphasized) : text
      }, separator: "\n")
    }
  }

  private func inlines(_ nodes: [InlineNode]) -> AttributedString {
    joined(nodes.map { node in
      switch node {
      case .text(let text): return AttributedString(text)
      case .softBreak: return AttributedString(softBreaks ? "\n" : " ")
      case .lineBreak: return AttributedString("\n")
      case .code(let text): return styled(AttributedString(text), .code)
      case .html(let text):
        return AttributedString(text.lowercased().hasPrefix("<br") ? "\n" : text)
      case .emphasis(let children): return styled(inlines(children), .emphasized)
      case .strong(let children): return styled(inlines(children), .stronglyEmphasized)
      case .strikethrough(let children): return styled(inlines(children), .strikethrough)
      case .link(let destination, let children):
        var text = inlines(children)
        text.link = URL(string: destination, relativeTo: baseURL)
        return text
      case .image(_, let children): return inlines(children)
      }
    }, separator: "")
  }

  private func styled(_ text: AttributedString, _ intent: InlinePresentationIntent) -> AttributedString {
    var text = text
    for run in text.runs {
      text[run.range].inlinePresentationIntent = (run.inlinePresentationIntent ?? []).union(intent)
    }
    return text
  }

  private func joined(_ values: [AttributedString], separator: String) -> AttributedString {
    var result = AttributedString()
    for (index, value) in values.enumerated() {
      if index > 0 { result += AttributedString(separator) }
      result += value
    }
    return result
  }
}
