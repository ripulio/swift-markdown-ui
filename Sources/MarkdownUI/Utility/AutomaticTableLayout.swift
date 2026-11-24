import SwiftUI

/// Single-pass table layout for built-in `.automatic` themes (`Theme.basic`, `Theme.gitHub`,
/// `Theme.docC`), replacing SwiftUI `Grid` + per-cell `GeometryReader` / `TableCellBoundsPreference`
/// anchor tracking with layout-resolved bounds and shape-batched backgrounds/borders.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct AutomaticTableLayout: Layout {
  let columnCount: Int
  let spacing: CGFloat
  let cellPadding: EdgeInsets
  let columnAlignments: [TextAlignment]
  let onResolveBounds: (([CGFloat], [CGFloat]) -> Void)?

  struct CacheEntry {
    let key: CacheKey
    let measurement: Measurement
  }

  struct Cache {
    var entries: [CacheEntry] = []

    func lookup(_ key: CacheKey) -> Measurement? {
      self.entries.first(where: { $0.key == key })?.measurement
    }

    mutating func insert(_ measurement: Measurement, for key: CacheKey) {
      if let idx = self.entries.firstIndex(where: { $0.key == key }) {
        self.entries[idx] = CacheEntry(key: key, measurement: measurement)
        return
      }
      if self.entries.count >= 4 {
        self.entries.removeFirst()
      }
      self.entries.append(CacheEntry(key: key, measurement: measurement))
    }
  }

  struct CacheKey: Equatable {
    let columnCount: Int
    let subviewCount: Int
    let spacing: CGFloat
    let availableWidth: CGFloat?
    let cellPadding: EdgeInsets
  }

  struct Measurement {
    let widths: [CGFloat]
    let heights: [CGFloat]
    let cellHeights: [CGFloat]
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
    let measurement = self.resolvedMeasurement(proposalWidth: proposal.width, subviews: subviews, cache: &cache)
    self.onResolveBounds?(measurement.widths, measurement.heights)
    return measurement.size
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) {
    let measurement = self.resolvedMeasurement(
      proposalWidth: proposal.width ?? bounds.width,
      subviews: subviews,
      cache: &cache
    )
    self.onResolveBounds?(measurement.widths, measurement.heights)
    guard self.columnCount > 0 else { return }

    let pad = self.cellPadding
    let horizontalPadding = pad.leading + pad.trailing
    var y = bounds.minY
    for row in measurement.heights.indices {
      let rowHeight = measurement.heights[row]
      var x = bounds.minX
      for column in measurement.widths.indices {
        let index = row * self.columnCount + column
        guard index < subviews.count else { continue }
        let width = measurement.widths[column]
        let innerWidth = max(0, width - horizontalPadding)
        let cellHeight = measurement.cellHeights[index]
        let cellTop = y + pad.top + max(0, (rowHeight - pad.top - pad.bottom - cellHeight) * 0.5)
        let itemProposal = ProposedViewSize(width: innerWidth, height: nil)
        let alignment =
          column < self.columnAlignments.count ? self.columnAlignments[column] : .leading
        switch alignment {
        case .leading:
          subviews[index].place(
            at: CGPoint(x: x + pad.leading, y: cellTop),
            anchor: .topLeading,
            proposal: itemProposal
          )
        case .center:
          subviews[index].place(
            at: CGPoint(x: x + pad.leading + innerWidth * 0.5, y: cellTop),
            anchor: .top,
            proposal: itemProposal
          )
        case .trailing:
          subviews[index].place(
            at: CGPoint(x: x + width - pad.trailing, y: cellTop),
            anchor: .topTrailing,
            proposal: itemProposal
          )
        }
        x += width + self.spacing
      }
      y += rowHeight + self.spacing
    }
  }

  private func resolvedMeasurement(
    proposalWidth: CGFloat?,
    subviews: Subviews,
    cache: inout Cache
  ) -> Measurement {
    let normalizedWidth: CGFloat? =
      if let w = proposalWidth, w.isFinite { w } else { nil }
    let key = CacheKey(
      columnCount: self.columnCount,
      subviewCount: subviews.count,
      spacing: self.spacing,
      availableWidth: normalizedWidth,
      cellPadding: self.cellPadding
    )
    if let hit = cache.lookup(key) {
      return hit
    }
    let measured = self.measure(availableWidth: normalizedWidth, subviews: subviews)
    cache.insert(measured, for: key)
    return measured
  }

  private func measure(availableWidth: CGFloat?, subviews: Subviews) -> Measurement {
    guard self.columnCount > 0, !subviews.isEmpty else {
      return Measurement(widths: [], heights: [], cellHeights: [], size: .zero)
    }

    let horizontalPadding = self.cellPadding.leading + self.cellPadding.trailing
    let verticalPadding = self.cellPadding.top + self.cellPadding.bottom

    var idealColWidths = Array(repeating: CGFloat(0), count: self.columnCount)
    var naturalSizes: [CGSize] = []
    naturalSizes.reserveCapacity(subviews.count)

    for (index, subview) in subviews.enumerated() {
      let raw = subview.sizeThatFits(.unspecified)
      naturalSizes.append(raw)
      let col = index % self.columnCount
      idealColWidths[col] = max(idealColWidths[col], raw.width + horizontalPadding)
    }

    let gaps = CGFloat(max(0, self.columnCount - 1)) * self.spacing
    let totalIdeal = idealColWidths.reduce(0, +)
    var widths = idealColWidths

    let rowCount = (subviews.count + self.columnCount - 1) / self.columnCount
    var heights = Array(repeating: CGFloat(0), count: rowCount)
    var cellHeights = Array(repeating: CGFloat(0), count: subviews.count)
    var measuredWrappedColumn = Array(repeating: false, count: self.columnCount)

    if let availableWidth, availableWidth > 0 {
      let budget = max(0, availableWidth - gaps)
      if totalIdeal > budget {
        // Mirror SwiftUI Grid's exact column allocation: compute each column's minimum
        // width, sort by ascending flexibility (ideal - min), offer equalShare, and
        // adopt each column's actual wrapped width so leftover space flows to remaining
        // columns and borders hug actual text bounds identically to Grid.
        var minColWidths = Array(repeating: CGFloat(0), count: self.columnCount)
        for (index, subview) in subviews.enumerated() {
          let col = index % self.columnCount
          let minW =
            subview.sizeThatFits(ProposedViewSize(width: 0, height: nil)).width + horizontalPadding
          minColWidths[col] = max(minColWidths[col], min(idealColWidths[col], minW))
        }

        var remainingBudget = budget
        var remainingCols = Array(0..<self.columnCount)
        remainingCols.sort { a, b in
          let flexA = idealColWidths[a] - minColWidths[a]
          let flexB = idealColWidths[b] - minColWidths[b]
          if abs(flexA - flexB) > 0.001 {
            return flexA < flexB
          }
          return a < b
        }

        var resolved = Array(repeating: CGFloat(0), count: self.columnCount)
        for (offset, col) in remainingCols.enumerated() {
          let countLeft = remainingCols.count - offset
          let equalShare = max(0, remainingBudget / CGFloat(countLeft))
          if equalShare >= idealColWidths[col] - 0.001 {
            resolved[col] = idealColWidths[col]
            remainingBudget = max(0, remainingBudget - idealColWidths[col])
          } else {
            let offeredInner = max(0, equalShare - horizontalPadding)
            var actualColWidth: CGFloat = 0
            for row in 0..<rowCount {
              let index = row * self.columnCount + col
              guard index < subviews.count else { continue }
              let measured: CGSize
              if offeredInner >= naturalSizes[index].width - 0.001 {
                measured = naturalSizes[index]
              } else {
                measured = subviews[index].sizeThatFits(
                  ProposedViewSize(width: offeredInner, height: nil)
                )
              }
              actualColWidth = max(actualColWidth, measured.width + horizontalPadding)
              cellHeights[index] = measured.height
              heights[row] = max(heights[row], measured.height + verticalPadding)
            }
            measuredWrappedColumn[col] = true
            resolved[col] = actualColWidth
            remainingBudget = max(0, remainingBudget - actualColWidth)
          }
        }
        widths = resolved
      }
    }

    for (index, subview) in subviews.enumerated() {
      let col = index % self.columnCount
      if measuredWrappedColumn[col] {
        continue
      }
      let innerWidth = max(0, widths[col] - horizontalPadding)
      let cellHeight: CGFloat
      if innerWidth >= naturalSizes[index].width - 0.001 {
        cellHeight = naturalSizes[index].height
      } else {
        cellHeight = subview.sizeThatFits(ProposedViewSize(width: innerWidth, height: nil)).height
      }
      cellHeights[index] = cellHeight
      let row = index / self.columnCount
      heights[row] = max(heights[row], cellHeight + verticalPadding)
    }

    let totalWidth = widths.reduce(0, +) + gaps
    let totalHeight = heights.reduce(0, +) + CGFloat(max(0, heights.count - 1)) * self.spacing
    return Measurement(
      widths: widths,
      heights: heights,
      cellHeights: cellHeights,
      size: CGSize(width: totalWidth, height: totalHeight)
    )
  }
}
