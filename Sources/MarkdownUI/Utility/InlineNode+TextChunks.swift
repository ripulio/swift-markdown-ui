import Foundation

extension Array where Element == InlineNode {
  /// Bound the work done by SwiftUI's per-Text layout/accessibility machinery.
  /// Split only at authored rendered newlines; never split/reparse Markdown or
  /// lose a style/link spanning a line. Ordinary paragraphs remain one Text.
  func textChunks(softBreakMode: SoftBreak.Mode, maximumLines: Int = 32) -> [[InlineNode]] {
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
      if isBreak, lines >= Swift.max(2, maximumLines), index < self.count - 1 {
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
