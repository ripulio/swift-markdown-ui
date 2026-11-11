import SwiftUI

struct NumberedListView: View {
  @Environment(\.theme.list) private var list
  @Environment(\.theme.numberedListMarker) private var numberedListMarker
  @Environment(\.listLevel) private var listLevel
  @Environment(\.lightweightListMarkers) private var lightweightListMarkers
  @Environment(\.lightweightBlocks) private var lightweightBlocks

  @State private var markerWidth: CGFloat?

  private let isTight: Bool
  private let start: Int
  private let items: [RawListItem]

  init(isTight: Bool, start: Int, items: [RawListItem]) {
    self.isTight = isTight
    self.start = start
    self.items = items
  }

  var body: some View {
    if self.lightweightBlocks, self.list.isIdentity {
      self.label
    } else {
      self.list.makeBody(
        configuration: .init(
          label: .init(self.label),
          content: .init(
            block: .numberedList(
              isTight: self.isTight,
              start: self.start,
              items: self.items
            )
          )
        )
      )
    }
  }

  @ViewBuilder private var label: some View {
    let needsWidthSync = !self.lightweightListMarkers || self.items.count > 1
    let sequence = ListItemSequence(
      items: self.items,
      start: self.start,
      markerStyle: self.numberedListMarker,
      markerWidth: needsWidthSync ? self.markerWidth : nil,
      readsMarkerWidth: needsWidthSync
    )
    .environment(\.listLevel, self.listLevel + 1)
    .environment(\.tightSpacingEnabled, self.isTight)

    if needsWidthSync {
      sequence.onColumnWidthChange { columnWidths in
        self.markerWidth = columnWidths[0]
      }
    } else {
      sequence
    }
  }
}
