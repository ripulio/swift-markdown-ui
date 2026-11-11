import SwiftUI

struct ListItemSequence: View {
  private let items: [RawListItem]
  private let start: Int
  private let markerStyle: BlockStyle<ListMarkerConfiguration>
  private let markerWidth: CGFloat?
  private let readsMarkerWidth: Bool

  init(
    items: [RawListItem],
    start: Int = 1,
    markerStyle: BlockStyle<ListMarkerConfiguration>,
    markerWidth: CGFloat? = nil,
    readsMarkerWidth: Bool = true
  ) {
    self.items = items
    self.start = start
    self.markerStyle = markerStyle
    self.markerWidth = markerWidth
    self.readsMarkerWidth = readsMarkerWidth
  }

  var body: some View {
    BlockSequence(self.items) { index, item in
      ListItemView(
        item: item,
        number: self.start + index,
        markerStyle: self.markerStyle,
        markerWidth: self.markerWidth,
        readsMarkerWidth: self.readsMarkerWidth
      )
    }
    .labelStyle(.titleAndIcon)
  }
}
