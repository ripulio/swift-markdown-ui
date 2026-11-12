import SwiftUI

/// Declarative styling parameters for Markdown table cells that avoid per-cell
/// `AnyView` type erasure in adaptive table layouts.
public struct MarkdownTableCellStyle: Equatable {
  public var headerFontWeight: Font.Weight?
  public var lineSpacing: RelativeSize?
  public var padding: EdgeInsets

  public init(
    headerFontWeight: Font.Weight? = .semibold,
    lineSpacing: RelativeSize? = nil,
    padding: EdgeInsets
  ) {
    self.headerFontWeight = headerFontWeight
    self.lineSpacing = lineSpacing
    self.padding = padding
  }
}

extension View {
  /// Sets column sizing for Markdown tables. The default uses a standard grid.
  public func markdownTableLayout(_ layout: TableLayoutStyle) -> some View {
    self.environment(\.tableLayoutStyle, layout)
  }

  /// Sets declarative cell styling for adaptive Markdown tables.
  public func markdownTableCellStyle(_ style: MarkdownTableCellStyle?) -> some View {
    self.environment(\.tableCellStyle, style)
  }

  /// Sets the table border style for the Markdown tables in a view hierarchy.
  ///
  /// Use this modifier to customize the table border style inside the body of
  /// the ``Theme/table`` block style.
  ///
  /// - Parameter tableBorderStyle: The border style to set.
  public func markdownTableBorderStyle(_ tableBorderStyle: TableBorderStyle) -> some View {
    self.environment(\.tableBorderStyle, tableBorderStyle)
  }

  /// Sets the table background style for the Markdown tables in a view hierarchy.
  ///
  /// Use this modifier to customize the table background style inside the body of
  /// the ``Theme/table`` block style.
  ///
  /// - Parameter tableBackgroundStyle: The background style to set.
  public func markdownTableBackgroundStyle(
    _ tableBackgroundStyle: TableBackgroundStyle
  ) -> some View {
    self.environment(\.tableBackgroundStyle, tableBackgroundStyle)
  }
}

extension EnvironmentValues {
  var tableLayoutStyle: TableLayoutStyle {
    get { self[TableLayoutStyleKey.self] }
    set { self[TableLayoutStyleKey.self] = newValue }
  }

  var tableBorderStyle: TableBorderStyle {
    get { self[TableBorderStyleKey.self] }
    set { self[TableBorderStyleKey.self] = newValue }
  }

  var tableBackgroundStyle: TableBackgroundStyle {
    get { self[TableBackgroundStyleKey.self] }
    set { self[TableBackgroundStyleKey.self] = newValue }
  }

  var tableCellStyle: MarkdownTableCellStyle? {
    get { self[TableCellStyleKey.self] }
    set { self[TableCellStyleKey.self] = newValue }
  }
}

private struct TableLayoutStyleKey: EnvironmentKey {
  static let defaultValue = TableLayoutStyle.automatic
}

private struct TableBorderStyleKey: EnvironmentKey {
  static let defaultValue = TableBorderStyle(color: .secondary)
}

private struct TableBackgroundStyleKey: EnvironmentKey {
  static let defaultValue = TableBackgroundStyle.clear
}

private struct TableCellStyleKey: EnvironmentKey {
  static let defaultValue: MarkdownTableCellStyle? = nil
}
