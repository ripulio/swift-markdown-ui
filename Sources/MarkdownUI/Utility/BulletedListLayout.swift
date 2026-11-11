import Foundation
import SwiftUI

struct BulletProbeKey: Hashable {
  let symbolVariant: Int
  let fontSize: CGFloat
  let minBulletWidth: CGFloat
  let fontProperties: FontProperties?
  let baselineOffset: CGFloat?
  let displayScale: CGFloat
}

struct BulletProbeMetrics {
  let iconSize: CGSize
  let fixedBulletY: CGFloat
  let fixedItemY: CGFloat
  let bulletSlotWidth: CGFloat
  let iconToItemSpacing: CGFloat
}

enum BulletProbeMetricsCache {
  private static let lock = NSLock()
  private static var storage: [BulletProbeKey: BulletProbeMetrics] = [:]

  static func lookup(_ key: BulletProbeKey) -> BulletProbeMetrics? {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.storage[key]
  }

  static func store(_ metrics: BulletProbeMetrics, for key: BulletProbeKey) {
    self.lock.lock()
    if self.storage.count >= 64 {
      self.storage.removeAll(keepingCapacity: true)
    }
    self.storage[key] = metrics
    self.lock.unlock()
  }
}

/// Places `[bullet_0, item_0, bullet_1, item_1, ...]` pairs directly in a single pass,
/// avoiding per-item `Label`, `HStack`, `VStack`, `_FlexFrameLayout`, `_FixedSizeLayout`,
/// and `_PaddingLayout` containers, and skipping the hidden `Label` metric probe once cached.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct BulletedListLayout: Layout {
  let minBulletWidth: CGFloat
  let itemSpacing: CGFloat
  var probeKey: BulletProbeKey? = nil
  var cachedProbe: BulletProbeMetrics? = nil
  var hasLeadingProbeSubview: Bool = true

  struct Cache {
    var key: CacheKey?
    var metrics: Metrics?
  }

  struct CacheKey: Equatable {
    let subviewCount: Int
    let availableWidth: CGFloat?
    let minBulletWidth: CGFloat
    let itemSpacing: CGFloat
    let hasLeadingProbeSubview: Bool
  }

  struct RowPlacement {
    let bulletY: CGFloat
    let itemY: CGFloat
    let rowHeight: CGFloat
  }

  struct Metrics {
    let iconSize: CGSize
    let bulletSlotWidth: CGFloat
    let iconToItemSpacing: CGFloat
    let itemProposalWidth: CGFloat?
    let rows: [RowPlacement]
    let size: CGSize
  }

  func makeCache(subviews: Subviews) -> Cache {
    Cache()
  }

  func updateCache(_ cache: inout Cache, subviews: Subviews) {
    cache = Cache()
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
    if let cached = cache.metrics,
      cache.key?.subviewCount == subviews.count,
      cache.key?.hasLeadingProbeSubview == self.hasLeadingProbeSubview,
      abs(cached.size.width - bounds.width) < 0.01,
      abs(cached.size.height - bounds.height) < 0.01
    {
      metrics = cached
    } else {
      metrics = self.resolveMetrics(
        proposalWidth: proposal.width ?? bounds.width,
        subviews: subviews,
        cache: &cache
      )
    }
    let baseOffset = self.hasLeadingProbeSubview ? 1 : 0
    let itemCount = (subviews.count - baseOffset) / 2
    guard itemCount > 0 else { return }

    if self.hasLeadingProbeSubview {
      subviews[0].place(
        at: bounds.origin,
        anchor: .topLeading,
        proposal: ProposedViewSize(width: 0, height: 0)
      )
    }

    let bulletX = bounds.minX + metrics.bulletSlotWidth - metrics.iconSize.width
    let itemX = bounds.minX + metrics.bulletSlotWidth + metrics.iconToItemSpacing
    let itemProposal = ProposedViewSize(width: metrics.itemProposalWidth, height: nil)

    var y = bounds.minY
    for index in 0..<itemCount {
      let row = metrics.rows[index]
      subviews[baseOffset + 2 * index].place(
        at: CGPoint(x: bulletX, y: y + row.bulletY),
        anchor: .topLeading,
        proposal: .unspecified
      )
      subviews[baseOffset + 1 + 2 * index].place(
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
      minBulletWidth: self.minBulletWidth,
      itemSpacing: self.itemSpacing,
      hasLeadingProbeSubview: self.hasLeadingProbeSubview
    )
    if cache.key == key, let cached = cache.metrics {
      return cached
    }
    let computed = self.measure(availableWidth: normalizedWidth, subviews: subviews)
    cache.key = key
    cache.metrics = computed
    return computed
  }

  private func measure(availableWidth: CGFloat?, subviews: Subviews) -> Metrics {
    let baseOffset = self.hasLeadingProbeSubview ? 1 : 0
    let itemCount = (subviews.count - baseOffset) / 2
    guard itemCount > 0 else {
      return Metrics(
        iconSize: .zero,
        bulletSlotWidth: self.minBulletWidth,
        iconToItemSpacing: 0,
        itemProposalWidth: availableWidth,
        rows: [],
        size: .zero
      )
    }

    let probe: BulletProbeMetrics
    if let cachedProbe = self.cachedProbe, !self.hasLeadingProbeSubview {
      probe = cachedProbe
    } else {
      let prototypeHeight: CGFloat = 100
      let prototypeDimensions = subviews[0].dimensions(in: .unspecified)
      let iconDimensions = subviews[1].dimensions(in: .unspecified)
      let iconSize = CGSize(width: iconDimensions.width, height: iconDimensions.height)
      let rawBulletY = prototypeDimensions.height - prototypeHeight
      let fixedBulletY = max(0, rawBulletY)
      let fixedItemY = max(0, -rawBulletY)
      let bulletSlotWidth = max(self.minBulletWidth, iconSize.width)
      let iconToItemSpacing = subviews[1].spacing.distance(
        to: subviews[2].spacing,
        along: .horizontal
      )
      let measured = BulletProbeMetrics(
        iconSize: iconSize,
        fixedBulletY: fixedBulletY,
        fixedItemY: fixedItemY,
        bulletSlotWidth: bulletSlotWidth,
        iconToItemSpacing: iconToItemSpacing
      )
      if let probeKey = self.probeKey {
        BulletProbeMetricsCache.store(measured, for: probeKey)
      }
      probe = measured
    }

    let itemProposalWidth: CGFloat? = availableWidth.map {
      max(0, $0 - probe.bulletSlotWidth - probe.iconToItemSpacing)
    }
    let itemProposal = ProposedViewSize(width: itemProposalWidth, height: nil)

    var rows: [RowPlacement] = []
    rows.reserveCapacity(itemCount)
    var maxItemWidth: CGFloat = 0
    var totalHeight: CGFloat = 0

    for index in 0..<itemCount {
      let itemDimensions = subviews[baseOffset + 1 + 2 * index].dimensions(in: itemProposal)
      let rowHeight = max(
        probe.fixedBulletY + probe.iconSize.height,
        probe.fixedItemY + itemDimensions.height
      )
      rows.append(
        RowPlacement(
          bulletY: probe.fixedBulletY,
          itemY: probe.fixedItemY,
          rowHeight: rowHeight
        )
      )
      maxItemWidth = max(maxItemWidth, itemDimensions.width)
      totalHeight += rowHeight
    }
    totalHeight += CGFloat(max(0, itemCount - 1)) * self.itemSpacing

    let resolvedWidth = probe.bulletSlotWidth + probe.iconToItemSpacing + maxItemWidth
    return Metrics(
      iconSize: probe.iconSize,
      bulletSlotWidth: probe.bulletSlotWidth,
      iconToItemSpacing: probe.iconToItemSpacing,
      itemProposalWidth: itemProposalWidth,
      rows: rows,
      size: CGSize(width: resolvedWidth, height: totalHeight)
    )
  }
}
