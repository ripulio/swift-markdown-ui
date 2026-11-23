import XCTest
@testable import MarkdownUI

final class ListLinkSelectionTests: XCTestCase {
  func testPlainBulletedListDoesNotTriggerOccludedLink() {
    let blocks = MarkdownContent(
      """
      - Plain item one
      - Plain item two
      """
    ).blocks
    guard case .bulletedList(_, let items) = blocks.first else {
      return XCTFail("Expected bulleted list")
    }
    XCTAssertFalse(items.hasOccludedListLink)
  }

  func testLinkOnlyInLastItemDoesNotTriggerOccludedLink() {
    let blocks = MarkdownContent(
      """
      - Plain item one
      - [Last link](https://example.com)
      """
    ).blocks
    guard case .bulletedList(_, let items) = blocks.first else {
      return XCTFail("Expected bulleted list")
    }
    XCTAssertFalse(items.hasOccludedListLink)
  }

  func testLinkBeforeAnotherItemTriggersOccludedLink() {
    let cases = [
      """
      - [Wikipedia](https://www.wikipedia.org)
      - [NASA](https://www.nasa.gov)
      """,
      """
      - [Wikipedia](https://www.wikipedia.org)
      - Plain item below
      """,
      """
      - **[Bold link](https://www.wikipedia.org)**
      - Plain item below
      """,
      """
      - Bare URL: https://example.com
      - Plain item below
      """,
      """
      - [Ref link][r]
      - Plain item below

      [r]: https://example.com
      """,
    ]
    for markdown in cases {
      let blocks = MarkdownContent(markdown).blocks
      guard case .bulletedList(_, let items) = blocks.first else {
        return XCTFail("Expected bulleted list for:\n\(markdown)")
      }
      XCTAssertTrue(items.hasOccludedListLink, "Expected occluded link for:\n\(markdown)")
    }
  }

  func testNestedListLinksTriggerOccludedLinkOnEnclosingList() {
    // Nested link inside a non-final parent item is followed by Parent 2.
    let nestedBeforeSibling = MarkdownContent(
      """
      - Parent 1
        - [Nested link](https://example.com)
      - Parent 2
      """
    ).blocks
    guard case .bulletedList(_, let outerItems) = nestedBeforeSibling.first else {
      return XCTFail("Expected outer bulleted list")
    }
    XCTAssertTrue(outerItems.hasOccludedListLink)

    // Link on a parent item directly above its nested child list.
    let parentLinkAboveChild = MarkdownContent(
      """
      - [Parent link](https://example.com)
        - Plain child
      """
    ).blocks
    guard case .bulletedList(_, let singleParentItems) = parentLinkAboveChild.first else {
      return XCTFail("Expected outer bulleted list")
    }
    XCTAssertTrue(singleParentItems.hasOccludedListLink)

    // Link on paragraph 1 of a multi-paragraph list item above paragraph 2.
    let multiParagraphItem = MarkdownContent(
      """
      - [First paragraph link](https://example.com)

        Second paragraph in same item
      """
    ).blocks
    guard case .bulletedList(_, let multiParaItems) = multiParagraphItem.first else {
      return XCTFail("Expected bulleted list")
    }
    XCTAssertTrue(multiParaItems.hasOccludedListLink)
  }

  func testNumberedAndTaskListsDetectOccludedLinks() {
    let numbered = MarkdownContent(
      """
      1. [One](https://one.example)
      2. [Two](https://two.example)
      """
    ).blocks
    guard case .numberedList(_, _, let numberedItems) = numbered.first else {
      return XCTFail("Expected numbered list")
    }
    XCTAssertTrue(numberedItems.hasOccludedListLink)

    let task = MarkdownContent(
      """
      - [x] [Done link](https://done.example)
      - [ ] Plain open task
      """
    ).blocks
    guard case .taskList(_, let taskItems) = task.first else {
      return XCTFail("Expected task list")
    }
    XCTAssertTrue(taskItems.hasOccludedListLink)

    let plainTask = MarkdownContent(
      """
      - [x] Done task
      - [ ] [Last link](https://last.example)
      """
    ).blocks
    guard case .taskList(_, let plainTaskItems) = plainTask.first else {
      return XCTFail("Expected task list")
    }
    XCTAssertFalse(plainTaskItems.hasOccludedListLink)
  }
}
