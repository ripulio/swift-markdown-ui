import SwiftUI

/// Single-pass layout for numbered lists (`[marker_0, item_0, marker_1, item_1, ...]`).
/// Computes the maximum marker width synchronously on pass 1 without `PreferenceKey`
/// or `@State` re-layout cycles, aligning markers and item text on `.firstTextBaseline`.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct NumberedListLayout: Layout {
  let minMarkerWidth: CGFloat
  let itemSpacing: CGFloat

  struct CacheEntry {
    let key: CacheKey
    let metrics: Metrics
  }

  struct Cache {
    var entries: [CacheEntry] = []

    func lookup(_ key: CacheKey) -> Metrics? {
      self.entries.first(where: { $0.key == key })?.metrics
    }

    mutating func insert(_ metrics: Metrics, for key: CacheKey) {
      if let existingIndex = self.entries.firstIndex(where: { $0.key == key }) {
        self.entries[existingIndex] = CacheEntry(key: key, metrics: metrics)
        return
      }
      if self.entries.count >= 6 {
        self.entries.removeFirst()
      }
      self.entries.append(CacheEntry(key: key, metrics: metrics))
    }
  }

  struct CacheKey: Equatable {
    let subviewCount: Int
    let availableWidth: CGFloat?
    let minMarkerWidth: CGFloat
    let itemSpacing: CGFloat
  }

  struct RowPlacement {
    let markerWidth: CGFloat
    let markerY: CGFloat
    let itemY: CGFloat
    let rowHeight: CGFloat
  }

  struct Metrics {
    let markerSlotWidth: CGFloat
    let markerToItemSpacing: CGFloat
    let itemProposalWidth: CGFloat?
    let rows: [RowPlacement]
    let size: CGSize
  }

  func makeCache(subviews: Subviews) -> Cache {
    Cache()
  }

  func updateCache(_ cache: inout Cache, subviews: Subviews) {
    cache.entries.removeAll(keepingCapacity: true)
  }

  func explicitAlignment(
    of guide: HorizontalAlignment,
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) -> CGFloat? {
    nil
  }

  func explicitAlignment(
    of guide: VerticalAlignment,
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) -> CGFloat? {
    nil
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
    self.resolveMetrics(proposalWidth: proposal.width, subviews: subviews, cache: &cache).size
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) {
    let metrics: Metrics
    if let matched = cache.entries.last(where: { entry in
      entry.key.subviewCount == subviews.count
        && abs(entry.metrics.size.width - bounds.width) < 0.01
        && abs(entry.metrics.size.height - bounds.height) < 0.01
    })?.metrics {
      metrics = matched
    } else {
      metrics = self.resolveMetrics(
        proposalWidth: proposal.width ?? bounds.width,
        subviews: subviews,
        cache: &cache
      )
    }

    let itemCount = subviews.count / 2
    guard itemCount > 0 else { return }

    let itemX = bounds.minX + metrics.markerSlotWidth + metrics.markerToItemSpacing
    let itemProposal = ProposedViewSize(width: metrics.itemProposalWidth, height: nil)

    var y = bounds.minY
    for index in 0..<itemCount {
      let row = metrics.rows[index]
      let markerX = bounds.minX + metrics.markerSlotWidth - row.markerWidth
      subviews[2 * index].place(
        at: CGPoint(x: markerX, y: y + row.markerY),
        anchor: .topLeading,
        proposal: .unspecified
      )
      subviews[2 * index + 1].place(
        at: CGPoint(x: itemX, y: y + row.itemY),
        anchor: .topLeading,
        proposal: itemProposal
      )
      y += row.rowHeight + self.itemSpacing
    }
  }

  private func resolveMetrics(
    proposalWidth: CGFloat?,
    subviews: Subviews,
    cache: inout Cache
  ) -> Metrics {
    let normalizedWidth: CGFloat? =
      if let w = proposalWidth, w.isFinite { w } else { nil }
    let key = CacheKey(
      subviewCount: subviews.count,
      availableWidth: normalizedWidth,
      minMarkerWidth: self.minMarkerWidth,
      itemSpacing: self.itemSpacing
    )
    if let cached = cache.lookup(key) {
      return cached
    }
    let computed = self.measure(availableWidth: normalizedWidth, subviews: subviews)
    cache.insert(computed, for: key)
    return computed
  }

  private func measure(
    availableWidth: CGFloat?,
    subviews: Subviews
  ) -> Metrics {
    let itemCount = subviews.count / 2
    guard itemCount > 0 else {
      return Metrics(
        markerSlotWidth: self.minMarkerWidth,
        markerToItemSpacing: 0,
        itemProposalWidth: availableWidth,
        rows: [],
        size: .zero
      )
    }

    var markerDims: [ViewDimensions] = []
    markerDims.reserveCapacity(itemCount)
    var maxMarkerWidth = self.minMarkerWidth
    for index in 0..<itemCount {
      let dim = subviews[2 * index].dimensions(in: .unspecified)
      markerDims.append(dim)
      maxMarkerWidth = max(maxMarkerWidth, dim.width)
    }

    let markerToItemSpacing = subviews[0].spacing.distance(
      to: subviews[1].spacing,
      along: .horizontal
    )

    let itemProposalWidth: CGFloat? = availableWidth.map {
      max(0, $0 - maxMarkerWidth - markerToItemSpacing)
    }
    let itemProposal = ProposedViewSize(width: itemProposalWidth, height: nil)

    var rows: [RowPlacement] = []
    rows.reserveCapacity(itemCount)
    var maxItemWidth: CGFloat = 0
    var totalHeight: CGFloat = 0

    for index in 0..<itemCount {
      let markerDim = markerDims[index]
      let itemDim = subviews[2 * index + 1].dimensions(in: itemProposal)
      let markerBaseline = markerDim[.firstTextBaseline]
      let itemBaseline = itemDim[.firstTextBaseline]
      let baseline = max(markerBaseline, itemBaseline)
      let markerY = baseline - markerBaseline
      let itemY = baseline - itemBaseline
      let rowHeight = max(markerY + markerDim.height, itemY + itemDim.height)
      rows.append(
        RowPlacement(
          markerWidth: markerDim.width,
          markerY: markerY,
          itemY: itemY,
          rowHeight: rowHeight
        )
      )
      maxItemWidth = max(maxItemWidth, itemDim.width)
      totalHeight += rowHeight
    }
    totalHeight += CGFloat(max(0, itemCount - 1)) * self.itemSpacing

    return Metrics(
      markerSlotWidth: maxMarkerWidth,
      markerToItemSpacing: markerToItemSpacing,
      itemProposalWidth: itemProposalWidth,
      rows: rows,
      size: CGSize(width: maxMarkerWidth + markerToItemSpacing + maxItemWidth, height: totalHeight)
    )
  }
}
