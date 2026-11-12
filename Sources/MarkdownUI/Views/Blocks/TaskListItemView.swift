import SwiftUI

struct TaskListItemView: View {
  @Environment(\.theme.listItem) private var listItem
  @Environment(\.theme.taskListMarker) private var taskListMarker
  @Environment(\.markdownBlockMargins) private var staticBlockMargins
  @Environment(\.usesDeclarativeBlockMargins) private var usesDeclarativeBlockMargins

  private let item: RawTaskListItem

  init(item: RawTaskListItem) {
    self.item = item
  }

  var body: some View {
    let canSkipMarginPreference = self.staticBlockMargins != nil || self.usesDeclarativeBlockMargins
    if self.listItem.isIdentity || (self.listItem.isMarginOnly && canSkipMarginPreference) {
      self.label
    } else {
      self.listItem.makeBody(
        configuration: .init(
          label: .init(self.label),
          content: .init(blocks: item.children)
        )
      )
    }
  }

  private var label: some View {
    Label {
      if self.item.children.count == 1,
        case .paragraph(let inlines) = self.item.children[0]
      {
        ParagraphView(content: inlines)
      } else {
        BlockSequence(self.item.children)
      }
    } icon: {
      self.taskListMarker.makeBody(configuration: .init(isCompleted: self.item.isCompleted))
        .textStyleFont()
    }
  }
}
