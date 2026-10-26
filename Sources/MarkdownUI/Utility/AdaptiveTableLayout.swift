import SwiftUI

/// Measures real styled cells, so links, code, padding and Dynamic Type all
/// participate in column sizing. Rows use their tallest wrapped cell.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct AdaptiveTableLayout: Layout {
  let columnCount: Int
  let spacing: CGFloat
  let availableWidth: CGFloat
  let minimumColumnWidth: CGFloat
  let maximumColumnWidth: CGFloat
  let overflow: TableLayoutStyle.Overflow

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
    self.measure(subviews).size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void
  ) {
    let measurement = self.measure(subviews)
    guard self.columnCount > 0 else { return }
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

  private func measure(_ subviews: Subviews) -> Measurement {
    guard self.columnCount > 0, !subviews.isEmpty else {
      return Measurement(widths: [], heights: [], size: .zero)
    }
    let maximum = max(1, self.maximumColumnWidth)
    var widths = Array(repeating: CGFloat(0), count: self.columnCount)
    for (index, subview) in subviews.enumerated() {
      let width = subview.sizeThatFits(.unspecified).width
      widths[index % self.columnCount] = max(widths[index % self.columnCount], min(maximum, width))
    }
    let minimums = widths.map { min($0, max(1, self.minimumColumnWidth)) }
    let gaps = CGFloat(self.columnCount - 1) * self.spacing
    let budget = max(0, self.availableWidth - gaps)
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
      let height = subview.sizeThatFits(.init(width: widths[index % self.columnCount], height: nil)).height
      heights[index / self.columnCount] = max(heights[index / self.columnCount], height)
    }
    return Measurement(
      widths: widths, heights: heights,
      size: CGSize(width: widths.reduce(0, +) + gaps,
                   height: heights.reduce(0, +) + CGFloat(max(0, heights.count - 1)) * self.spacing)
    )
  }

  private struct Measurement {
    let widths: [CGFloat]
    let heights: [CGFloat]
    let size: CGSize
  }
}
