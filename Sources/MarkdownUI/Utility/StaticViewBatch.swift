import SwiftUI

/// Emits `0..<count` homogeneous views into a `Layout` container without `ForEach` /
/// `DynamicViewList` overhead for the first 32 items while keeping every item's
/// structural SwiftUI identity completely stable as `count` grows (e.g. during
/// live token streaming when new blocks or list rows append at the tail).
struct StaticViewBatch<ItemView: View>: View {
  let count: Int
  let makeItem: (Int) -> ItemView

  init(count: Int, @ViewBuilder makeItem: @escaping (Int) -> ItemView) {
    self.count = count
    self.makeItem = makeItem
  }

  var body: some View {
    if self.count > 0 {
      self.prefix8(base: 0, count: self.count)
    }
    if self.count > 8 {
      self.prefix8(base: 8, count: self.count)
    }
    if self.count > 16 {
      self.prefix8(base: 16, count: self.count)
    }
    if self.count > 24 {
      self.prefix8(base: 24, count: self.count)
    }
    if self.count > 32 {
      let endGroup = (self.count + 7) >> 3
      ForEach(4..<endGroup, id: \.self) { group in
        self.prefix8(base: group << 3, count: self.count)
      }
    }
  }

  @ViewBuilder private func prefix8(base: Int, count: Int) -> some View {
    if count > base { self.makeItem(base) }
    if count > base + 1 { self.makeItem(base + 1) }
    if count > base + 2 { self.makeItem(base + 2) }
    if count > base + 3 { self.makeItem(base + 3) }
    if count > base + 4 { self.makeItem(base + 4) }
    if count > base + 5 { self.makeItem(base + 5) }
    if count > base + 6 { self.makeItem(base + 6) }
    if count > base + 7 { self.makeItem(base + 7) }
  }
}
