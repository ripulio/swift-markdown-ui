import SwiftUI

/// A type that applies a custom background to tables in a Markdown view.
///
/// To customize the background of tables in a ``Markdown`` view, use the
/// `markdownTableBackgroundStyle(_:)` modifier inside the body of
/// the ``Theme/table`` block style.
///
/// The following example customizes the background of the odd rows in a table.
///
/// ```swift
/// Markdown {
///   """
///   | First Header  | Second Header |
///   | ------------- | ------------- |
///   | Content Cell  | Content Cell  |
///   | Content Cell  | Content Cell  |
///   | Content Cell  | Content Cell  |
///   """
/// }
/// .markdownBlockStyle(\.table) { configuration in
///   configuration.label
///     .markdownTableBackgroundStyle(
///       .alternatingRows(Color.teal.opacity(0.5), .clear, header: .clear)
///     )
/// }
/// ```
///
/// ![](CustomTableBackground)
public struct TableBackgroundStyle {
  enum FastBatching {
    case clear
    case alternatingRows(
      odd: AnyShapeStyle,
      oddIsClear: Bool,
      even: AnyShapeStyle,
      evenIsClear: Bool,
      header: AnyShapeStyle,
      headerIsClear: Bool
    )
  }

  let background: (_ row: Int, _ column: Int) -> AnyShapeStyle
  let fastBatching: FastBatching?

  /// Creates a table background style that customizes table backgrounds by applying a given closure
  /// to the background of each cell.
  /// - Parameter background: A closure that returns a shape style for a given table cell location.
  public init<S: ShapeStyle>(background: @escaping (_ row: Int, _ column: Int) -> S) {
    self.background = { row, column in
      AnyShapeStyle(background(row, column))
    }
    self.fastBatching = nil
  }

  private init(
    fastBatching: FastBatching,
    background: @escaping (_ row: Int, _ column: Int) -> AnyShapeStyle
  ) {
    self.fastBatching = fastBatching
    self.background = background
  }
}

extension TableBackgroundStyle {
  /// A clear color table background style.
  public static var clear: Self {
    TableBackgroundStyle(fastBatching: .clear) { _, _ in
      AnyShapeStyle(Color.clear)
    }
  }

  /// A table background style that alternates row background shape styles.
  /// - Parameters:
  ///   - odd: The shape style for odd rows.
  ///   - even: The shape style for even rows.
  ///   - header: The shape style for the header row. If `nil`, the odd row shape style is used.
  public static func alternatingRows<S: ShapeStyle>(_ odd: S, _ even: S, header: S? = nil) -> Self {
    let resolvedHeader = header ?? odd
    let oddAny = AnyShapeStyle(odd)
    let evenAny = AnyShapeStyle(even)
    let headerAny = AnyShapeStyle(resolvedHeader)
    return TableBackgroundStyle(
      fastBatching: .alternatingRows(
        odd: oddAny,
        oddIsClear: (odd as? Color) == Color.clear,
        even: evenAny,
        evenIsClear: (even as? Color) == Color.clear,
        header: headerAny,
        headerIsClear: (resolvedHeader as? Color) == Color.clear
      )
    ) { row, _ in
      guard row > 0 else {
        return headerAny
      }

      return row.isMultiple(of: 2) ? evenAny : oddAny
    }
  }
}
