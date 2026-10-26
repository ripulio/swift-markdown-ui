import XCTest
@testable import MarkdownUI

final class InlineTextChunkingTests: XCTestCase {
  func testPreservesEveryLineAndStyleAtChunkBoundaries() {
    var inlines: [InlineNode] = []
    for index in 1...1200 {
      if index > 1 { inlines.append(.softBreak) }
      inlines.append(.strong(children: [.text("Line \(index)")]))
      inlines.append(.text(" and "))
      inlines.append(.link(destination: "https://example.com/\(index)", children: [.text("link")]))
    }
    let chunks = inlines.textChunks(softBreakMode: .lineBreak)
    XCTAssertEqual(chunks.count, 38)
    var restored: [InlineNode] = []
    for chunk in chunks {
      if !restored.isEmpty { restored.append(.softBreak) }
      restored += chunk
    }
    XCTAssertEqual(restored, inlines)
  }

  func testSpaceModeDoesNotIntroduceNewlines() {
    let inlines = (0..<100).flatMap { [InlineNode.text("word \($0)"), .softBreak] }
    XCTAssertEqual(inlines.textChunks(softBreakMode: .space), [inlines])
  }

  func testSmallParagraphAndNestedStyleStayTogether() {
    let content: [InlineNode] = [.text("Hello "), .strong(children: [.text("one"), .lineBreak, .text("two")])]
    XCTAssertEqual(content.textChunks(softBreakMode: .lineBreak), [content])
  }

  func testTrailingAndRepeatedBlankLinesSurviveAChunkBoundary() {
    let content: [InlineNode] = [.text("one"), .lineBreak, .text("two"), .lineBreak]
    XCTAssertEqual(content.textChunks(softBreakMode: .lineBreak, maximumLines: 2), [content])
    let withBlankLines = content + [.lineBreak, .lineBreak, .text("last"), .lineBreak]
    let chunks = withBlankLines.textChunks(softBreakMode: .lineBreak, maximumLines: 2)
    XCTAssertEqual(chunks.flatMapWithSeparator(.lineBreak), withBlankLines)
    XCTAssertFalse(chunks.last!.isEmpty)
  }
}

private extension Array where Element == [InlineNode] {
  func flatMapWithSeparator(_ separator: InlineNode) -> [InlineNode] {
    enumerated().flatMap { index, nodes in (index == 0 ? [] : [separator]) + nodes }
  }
}
