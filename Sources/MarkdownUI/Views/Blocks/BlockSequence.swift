import SwiftUI

struct BlockSequence<Data, Content>: View
where
  Data: Sequence,
  Data.Element: BlockMarginElement,
  Content: View
{
  @Environment(\.multilineTextAlignment) private var textAlignment
  @Environment(\.tightSpacingEnabled) private var tightSpacingEnabled
  @Environment(\.markdownBlockPath) private var blockPath
  @Environment(\.markdownBlockMargins) private var staticBlockMargins
  @Environment(\.inlineImageFlow) private var inlineImageFlow

  private let data: [Indexed<Data.Element>]
  private let content: (Int, Data.Element) -> Content

  init(
    _ data: Data,
    @ViewBuilder content: @escaping (_ index: Int, _ element: Data.Element) -> Content
  ) {
    self.data = data.indexed()
    self.content = content
  }

  var body: some View {
    if let staticBlockMargins = self.staticBlockMargins {
      StaticBlockSequenceContent(
        data: self.data,
        content: self.content,
        margins: staticBlockMargins,
        inlineImageFlow: self.inlineImageFlow,
        textAlignment: self.textAlignment,
        tightSpacingEnabled: self.tightSpacingEnabled,
        blockPath: self.blockPath
      )
    } else {
      DynamicBlockSequenceContent(
        data: self.data,
        content: self.content,
        textAlignment: self.textAlignment,
        tightSpacingEnabled: self.tightSpacingEnabled,
        blockPath: self.blockPath
      )
    }
  }
}

private struct StaticBlockSequenceContent<Element: BlockMarginElement, Content: View>: View {
  let data: [Indexed<Element>]
  let content: (Int, Element) -> Content
  let margins: MarkdownBlockMargins
  let inlineImageFlow: Bool
  let textAlignment: TextAlignment
  let tightSpacingEnabled: Bool
  let blockPath: [Int]

  var body: some View {
    let resolved = self.data.map {
      $0.value.effectiveMargin(using: self.margins, inlineImageFlow: self.inlineImageFlow)
    }
    VStack(alignment: self.textAlignment.alignment.horizontal, spacing: 0) {
      ForEach(self.data, id: \.index) { element in
        self.content(element.index, element.value)
          .environment(\.markdownBlockPath, self.blockPath + [element.index])
          .padding(.top, self.topPaddingLength(at: element.index, margins: resolved))
      }
    }
  }

  private func topPaddingLength(at index: Int, margins: [BlockMargin]) -> CGFloat? {
    guard index > 0 else {
      return 0
    }
    let topSpacing = margins[index].top
    let predecessorBottomSpacing =
      self.tightSpacingEnabled ? 0 : margins[index - 1].bottom
    return BlockMargin.max(topSpacing, predecessorBottomSpacing)
  }
}

private struct DynamicBlockSequenceContent<Element: Hashable, Content: View>: View {
  @State private var blockMargins: [Int: BlockMargin] = [:]

  let data: [Indexed<Element>]
  let content: (Int, Element) -> Content
  let textAlignment: TextAlignment
  let tightSpacingEnabled: Bool
  let blockPath: [Int]

  var body: some View {
    VStack(alignment: self.textAlignment.alignment.horizontal, spacing: 0) {
      // A streamed edit changes a block's value, not its position. Keying by the
      // entire value recreates the view (and its local state) for every token.
      ForEach(self.data, id: \.index) { element in
        self.content(element.index, element.value)
          .environment(\.markdownBlockPath, self.blockPath + [element.index])
          .onPreferenceChange(BlockMarginsPreference.self) { value in
            self.blockMargins[element.index] = value
          }
          .padding(.top, self.topPaddingLength(for: element))
      }
    }
  }

  private func topPaddingLength(for element: Indexed<Element>) -> CGFloat? {
    guard element.index > 0 else {
      return 0
    }

    let topSpacing = self.blockMargins[element.index]?.top
    let predecessor = self.data[element.index - 1]
    let predecessorBottomSpacing =
      self.tightSpacingEnabled ? 0 : self.blockMargins[predecessor.index]?.bottom

    return BlockMargin.max(topSpacing, predecessorBottomSpacing)
  }
}

extension BlockSequence where Data == [BlockNode], Content == BlockNode {
  init(_ blocks: [BlockNode]) {
    self.init(blocks) { $1 }
  }
}

extension TextAlignment {
  var alignment: Alignment {
    switch self {
    case .leading:
      return .leading
    case .center:
      return .center
    case .trailing:
      return .trailing
    }
  }
}
