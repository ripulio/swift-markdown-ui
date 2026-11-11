import Foundation

extension Array where Element == InlineNode {
  /// Returns `true` only when `textChunks(softBreakMode:maximumLines:)` would split this inline run
  /// into more than one `Text`, avoiding outer array allocations for ordinary paragraphs, list items,
  /// headings, and table cells.
  func hasMultipleTextChunks(softBreakMode: SoftBreak.Mode, maximumLines: Int = 32) -> Bool {
    let limit = Swift.max(2, maximumLines)
    guard self.count > limit else {
      return false
    }
    var lines = 1
    for index in self.indices {
      let isBreak: Bool
      switch self[index] {
      case .lineBreak: isBreak = true
      case .softBreak: isBreak = softBreakMode == .lineBreak
      default: isBreak = false
      }
      if isBreak {
        if lines >= limit, index < self.count - 1 {
          return true
        }
        lines += 1
      }
    }
    return false
  }

  /// Bound the work done by SwiftUI's per-Text layout/accessibility machinery.
  /// Split only at authored rendered newlines; never split/reparse Markdown or
  /// lose a style/link spanning a line. Ordinary paragraphs remain one Text.
  func textChunks(softBreakMode: SoftBreak.Mode, maximumLines: Int = 32) -> [[InlineNode]] {
    let limit = Swift.max(2, maximumLines)
    if self.count <= limit {
      return [self]
    }
    var chunks: [[InlineNode]] = []
    var current: [InlineNode] = []
    var lines = 1
    for (index, inline) in self.enumerated() {
      let isBreak: Bool
      switch inline {
      case .lineBreak: isBreak = true
      case .softBreak: isBreak = softBreakMode == .lineBreak
      default: isBreak = false
      }
      // Keep a final newline in the Text itself: an empty trailing Text has no
      // line height, so splitting there would silently remove the blank line.
      if isBreak, lines >= limit, index < self.count - 1 {
        chunks.append(current)
        current = []
        lines = 1
      } else {
        current.append(inline)
        if isBreak { lines += 1 }
      }
    }
    if !current.isEmpty || chunks.isEmpty { chunks.append(current) }
    return chunks
  }
}
