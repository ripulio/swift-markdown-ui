import SwiftUI

extension View {
  /// Supplies fixed point margins for each kind of Markdown block so
  /// `BlockSequence` spaces blocks on its first pass without reading
  /// `BlockMarginsPreference`. Pass `nil` (the default) to measure block
  /// margins dynamically from `.markdownMargin(...)` modifiers.
  public func markdownBlockMargins(_ margins: MarkdownBlockMargins?) -> some View {
    self.environment(\.markdownBlockMargins, margins)
  }
}

extension EnvironmentValues {
  var markdownBlockMargins: MarkdownBlockMargins? {
    get { self[MarkdownBlockMarginsKey.self] }
    set { self[MarkdownBlockMarginsKey.self] = newValue }
  }

  var usesDeclarativeBlockMargins: Bool {
    get { self[UsesDeclarativeBlockMarginsKey.self] }
    set { self[UsesDeclarativeBlockMarginsKey.self] = newValue }
  }

  var isInsideDynamicBlockSequence: Bool {
    get { self[IsInsideDynamicBlockSequenceKey.self] }
    set { self[IsInsideDynamicBlockSequenceKey.self] = newValue }
  }
}

private struct MarkdownBlockMarginsKey: EnvironmentKey {
  static let defaultValue: MarkdownBlockMargins? = nil
}

private struct UsesDeclarativeBlockMarginsKey: EnvironmentKey {
  static let defaultValue = false
}

private struct IsInsideDynamicBlockSequenceKey: EnvironmentKey {
  static let defaultValue = false
}
