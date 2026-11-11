import SwiftUI

extension View {
  /// Enables lightweight view construction and layout paths for Markdown blocks and inlines
  /// while preserving rendered appearance and settled dimensions.
  ///
  /// The default is `false`, keeping the original view hierarchy untouched.
  public func markdownLightweightBlocks(_ enabled: Bool = true) -> some View {
    self.environment(\.lightweightBlocks, enabled)
  }
}

extension EnvironmentValues {
  var lightweightBlocks: Bool {
    get { self[LightweightBlocksKey.self] }
    set { self[LightweightBlocksKey.self] = newValue }
  }
}

private struct LightweightBlocksKey: EnvironmentKey {
  static let defaultValue = false
}
