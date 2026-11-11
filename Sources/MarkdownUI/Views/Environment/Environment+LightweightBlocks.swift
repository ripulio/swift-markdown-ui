import SwiftUI

extension View {
  /// Enables lightweight view construction and layout paths for Markdown blocks and inlines
  /// while preserving rendered appearance and settled dimensions.
  ///
  /// The default is `false`, keeping the original view hierarchy untouched.
  public func markdownLightweightBlocks(_ enabled: Bool = true) -> some View {
    self.environment(\.lightweightBlocks, enabled)
  }

  /// Enables compact single-layout rendering for lists, adaptive table cells, and
  /// top-level paragraphs when ``View/markdownLightweightBlocks(_:)`` is active.
  ///
  /// The default is `false`, keeping Pass 4's hierarchy untouched until switched on.
  public func markdownCompactLayout(_ enabled: Bool = true) -> some View {
    self.environment(\.compactLayout, enabled)
  }

  /// Enables Pass 7 direct block sequences, coalesced prose runs (headings and paragraphs),
  /// shared inline-attribute caching, and static tuple view batching when
  /// ``View/markdownCompactLayout(_:)`` is active.
  ///
  /// The default is `false`, keeping Pass 6's hierarchy untouched until switched on.
  public func markdownDirectBlocks(_ enabled: Bool = true) -> some View {
    self.environment(\.directBlocks, enabled)
  }
}

extension EnvironmentValues {
  var lightweightBlocks: Bool {
    get { self[LightweightBlocksKey.self] }
    set { self[LightweightBlocksKey.self] = newValue }
  }

  var compactLayout: Bool {
    get { self[CompactLayoutKey.self] }
    set { self[CompactLayoutKey.self] = newValue }
  }

  var directBlocks: Bool {
    get { self[DirectBlocksKey.self] }
    set { self[DirectBlocksKey.self] = newValue }
  }
}

private struct LightweightBlocksKey: EnvironmentKey {
  static let defaultValue = false
}

private struct CompactLayoutKey: EnvironmentKey {
  static let defaultValue = false
}

private struct DirectBlocksKey: EnvironmentKey {
  static let defaultValue = false
}
