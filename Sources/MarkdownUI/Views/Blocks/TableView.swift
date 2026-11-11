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
  @Environment(\.tableCellStyle) private var tableCellStyle
  @Environment(\.lightweightBlocks) private var lightweightBlocks
  @Environment(\.textStyleAttributes) private var textStyleAttributes

  @State private var boundsBox = TableBoundsBox()

  let columnAlignments: [RawTableColumnAlignment]
  let rows: [RawTableRow]

  private var usesDirectBoundsDecoration: Bool {
    guard self.lightweightBlocks else { return false }
    switch self.layoutStyle {
    case .automatic:
      return false
    case .adaptive, .adaptiveDynamic:
      return true
    }
  }

  var body: some View {
    if self.usesDirectBoundsDecoration {
      self.styledCells
        .padding(self.borderWidth)
        .background {
          LightweightTableBackgroundView(boundsBox: self.boundsBox)
        }
        .overlay {
          LightweightTableBorderView(boundsBox: self.boundsBox)
        }
    } else {
      self.cells
        .padding(self.borderWidth)
        .tableDecoration(
          rowCount: self.rowCount,
          columnCount: self.columnCount,
          background: TableBackgroundView.init,
          overlay: TableBorderView.init
        )
    }
  }

  @ViewBuilder private var styledCells: some View {
    if let lineSpacing = self.tableCellStyle?.lineSpacing {
      self.cells
        .lineSpacing(lineSpacing.points(relativeTo: self.textStyleAttributes.fontProperties))
    } else {
      self.cells
    }
  }

  @ViewBuilder private var cells: some View {
    let directDecoration = self.usesDirectBoundsDecoration
    let borderWidth = self.borderWidth
    let boundsBox = self.boundsBox
    let resolveBounds: (([CGFloat], [CGFloat]) -> Void)? =
      directDecoration
      ? { widths, heights in
        boundsBox.value = TableBounds(widths: widths, heights: heights, borderWidth: borderWidth)
      } : nil

    switch self.layoutStyle {
    case .automatic:
      self.grid
    case let .adaptive(availableWidth, minimumColumnWidth, maximumColumnWidth, overflow):
      AdaptiveTableLayout(
        columnCount: self.columnCount,
        spacing: self.borderWidth,
        availableWidth: max(0, availableWidth - 2 * self.borderWidth),
        minimumColumnWidth: minimumColumnWidth,
        maximumColumnWidth: maximumColumnWidth,
        overflow: overflow,
        onResolveBounds: resolveBounds
      ) {
        self.adaptiveCellItems(directDecoration: directDecoration)
      }
    case let .adaptiveDynamic(configuration):
      let borderInset = 2 * self.borderWidth
      AdaptiveTableLayout(
        columnCount: self.columnCount,
        spacing: self.borderWidth,
        resolveAvailableWidth: {
          max(0, configuration.availableWidth() - borderInset)
        },
        minimumColumnWidth: configuration.minimumColumnWidth,
        maximumColumnWidth: configuration.maximumColumnWidth,
        overflow: configuration.overflow,
        onMeasureWidth: { innerWidth in
          configuration.onMeasureWidth?(innerWidth + borderInset)
        },
        onResolveBounds: resolveBounds,
        cachesMeasurements: true,
        canReuseUnwrappedCellHeights: !self.hasImageCells
      ) {
        self.adaptiveCellItems(directDecoration: directDecoration)
      }
    }
  }

  @ViewBuilder private func adaptiveCellItems(directDecoration: Bool) -> some View {
    if directDecoration, let cellStyle = self.tableCellStyle {
      ForEach(0..<(self.rowCount * self.columnCount), id: \.self) { index in
        let row = index / self.columnCount
        let column = index % self.columnCount
        LightweightTableCell(
          row: row,
          cell: self.rows[row].cells[column],
          alignment: .init(self.columnAlignments[column]),
          style: cellStyle
        )
      }
    } else {
      ForEach(0..<(self.rowCount * self.columnCount), id: \.self) { index in
        self.cell(
          row: index / self.columnCount,
          column: index % self.columnCount,
          tracksCellBounds: !directDecoration
        )
      }
    }
  }

  private var hasImageCells: Bool {
    self.rows.contains { row in
      row.cells.contains { cell in
        cell.content.contains(where: \.containsImage)
      }
    }
  }

  private var grid: some View {
    Grid(horizontalSpacing: self.borderWidth, verticalSpacing: self.borderWidth) {
      ForEach(0..<self.rowCount, id: \.self) { row in
        GridRow {
          ForEach(0..<self.columnCount, id: \.self) { column in
            self.cell(row: row, column: column, tracksCellBounds: true)
              .gridColumnAlignment(.init(self.columnAlignments[column]))
          }
        }
      }
    }
  }

  private func cell(row: Int, column: Int, tracksCellBounds: Bool) -> some View {
    TableCell(
      row: row,
      column: column,
      cell: self.rows[row].cells[column],
      alignment: .init(self.columnAlignments[column]),
      tracksCellBounds: tracksCellBounds
    )
  }

  private var rowCount: Int {
    self.rows.count
  }

  private var columnCount: Int {
    self.columnAlignments.count
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct LightweightTableBackgroundView: View {
  @Environment(\.tableBackgroundStyle) private var tableBackgroundStyle
  let boundsBox: TableBoundsBox

  var body: some View {
    switch self.tableBackgroundStyle.fastBatching {
    case .clear:
      EmptyView()
    case let .alternatingRows(odd, oddIsClear, even, evenIsClear, header, headerIsClear):
      ZStack(alignment: .topLeading) {
        if !headerIsClear {
          TableRowCellsShape(boundsBox: self.boundsBox, kind: .header)
            .fill(header)
        }
        if !oddIsClear {
          TableRowCellsShape(boundsBox: self.boundsBox, kind: .oddBody)
            .fill(odd)
        }
        if !evenIsClear {
          TableRowCellsShape(boundsBox: self.boundsBox, kind: .evenBody)
            .fill(even)
        }
      }
      .allowsHitTesting(false)
    case nil:
      Canvas { context, _ in
        guard let tableBounds = self.boundsBox.value else { return }
        for row in 0..<tableBounds.rowCount {
          for column in 0..<tableBounds.columnCount {
            let rect = tableBounds.bounds(forRow: row, column: column)
            context.fill(
              Path(rect),
              with: .style(self.tableBackgroundStyle.background(row, column))
            )
          }
        }
      }
      .allowsHitTesting(false)
    }
  }
}

private struct TableRowCellsShape: Shape {
  enum Kind {
    case header
    case oddBody
    case evenBody
  }

  let boundsBox: TableBoundsBox
  let kind: Kind

  func path(in _: CGRect) -> Path {
    var path = Path()
    guard let tableBounds = self.boundsBox.value,
      tableBounds.rowCount > 0,
      tableBounds.columnCount > 0
    else {
      return path
    }
    switch self.kind {
    case .header:
      for column in 0..<tableBounds.columnCount {
        path.addRect(tableBounds.bounds(forRow: 0, column: column))
      }
    case .oddBody:
      var row = 1
      while row < tableBounds.rowCount {
        for column in 0..<tableBounds.columnCount {
          path.addRect(tableBounds.bounds(forRow: row, column: column))
        }
        row += 2
      }
    case .evenBody:
      var row = 2
      while row < tableBounds.rowCount {
        for column in 0..<tableBounds.columnCount {
          path.addRect(tableBounds.bounds(forRow: row, column: column))
        }
        row += 2
      }
    }
    return path
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct LightweightTableBorderView: View {
  @Environment(\.tableBorderStyle) private var tableBorderStyle
  let boundsBox: TableBoundsBox

  var body: some View {
    let borderWidth = self.tableBorderStyle.strokeStyle.lineWidth
    if let groupBuilder = self.tableBorderStyle.visibleBorders.disjointGroups {
      ZStack(alignment: .topLeading) {
        TableBorderGroupShape(boundsBox: self.boundsBox, borderWidth: borderWidth, groupIndex: 0, groupBuilder: groupBuilder)
          .stroke(self.tableBorderStyle.color, style: self.tableBorderStyle.strokeStyle)
        TableBorderGroupShape(boundsBox: self.boundsBox, borderWidth: borderWidth, groupIndex: 1, groupBuilder: groupBuilder)
          .stroke(self.tableBorderStyle.color, style: self.tableBorderStyle.strokeStyle)
        TableBorderGroupShape(boundsBox: self.boundsBox, borderWidth: borderWidth, groupIndex: 2, groupBuilder: groupBuilder)
          .stroke(self.tableBorderStyle.color, style: self.tableBorderStyle.strokeStyle)
      }
      .allowsHitTesting(false)
    } else {
      Canvas { context, _ in
        guard let tableBounds = self.boundsBox.value else { return }
        let halfWidth = borderWidth / 2
        let rectangles = self.tableBorderStyle.visibleBorders.rectangles(tableBounds, borderWidth)
        let shading = GraphicsContext.Shading.color(self.tableBorderStyle.color)
        let style = self.tableBorderStyle.strokeStyle
        for rectangle in rectangles {
          let path = Rectangle().inset(by: halfWidth).path(in: rectangle)
          context.stroke(path, with: shading, style: style)
        }
      }
      .allowsHitTesting(false)
    }
  }
}

private struct TableBorderGroupShape: Shape {
  let boundsBox: TableBoundsBox
  let borderWidth: CGFloat
  let groupIndex: Int
  let groupBuilder: @Sendable (TableBounds, CGFloat) -> [[CGRect]]

  func path(in _: CGRect) -> Path {
    var path = Path()
    guard let tableBounds = self.boundsBox.value else { return path }
    let groups = self.groupBuilder(tableBounds, self.borderWidth)
    guard self.groupIndex < groups.count else { return path }
    let halfWidth = self.borderWidth / 2
    let insetShape = Rectangle().inset(by: halfWidth)
    for rectangle in groups[self.groupIndex] {
      path.addPath(insetShape.path(in: rectangle))
    }
    return path
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
