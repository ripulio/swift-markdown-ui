import XCTest
@testable import MarkdownUI

final class SelectionTextTests: XCTestCase {
  func testContinuousSelectionPreservesBlocksAndNestedTraits() {
    let result = MarkdownContent("# Heading\n\nFirst **bold and *italic***.\nSecond line.\n\n- Item\n- Other").renderAttributedString(softBreaks: true)
    XCTAssertEqual(String(result.characters), "Heading\n\nFirst bold and italic.\nSecond line.\n\n• Item\n• Other")
    let italic = result.runs.first { String(result[$0.range].characters) == "italic" }!
    XCTAssertTrue(italic.inlinePresentationIntent!.contains([.emphasized, .stronglyEmphasized]))
  }

  func testReferenceLinksKeepDestinationAndCodeKeepsLiteralText() {
    let result = MarkdownContent("[Guide][ref]\n\n```text\n**literal** <xml>\n```\n\n[ref]: https://example.com").renderAttributedString()
    XCTAssertEqual(result.runs.first?.link?.absoluteString, "https://example.com")
    XCTAssertEqual(String(result.characters), "Guide\n\n**literal** <xml>")
    XCTAssertTrue(result.runs.last!.inlinePresentationIntent!.contains(.code))
  }

  func testTablesRemainCopyableAsRowsAndCells() {
    let result = MarkdownContent("| Name | Count |\n|---|---:|\n| **Alpha** | 2 |").renderAttributedString()
    XCTAssertEqual(String(result.characters), "Name\tCount\nAlpha\t2")
    XCTAssertTrue(result.runs.first!.inlinePresentationIntent!.contains(.stronglyEmphasized))
  }
}
