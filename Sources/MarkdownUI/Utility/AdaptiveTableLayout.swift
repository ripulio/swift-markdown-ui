import SwiftUI

/// Measures real styled cells, so links, code, padding and Dynamic Type all
/// participate in column sizing. Rows use their tallest wrapped cell.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct AdaptiveTableLayout: Layout {
  let columnCount: Int
  let spacing: CGFloat
  let resolveAvailableWidth: () -> CGFloat
  let minimumColumnWidth: CGFloat
  let maximumColumnWidth: CGFloat
  let overflow: TableLayoutStyle.Overflow
  let onMeasureWidth: ((CGFloat) -> Void)?
  let onResolveBounds: (([CGFloat], [CGFloat]) -> Void)?
  let cachesMeasurements: Bool
  let canReuseUnwrappedCellHeights: Bool
  let cellPadding: EdgeInsets?
  let columnAlignments: [TextAlignment]

  init(
    columnCount: Int,
    spacing: CGFloat,
    availableWidth: CGFloat,
    minimumColumnWidth: CGFloat,
    maximumColumnWidth: CGFloat,
    overflow: TableLayoutStyle.Overflow,
    onResolveBounds: (([CGFloat], [CGFloat]) -> Void)? = nil,
    cellPadding: EdgeInsets? = nil,
    columnAlignments: [TextAlignment] = []
  ) {
    self.columnCount = columnCount
    self.spacing = spacing
    self.resolveAvailableWidth = { availableWidth }
    self.minimumColumnWidth = minimumColumnWidth
    self.maximumColumnWidth = maximumColumnWidth
    self.overflow = overflow
    self.onMeasureWidth = nil
    self.onResolveBounds = onResolveBounds
    self.cachesMeasurements = false
    self.canReuseUnwrappedCellHeights = false
    self.cellPadding = cellPadding
    self.columnAlignments = columnAlignments
  }

  init(
    columnCount: Int,
    spacing: CGFloat,
    resolveAvailableWidth: @escaping () -> CGFloat,
    minimumColumnWidth: CGFloat,
    maximumColumnWidth: CGFloat,
    overflow: TableLayoutStyle.Overflow,
    onMeasureWidth: ((CGFloat) -> Void)?,
    onResolveBounds: (([CGFloat], [CGFloat]) -> Void)? = nil,
    cachesMeasurements: Bool,
    canReuseUnwrappedCellHeights: Bool,
    cellPadding: EdgeInsets? = nil,
    columnAlignments: [TextAlignment] = []
  ) {
    self.columnCount = columnCount
    self.spacing = spacing
    self.resolveAvailableWidth = resolveAvailableWidth
    self.minimumColumnWidth = minimumColumnWidth
    self.maximumColumnWidth = maximumColumnWidth
    self.overflow = overflow
    self.onMeasureWidth = onMeasureWidth
    self.onResolveBounds = onResolveBounds
    self.cachesMeasurements = cachesMeasurements
    self.canReuseUnwrappedCellHeights = canReuseUnwrappedCellHeights
    self.cellPadding = cellPadding
    self.columnAlignments = columnAlignments
  }

  struct Cache {
    var key: CacheKey?
    var measurement: Measurement?
  }

  struct CacheKey: Equatable {
    let columnCount: Int
    let subviewCount: Int
    let spacing: CGFloat
    let availableWidth: CGFloat
    let minimumColumnWidth: CGFloat
    let maximumColumnWidth: CGFloat
    let overflow: TableLayoutStyle.Overflow
    let cellPadding: EdgeInsets?
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
    let measurement = self.resolvedMeasurement(subviews, cache: &cache)
    self.onMeasureWidth?(measurement.size.width)
    self.onResolveBounds?(measurement.widths, measurement.heights)
    return measurement.size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache
  ) {
    let measurement = self.resolvedMeasurement(subviews, cache: &cache)
    self.onMeasureWidth?(measurement.size.width)
    self.onResolveBounds?(measurement.widths, measurement.heights)
    guard self.columnCount > 0 else { return }

    if let pad = self.cellPadding {
      let horizontalPadding = pad.leading + pad.trailing
      var y = bounds.minY
      for row in measurement.heights.indices {
        var x = bounds.minX
        for column in measurement.widths.indices {
          let index = row * self.columnCount + column
          guard index < subviews.count else { continue }
          let width = measurement.widths[column]
          let innerWidth = max(0, width - horizontalPadding)
          let itemProposal = ProposedViewSize(width: innerWidth, height: nil)
          let alignment =
            column < self.columnAlignments.count ? self.columnAlignments[column] : .leading
          switch alignment {
          case .leading:
            subviews[index].place(
              at: CGPoint(x: x + pad.leading, y: y + pad.top),
              anchor: .topLeading,
              proposal: itemProposal
            )
          case .center:
            subviews[index].place(
              at: CGPoint(x: x + pad.leading + innerWidth * 0.5, y: y + pad.top),
              anchor: .top,
              proposal: itemProposal
            )
          case .trailing:
            subviews[index].place(
              at: CGPoint(x: x + width - pad.trailing, y: y + pad.top),
              anchor: .topTrailing,
              proposal: itemProposal
            )
          }
          x += width + self.spacing
        }
        y += measurement.heights[row] + self.spacing
      }
    } else {
      var y = bounds.minY
      for row in measurement.heights.indices {
        var x = bounds.minX
        for column in measurement.widths.indices {
          let index = row * self.columnCount + column
          guard index < subviews.count else { continue }
          let width = measurement.widths[column]
          // SwiftUI mirrors layout placement for right-to-left environments.
          subviews[index].place(
            at: CGPoint(x: x, y: y), anchor: .topLeading,
            proposal: .init(width: width, height: measurement.heights[row])
          )
          x += width + self.spacing
        }
        y += measurement.heights[row] + self.spacing
      }
    }
  }

  private func resolvedMeasurement(_ subviews: Subviews, cache: inout Cache) -> Measurement {
    let availableWidth = self.resolveAvailableWidth()
    guard self.cachesMeasurements else {
      return self.measure(subviews, availableWidth: availableWidth)
    }
    let key = CacheKey(
      columnCount: self.columnCount,
      subviewCount: subviews.count,
      spacing: self.spacing,
      availableWidth: availableWidth,
      minimumColumnWidth: self.minimumColumnWidth,
      maximumColumnWidth: self.maximumColumnWidth,
      overflow: self.overflow,
      cellPadding: self.cellPadding
    )
    if cache.key == key, let hit = cache.measurement {
      return hit
    }
    let measured = self.measure(subviews, availableWidth: availableWidth)
    cache.key = key
    cache.measurement = measured
    return measured
  }

  private func measure(_ subviews: Subviews, availableWidth: CGFloat) -> Measurement {
    guard self.columnCount > 0, !subviews.isEmpty else {
      return Measurement(widths: [], heights: [], size: .zero)
    }
    let horizontalPadding = self.cellPadding.map { $0.leading + $0.trailing } ?? 0
    let verticalPadding = self.cellPadding.map { $0.top + $0.bottom } ?? 0
    let maximum = max(1, self.maximumColumnWidth)
    var widths = Array(repeating: CGFloat(0), count: self.columnCount)
    var naturalSizes: [CGSize] = []
    if self.canReuseUnwrappedCellHeights {
      naturalSizes.reserveCapacity(subviews.count)
    }
    for (index, subview) in subviews.enumerated() {
      let raw = subview.sizeThatFits(.unspecified)
      let natural = CGSize(
        width: raw.width + horizontalPadding,
        height: raw.height + verticalPadding
      )
      if self.canReuseUnwrappedCellHeights {
        naturalSizes.append(natural)
      }
      widths[index % self.columnCount] = max(widths[index % self.columnCount], min(maximum, natural.width))
    }
    let minimums = widths.map { min($0, max(1, self.minimumColumnWidth)) }
    let gaps = CGFloat(self.columnCount - 1) * self.spacing
    let budget = max(0, availableWidth - gaps)
    let idealTotal = widths.reduce(0, +)
    let minimumTotal = minimums.reduce(0, +)
    if budget >= minimumTotal, budget < idealTotal, idealTotal > minimumTotal {
      let fraction = (budget - minimumTotal) / (idealTotal - minimumTotal)
      widths = zip(widths, minimums).map { ideal, minimum in
        minimum + (ideal - minimum) * fraction
      }
    } else if budget < minimumTotal, self.overflow == .minimum {
      widths = minimums
    }
    // Overflow never compresses below the chosen readable minimum. Consumers
    // can choose minimum widths to combine wrapping with a shorter scroll span.
    var heights = Array(repeating: CGFloat(0), count: (subviews.count + self.columnCount - 1) / self.columnCount)
    for (index, subview) in subviews.enumerated() {
      let colWidth = widths[index % self.columnCount]
      let height: CGFloat
      if self.canReuseUnwrappedCellHeights, colWidth >= naturalSizes[index].width - 0.001 {
        height = naturalSizes[index].height
      } else {
        let proposalWidth = self.cellPadding == nil ? colWidth : max(0, colWidth - horizontalPadding)
        height = subview.sizeThatFits(.init(width: proposalWidth, height: nil)).height + verticalPadding
      }
      heights[index / self.columnCount] = max(heights[index / self.columnCount], height)
    }
    return Measurement(
      widths: widths, heights: heights,
      size: CGSize(width: widths.reduce(0, +) + gaps,
                   height: heights.reduce(0, +) + CGFloat(max(0, heights.count - 1)) * self.spacing)
    )
  }

  struct Measurement {
    let widths: [CGFloat]
    let heights: [CGFloat]
    let size: CGSize
  }
}
