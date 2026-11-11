import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct TableCell: View {
  @Environment(\.theme.tableCell) private var tableCell

  private let row: Int
  private let column: Int
  private let cell: RawTableCell
  private let alignment: TextAlignment
  private let tracksCellBounds: Bool

  init(
    row: Int,
    column: Int,
    cell: RawTableCell,
    alignment: TextAlignment,
    tracksCellBounds: Bool = true
  ) {
    self.row = row
    self.column = column
    self.cell = cell
    self.alignment = alignment
    self.tracksCellBounds = tracksCellBounds
  }

  var body: some View {
    let styled = self.tableCell.makeBody(
      configuration: .init(
        row: self.row,
        column: self.column,
        alignment: self.alignment,
        label: .init(self.label),
        content: .init(block: .paragraph(content: cell.content))
      )
    )
    if self.tracksCellBounds {
      styled.tableCellBounds(forRow: self.row, column: self.column)
    } else {
      styled
    }
  }

  @ViewBuilder private var label: some View {
    if let imageFlow = ImageFlow(self.cell.content) {
      imageFlow
    } else {
      InlineText(self.cell.content)
    }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct LightweightTableCell: View {
  let row: Int
  let cell: RawTableCell
  let alignment: TextAlignment
  let style: MarkdownTableCellStyle

  var body: some View {
    self.styledLabel
      .multilineTextAlignment(self.alignment)
      .fixedSize(horizontal: false, vertical: true)
      .padding(self.style.padding)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: self.frameAlignment)
  }

  @ViewBuilder private var styledLabel: some View {
    if self.row == 0, let weight = self.style.headerFontWeight {
      self.rawLabel.textStyle(FontWeight(weight))
    } else {
      self.rawLabel
    }
  }

  @ViewBuilder private var rawLabel: some View {
    if let imageFlow = ImageFlow(self.cell.content) {
      imageFlow
    } else {
      InlineText(self.cell.content)
    }
  }

  private var frameAlignment: Alignment {
    switch self.alignment {
    case .leading:
      return .topLeading
    case .center:
      return .top
    case .trailing:
      return .topTrailing
    }
  }
}
