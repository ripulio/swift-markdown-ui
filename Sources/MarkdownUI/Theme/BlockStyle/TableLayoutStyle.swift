import SwiftUI

/// Controls how a table distributes space between its columns.
public enum TableLayoutStyle {
  /// Use SwiftUI's standard grid sizing.
  case automatic

  /// Fit columns to a scroll viewport when they remain readable.
  ///
  /// Short columns keep their natural width. Longer columns wrap, up to the
  /// maximum width (including cell padding). If the minimum readable widths
  /// cannot fit, `overflow` controls how much width horizontal scrolling exposes.
  /// Place the table in a horizontal ScrollView and pass its measured width.
  /// Scale the column limits with the text size for accessibility.
  case adaptive(
    availableWidth: CGFloat, minimumColumnWidth: CGFloat, maximumColumnWidth: CGFloat,
    overflow: Overflow = .natural
  )

  /// Column widths when the readable minimums exceed the available width.
  public enum Overflow {
    /// Retain natural widths, up to the configured maximum.
    case natural
    /// Wrap at the readable minimums, limiting the amount of horizontal scroll.
    case minimum
  }
}
