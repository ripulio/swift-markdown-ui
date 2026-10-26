import SwiftUI

extension EnvironmentValues {
  /// The position of a block within this document, including its container blocks.
  var markdownBlockPath: [Int] {
    get { self[MarkdownBlockPathKey.self] }
    set { self[MarkdownBlockPathKey.self] = newValue }
  }
}

private struct MarkdownBlockPathKey: EnvironmentKey {
  static let defaultValue: [Int] = []
}
