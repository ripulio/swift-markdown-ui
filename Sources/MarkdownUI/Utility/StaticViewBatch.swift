import SwiftUI

/// Emits `0..<count` homogeneous views into a `Layout` container without `ForEach` /
/// `DynamicViewList` overhead when `count < 32` (using a 5-bit binary tuple decomposition),
/// and in 16-item chunks when `count >= 32`.
struct StaticViewBatch<ItemView: View>: View {
  let count: Int
  let makeItem: (Int) -> ItemView

  init(count: Int, @ViewBuilder makeItem: @escaping (Int) -> ItemView) {
    self.count = count
    self.makeItem = makeItem
  }

  var body: some View {
    if self.count < 32 {
      self.emitUpTo31(base: 0, count: Swift.max(0, self.count))
    } else {
      let fullGroups = self.count >> 4
      let rem = self.count & 15
      ForEach(0..<fullGroups, id: \.self) { group in
        self.group16(base: group << 4)
      }
      self.emitUpTo15(base: fullGroups << 4, count: rem)
    }
  }

  @ViewBuilder private func emitUpTo31(base: Int, count: Int) -> some View {
    let b8 = base + (count & 16)
    if (count & 16) != 0 {
      self.group16(base: base)
    }
    self.emitUpTo15(base: b8, count: count & 15)
  }

  @ViewBuilder private func emitUpTo15(base: Int, count: Int) -> some View {
    let b4 = base + (count & 8)
    let b2 = b4 + (count & 4)
    let b1 = b2 + (count & 2)
    if (count & 8) != 0 {
      self.group8(base: base)
    }
    if (count & 4) != 0 {
      self.group4(base: b4)
    }
    if (count & 2) != 0 {
      self.group2(base: b2)
    }
    if (count & 1) != 0 {
      self.makeItem(b1)
    }
  }

  @ViewBuilder private func group16(base: Int) -> some View {
    self.group8(base: base)
    self.group8(base: base + 8)
  }

  @ViewBuilder private func group8(base: Int) -> some View {
    self.makeItem(base)
    self.makeItem(base + 1)
    self.makeItem(base + 2)
    self.makeItem(base + 3)
    self.makeItem(base + 4)
    self.makeItem(base + 5)
    self.makeItem(base + 6)
    self.makeItem(base + 7)
  }

  @ViewBuilder private func group4(base: Int) -> some View {
    self.makeItem(base)
    self.makeItem(base + 1)
    self.makeItem(base + 2)
    self.makeItem(base + 3)
  }

  @ViewBuilder private func group2(base: Int) -> some View {
    self.makeItem(base)
    self.makeItem(base + 1)
  }
}
