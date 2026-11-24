import SwiftUI

struct CodeBlockView: View, Equatable {
  @Environment(\.theme.codeBlock) private var codeBlock
  @Environment(\.codeSyntaxHighlighter) private var codeSyntaxHighlighter
  @Environment(\.markdownBlockPath) private var blockPath

  private let fenceInfo: String?
  private let content: String

  init(fenceInfo: String?, content: String) {
    self.fenceInfo = fenceInfo
    self.content = content.hasSuffix("\n") ? String(content.dropLast()) : content
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.fenceInfo == rhs.fenceInfo && lhs.content == rhs.content
  }

  var body: some View {
    self.codeBlock.makeBody(
      configuration: .init(
        language: self.fenceInfo?.split(whereSeparator: \.isWhitespace).first.map(String.init),
        content: self.content,
        blockPath: self.blockPath,
        label: .init(self.label)
      )
    )
  }

  private var label: some View {
    self.codeSyntaxHighlighter.highlightCode(
      self.content,
      language: self.fenceInfo?.split(whereSeparator: \.isWhitespace).first.map(String.init)
    )
      .textStyleFont()
      .textStyleForegroundColor()
  }
}
