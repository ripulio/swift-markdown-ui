import Foundation

struct InlineTextStyles: Equatable {
  let revision: UInt64
  let code: TextStyle
  let emphasis: TextStyle
  let strong: TextStyle
  let strikethrough: TextStyle
  let link: TextStyle

  init(
    revision: UInt64 = StyleRevisionID.next(),
    code: TextStyle,
    emphasis: TextStyle,
    strong: TextStyle,
    strikethrough: TextStyle,
    link: TextStyle
  ) {
    self.revision = revision
    self.code = code
    self.emphasis = emphasis
    self.strong = strong
    self.strikethrough = strikethrough
    self.link = link
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.revision == rhs.revision
  }
}
