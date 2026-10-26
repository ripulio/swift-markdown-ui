import MarkdownUI
import XCTest

final class ChatDocumentTests: XCTestCase {
  func testLongFenceContainsShorterFenceLiterally() {
    let source = "````markdown\n```swift\nlet value = 1\n```\n````"
    XCTAssertEqual(MarkdownContent(source), MarkdownContent {
      CodeBlock(language: "markdown", content: "```swift\nlet value = 1\n```\n")
    })
  }

  func testReferenceLinkResolvesAcrossCodeBlock() {
    let source = "[Guide][guide]\n\n~~~swift\nlet value = 1\n~~~\n\n[guide]: https://example.com/guide"
    let html = MarkdownContent(source).renderHTML()
    XCTAssertTrue(html.contains("href=\"https://example.com/guide\""))
    XCTAssertTrue(html.contains("language-swift"))
    XCTAssertFalse(html.contains("[guide]"))
  }

  func testQuotedCodeKeepsContainerAndLanguage() {
    let source = "> A quote\n>\n> ~~~swift\n> let value = 1\n> ~~~"
    let html = MarkdownContent(source).renderHTML()
    XCTAssertTrue(html.contains("<blockquote>"))
    XCTAssertTrue(html.contains("<pre><code class=\"language-swift\">let value = 1"))
    XCTAssertTrue(html.contains("</code></pre>\n</blockquote>"))
  }
}
