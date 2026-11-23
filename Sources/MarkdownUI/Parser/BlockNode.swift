import Foundation

enum BlockNode: Hashable {
  case blockquote(children: [BlockNode])
  case bulletedList(isTight: Bool, items: [RawListItem])
  case numberedList(isTight: Bool, start: Int, items: [RawListItem])
  case taskList(isTight: Bool, items: [RawTaskListItem])
  case codeBlock(fenceInfo: String?, content: String)
  case htmlBlock(content: String)
  case paragraph(content: [InlineNode])
  case heading(level: Int, content: [InlineNode])
  case table(columnAlignments: [RawTableColumnAlignment], rows: [RawTableRow])
  case thematicBreak
}

extension BlockNode {
  var children: [BlockNode] {
    switch self {
    case .blockquote(let children):
      return children
    case .bulletedList(_, let items):
      return items.map(\.children).flatMap { $0 }
    case .numberedList(_, _, let items):
      return items.map(\.children).flatMap { $0 }
    case .taskList(_, let items):
      return items.map(\.children).flatMap { $0 }
    default:
      return []
    }
  }

  var isParagraph: Bool {
    guard case .paragraph = self else { return false }
    return true
  }

  var containsImage: Bool {
    switch self {
    case .blockquote(let children):
      return children.contains(where: \.containsImage)
    case .bulletedList(_, let items), .numberedList(_, _, let items):
      return items.contains { $0.children.contains(where: \.containsImage) }
    case .taskList(_, let items):
      return items.contains { $0.children.contains(where: \.containsImage) }
    case .paragraph(let content), .heading(_, let content):
      return content.contains(where: \.containsImage)
    case .table(_, let rows):
      return rows.contains { row in
        row.cells.contains { $0.content.contains(where: \.containsImage) }
      }
    case .codeBlock, .htmlBlock, .thematicBreak:
      return false
    }
  }

  var containsLink: Bool {
    switch self {
    case .blockquote(let children):
      return children.contains(where: \.containsLink)
    case .bulletedList(_, let items), .numberedList(_, _, let items):
      return items.contains(where: \.containsLink)
    case .taskList(_, let items):
      return items.contains(where: \.containsLink)
    case .paragraph(let content), .heading(_, let content):
      return content.contains(where: \.containsLink)
    case .table(_, let rows):
      return rows.contains { row in
        row.cells.contains { $0.content.contains(where: \.containsLink) }
      }
    case .codeBlock, .htmlBlock, .thematicBreak:
      return false
    }
  }
}

struct RawListItem: Hashable {
  let children: [BlockNode]

  var containsLink: Bool {
    self.children.contains(where: \.containsLink)
  }
}

struct RawTaskListItem: Hashable {
  let isCompleted: Bool
  let children: [BlockNode]

  var containsLink: Bool {
    self.children.contains(where: \.containsLink)
  }
}

extension Array where Element == RawListItem {
  /// True when any link in the list sits above another item or sibling block in the same list.
  /// On iOS, SwiftUI's `.textSelection(.enabled)` gives each selectable `Text` a ±16 pt hit-test
  /// responder while its `TextSelectionInteractionView` only accepts hits inside its exact text
  /// bounds, so a following item eclipses links on the line above it.
  var hasOccludedListLink: Bool {
    self.dropLast().contains(where: \.containsLink)
      || self.contains { $0.children.dropLast().contains(where: \.containsLink) }
  }
}

extension Array where Element == RawTaskListItem {
  var hasOccludedListLink: Bool {
    self.dropLast().contains(where: \.containsLink)
      || self.contains { $0.children.dropLast().contains(where: \.containsLink) }
  }
}

enum RawTableColumnAlignment: Character {
  case none = "\0"
  case left = "l"
  case center = "c"
  case right = "r"
}

struct RawTableRow: Hashable {
  let cells: [RawTableCell]
}

struct RawTableCell: Hashable {
  let content: [InlineNode]
}
