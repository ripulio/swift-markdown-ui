import SwiftUI

/// Controls how a table distributes space between its columns.
public enum TableLayoutStyle {
  /// Use SwiftUI's standard grid sizing.
  case automatic

  /// Fit columns to a scroll viewport when they remain readable.
  ///
  /// Short columns keep their natural width. Longer columns wrap, up to the
  /// maximum width (including cell padding). If the minimum readable widths
  /// cannot fit, the table keeps its natural widths for horizontal scrolling.
  /// Place the table in a horizontal ScrollView and pass its measured width.
  /// Scale the column limits with the text size for accessibility.
  case adaptive(availableWidth: CGFloat, minimumColumnWidth: CGFloat, maximumColumnWidth: CGFloat)
}
