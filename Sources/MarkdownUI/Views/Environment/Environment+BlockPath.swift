import SwiftUI

extension EnvironmentValues {
  /// The position of the current block within its document, including containers.
  /// Read this from a view in a custom block style to key per-block controls.
  /// Paths are positional, stable during streaming, and local to one document.
  public internal(set) var markdownBlockPath: [Int] {
    get { self[MarkdownBlockPathKey.self] }
    set { self[MarkdownBlockPathKey.self] = newValue }
  }
}

private struct MarkdownBlockPathKey: EnvironmentKey {
  static let defaultValue: [Int] = []
}
