import XCTest
@testable import MarkdownUI

final class InlineImageFragmentTests: XCTestCase {
  func testLinkedImageInsideProseKeepsTextAndDestination() {
    let nodes: [InlineNode] = [.text("before "), .link(destination: "https://example.com", children: [
      .image(source: "image.png", children: [.text("Alt")])
    ]), .text(" after")]
    XCTAssertEqual(nodes.imageFragments(), [
      .text([.text("before ")]),
      .image(.init(source: "image.png", alt: "Alt", destination: "https://example.com")),
      .text([.text(" after")])
    ])
  }

  func testNestedStylesAndLinksAroundAnImageSurvive() {
    let nodes: [InlineNode] = [.strong(children: [.link(destination: "https://example.com", children: [
      .text("before "), .image(source: "image.png", children: [.text("Alt")]), .text(" after")
    ])])]
    let fragments = nodes.imageFragments()
    XCTAssertEqual(fragments.count, 3)
    XCTAssertEqual(fragments[0], .text([.strong(children: [.link(destination: "https://example.com", children: [.text("before ")])])]))
    XCTAssertEqual(fragments[1], .image(.init(source: "image.png", alt: "Alt", destination: "https://example.com")))
    XCTAssertEqual(fragments[2], .text([.strong(children: [.link(destination: "https://example.com", children: [.text(" after")])])]))
  }

  func testParagraphWithoutImagesIsUnchanged() {
    let nodes: [InlineNode] = [.text("A "), .strong(children: [.text("bold")]), .text(" paragraph.")]
    XCTAssertEqual(nodes.imageFragments(), [.text(nodes)])
  }
}
