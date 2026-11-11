import SwiftUI

extension View {
  /// Skips marker width preference measurement for bulleted lists and single-item
  /// numbered lists, and folds default bullet marker sizing into a single pass.
  ///
  /// The default is `false`, keeping the original preference-reading behaviour.
  public func markdownLightweightListMarkers(_ enabled: Bool = true) -> some View {
    self.environment(\.lightweightListMarkers, enabled)
  }
}

extension EnvironmentValues {
  var listLevel: Int {
    get { self[ListLevelKey.self] }
    set { self[ListLevelKey.self] = newValue }
  }

  var tightSpacingEnabled: Bool {
    get { self[TightSpacingEnabledKey.self] }
    set { self[TightSpacingEnabledKey.self] = newValue }
  }

  var lightweightListMarkers: Bool {
    get { self[LightweightListMarkersKey.self] }
    set { self[LightweightListMarkersKey.self] = newValue }
  }
}

private struct ListLevelKey: EnvironmentKey {
  static var defaultValue = 0
}

private struct TightSpacingEnabledKey: EnvironmentKey {
  static var defaultValue = false
}

private struct LightweightListMarkersKey: EnvironmentKey {
  static let defaultValue = false
}
