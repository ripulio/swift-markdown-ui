import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct TableView: View {
  @Environment(\.theme.table) private var table

  private let columnAlignments: [RawTableColumnAlignment]
  private let rows: [RawTableRow]

  init(columnAlignments: [RawTableColumnAlignment], rows: [RawTableRow]) {
    self.columnAlignments = columnAlignments
    self.rows = rows
  }

  var body: some View {
    self.table.makeBody(
      configuration: .init(
        label: .init(TableContentView(columnAlignments: self.columnAlignments, rows: self.rows)),
        content: .init(block: .table(columnAlignments: self.columnAlignments, rows: self.rows))
      )
    )
  }
}

// Read sizing and decoration inside the theme's label so modifiers applied by
// a custom table style reach the content, rather than its TableView parent.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct TableContentView: View {
  @Environment(\.tableBorderStyle.strokeStyle.lineWidth) private var borderWidth
  @Environment(\.tableLayoutStyle) private var layoutStyle

  let columnAlignments: [RawTableColumnAlignment]
  let rows: [RawTableRow]

  var body: some View {
    self.cells
      .padding(self.borderWidth)
      .tableDecoration(
        rowCount: self.rowCount,
        columnCount: self.columnCount,
        background: TableBackgroundView.init,
        overlay: TableBorderView.init
      )
  }

  @ViewBuilder private var cells: some View {
    switch self.layoutStyle {
    case .automatic:
      self.grid
    case let .adaptive(availableWidth, minimumColumnWidth, maximumColumnWidth):
      AdaptiveTableLayout(
        columnCount: self.columnCount,
        spacing: self.borderWidth,
        availableWidth: max(0, availableWidth - 2 * self.borderWidth),
        minimumColumnWidth: minimumColumnWidth,
        maximumColumnWidth: maximumColumnWidth
      ) {
        ForEach(0..<(self.rowCount * self.columnCount), id: \.self) { index in
          self.cell(row: index / self.columnCount, column: index % self.columnCount)
        }
      }
    }
  }

  private var grid: some View {
    Grid(horizontalSpacing: self.borderWidth, verticalSpacing: self.borderWidth) {
      ForEach(0..<self.rowCount, id: \.self) { row in
        GridRow {
          ForEach(0..<self.columnCount, id: \.self) { column in
            self.cell(row: row, column: column)
              .gridColumnAlignment(.init(self.columnAlignments[column]))
          }
        }
      }
    }
  }

  private func cell(row: Int, column: Int) -> some View {
    TableCell(
      row: row, column: column, cell: self.rows[row].cells[column],
      alignment: .init(self.columnAlignments[column])
    )
  }

  private var rowCount: Int {
    self.rows.count
  }

  private var columnCount: Int {
    self.columnAlignments.count
  }
}

extension TextAlignment {
  fileprivate init(_ alignment: RawTableColumnAlignment) {
    switch alignment {
    case .none, .left: self = .leading
    case .center: self = .center
    case .right: self = .trailing
    }
  }
}

extension HorizontalAlignment {
  fileprivate init(_ rawTableColumnAlignment: RawTableColumnAlignment) {
    switch rawTableColumnAlignment {
    case .none, .left:
      self = .leading
    case .center:
      self = .center
    case .right:
      self = .trailing
    }
  }
}
