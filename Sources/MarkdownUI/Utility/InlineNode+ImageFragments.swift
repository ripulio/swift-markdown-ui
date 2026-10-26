import Foundation

enum InlineImageFragment: Hashable {
  case text([InlineNode])
  case image(RawImageData)
}

extension Array where Element == InlineNode {
  /// Keep images as actual image views so they can fit their proposal, expose
  /// alt text and open an enclosing link. Styled text on either side keeps its
  /// original inline nodes; references have already been resolved by the parser.
  func imageFragments() -> [InlineImageFragment] {
    var fragments: [InlineImageFragment] = []
    var text: [InlineNode] = []
    for node in self {
      for fragment in node.imageFragments() {
        switch fragment {
        case .text(let nodes): text += nodes
        case .image:
          if !text.isEmpty { fragments.append(.text(text)); text = [] }
          fragments.append(fragment)
        }
      }
    }
    if !text.isEmpty { fragments.append(.text(text)) }
    return fragments
  }
}

extension InlineNode {
  fileprivate func imageFragments() -> [InlineImageFragment] {
    if let data = imageData { return [.image(data)] }
    let wrap: ([InlineNode]) -> InlineNode
    switch self {
    case .strong: wrap = { .strong(children: $0) }
    case .emphasis: wrap = { .emphasis(children: $0) }
    case .strikethrough: wrap = { .strikethrough(children: $0) }
    case .link(let destination, _): wrap = { .link(destination: destination, children: $0) }
    default: return [.text([self])]
    }
    return children.imageFragments().map {
      switch $0 {
      case .text(let nodes): return .text([wrap(nodes)])
      case .image(var data):
        if case .link(let destination, _) = self { data.destination = destination }
        return .image(data)
      }
    }
  }
}
