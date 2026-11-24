#if os(macOS) || os(iOS)
  import SwiftUI
  import XCTest
  @testable import MarkdownUI

  #if os(macOS)
    import AppKit
  #elseif os(iOS)
    import UIKit
  #endif

  final class Performance26Tests: XCTestCase {

    // MARK: - 1. Numbered Lists (Single-Pass, Multi-Digit, All Built-In Markers, Fallback)

    @MainActor
    func testNumberedListSinglePassParityAcrossDigitTransitionsAndMarkers() {
      let list16 = (1...16).map {
        "\($0). Item \($0) with **bold**, `code`, and wrapping text across lines to verify aligned baselines."
      }.joined(separator: "\n")

      let list98to102 = (98...102).map {
        "\($0). Three-digit transition item \($0) wrapping cleanly next to right-aligned numerals."
      }.joined(separator: "\n")

      let cases: [(String, String, BlockStyle<ListMarkerConfiguration>, BlockStyle<ListMarkerConfiguration>)] = [
        (
          "decimal_16",
          list16,
          .decimal,
          BlockStyle { configuration in
            Text("\(configuration.itemNumber).")
              .monospacedDigit()
              .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
          }
        ),
        (
          "decimal_98_to_102",
          list98to102,
          .decimal,
          BlockStyle { configuration in
            Text("\(configuration.itemNumber).")
              .monospacedDigit()
              .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
          }
        ),
        (
          "upperRoman_16",
          list16,
          .upperRoman,
          BlockStyle { configuration in
            Text(configuration.itemNumber.roman + ".")
              .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
          }
        ),
        (
          "lowerRoman_16",
          list16,
          .lowerRoman,
          BlockStyle { configuration in
            Text(configuration.itemNumber.roman.lowercased() + ".")
              .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
          }
        ),
        (
          "dash_16",
          list16,
          .dash,
          BlockStyle { _ in
            Text("-")
              .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
          }
        ),
      ]

      for (name, markdown, fastMarker, legacyMarker) in cases {
        let fastTheme = Theme.basic.numberedListMarker { fastMarker.makeBody(configuration: $0) }
        _ = fastTheme // ensure marker style itself is applied via property assignment below
        var directTheme = Theme.basic
        directTheme.numberedListMarker = fastMarker
        var legacyTheme = Theme.basic
        legacyTheme.numberedListMarker = legacyMarker

        let expected = self.render(markdown, theme: legacyTheme, width: 340, settlePasses: 8)
        let actual = self.render(markdown, theme: directTheme, width: 340, settlePasses: 8)

        XCTAssertEqual(
          actual.firstPassHeight,
          expected.settledHeight,
          accuracy: 0.5,
          "Numbered list first-pass height mismatch for \(name)"
        )
        XCTAssertEqual(
          actual.settledHeight,
          expected.settledHeight,
          accuracy: 0.5,
          "Numbered list settled height mismatch for \(name)"
        )
        XCTAssertEqual(
          actual.bitmapData,
          expected.bitmapData,
          "Numbered list pixel mismatch for \(name)"
        )
      }

      // Custom numberedListMarker override must bypass CompactNumberedListView and take effect.
      let defaultRender = self.render("1. One\n2. Two", theme: .basic, width: 320, settlePasses: 4)
      let customRender = self.renderHostView(
        Markdown("1. One\n2. Two")
          .markdownBlockStyle(\.numberedListMarker) { config in
            Text("[\(config.itemNumber)]")
              .padding(.vertical, 16)
          }
          .markdownTheme(.basic)
          .frame(width: 320, alignment: .leading),
        width: 320,
        settlePasses: 6
      )
      XCTAssertGreaterThan(
        customRender.settledHeight,
        defaultRender.settledHeight + 40,
        "Custom numberedListMarker override must take effect"
      )
    }

    // MARK: - 2. Task Lists (Single-Pass Parity & Custom Fallback)

    @MainActor
    func testTaskListSinglePassParityAndCustomOverrideFallback() {
      let markdown = (1...12).map { idx in
        let mark = idx.isMultiple(of: 2) ? "x" : " "
        return "- [\(mark)] Task \(idx) with **bold**, `code`, ~~strike~~, and [link](https://example.com) wrapping cleanly."
      }.joined(separator: "\n")

      let themes: [(String, Theme, BlockStyle<TaskListMarkerConfiguration>)] = [
        (
          "basic",
          .basic,
          BlockStyle { configuration in
            Image(systemName: configuration.isCompleted ? "checkmark.square.fill" : "square")
              .symbolRenderingMode(.hierarchical)
              .imageScale(.small)
              .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
          }
        ),
        (
          "docC",
          .docC,
          BlockStyle { _ in
            ListBullet.disc
              .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
          }
        ),
      ]

      for (name, fastTheme, legacyMarker) in themes {
        var legacyTheme = fastTheme
        legacyTheme.taskListMarker = legacyMarker

        let expected = self.render(markdown, theme: legacyTheme, width: 340, settlePasses: 8)
        let actual = self.render(markdown, theme: fastTheme, width: 340, settlePasses: 8)

        XCTAssertEqual(
          actual.firstPassHeight,
          expected.settledHeight,
          accuracy: 0.5,
          "Task list first-pass height mismatch for \(name)"
        )
        XCTAssertEqual(
          actual.bitmapData,
          expected.bitmapData,
          "Task list pixel mismatch for \(name)"
        )
      }

      // Theme.chat & Theme.gitHub settle on pass 1.
      for (name, theme) in [("gitHub", Theme.gitHub), ("chat", Theme.chat)] {
        let snap = self.render(markdown, theme: theme, width: 340, settlePasses: 6)
        XCTAssertEqual(
          snap.firstPassHeight,
          snap.settledHeight,
          accuracy: 0.5,
          "Task list should settle on pass 1 for \(name)"
        )
      }

      // Custom taskListMarker override must take effect.
      let defaultTask = self.render("- [x] Done\n- [ ] Todo", theme: .gitHub, width: 320, settlePasses: 4)
      let customTask = self.renderHostView(
        Markdown("- [x] Done\n- [ ] Todo")
          .markdownBlockStyle(\.taskListMarker) { config in
            Text(config.isCompleted ? "DONE" : "OPEN")
              .padding(.vertical, 18)
          }
          .markdownTheme(.gitHub)
          .frame(width: 320, alignment: .leading),
        width: 320,
        settlePasses: 6
      )
      XCTAssertGreaterThan(
        customTask.settledHeight,
        defaultTask.settledHeight + 40,
        "Custom taskListMarker override must take effect"
      )
    }

    // MARK: - 3. Nested Bulleted Lists (Flattened Single-Pass Parity & Complex Fallback)

    @MainActor
    func testNestedBulletedListSinglePassParityAndComplexFallback() {
      let nestedMarkdown = """
        - Level 1 item A with **bold** and `code` wrapping across lines
          - Level 2 item A1 with *italic* text
            - Level 3 item A1a with ~~strikethrough~~
            - Level 3 item A1b
          - Level 2 item A2 with [link](https://example.com)
        - Level 1 item B
          - Level 2 item B1
            - Level 3 item B1a wrapping across multiple lines to verify indented width calculation
        """

      let legacyMarker = BlockStyle<ListMarkerConfiguration> { configuration in
        switch min(configuration.listLevel, 3) {
        case 1: ListBullet.disc.markerFrame()
        case 2: ListBullet.circle.markerFrame()
        default: ListBullet.square.markerFrame()
        }
      }

      for (name, fastTheme) in [("basic", Theme.basic), ("gitHub", Theme.gitHub), ("docC", Theme.docC), ("chat", Theme.chat)] {
        var legacyTheme = fastTheme
        legacyTheme.bulletedListMarker = legacyMarker

        let expected = self.render(nestedMarkdown, theme: legacyTheme, width: 340, settlePasses: 8)
        let actual = self.render(nestedMarkdown, theme: fastTheme, width: 340, settlePasses: 8)

        XCTAssertEqual(
          actual.firstPassHeight,
          expected.settledHeight,
          accuracy: 0.5,
          "Nested bullet first-pass height mismatch for \(name)"
        )
        XCTAssertEqual(
          actual.bitmapData,
          expected.bitmapData,
          "Nested bullet pixel mismatch for \(name)"
        )
      }

      // Nested list containing a fenced code block inside an item falls back cleanly.
      let complexNested = """
        - Outer item with code block:

          ```swift
          let x = 42
          ```

        - Second outer item
        """
      let complexSnap = self.render(complexNested, theme: .gitHub, width: 340, settlePasses: 6)
      XCTAssertGreaterThan(complexSnap.settledHeight, 60)
    }

    // MARK: - 4. Automatic Tables (Single-Pass Wrapping + Non-Wrapping Parity & Fallback)

    @MainActor
    func testAutomaticTableSinglePassParityAcrossWrappingAndNonWrappingWidths() {
      let tableMarkdown = """
        | Component | Alignment | Measurements & Notes | Status |
        | :--- | :---: | :--- | ---: |
        | `AutomaticTableLayout` | center | Replaces SwiftUI `Grid` + `PreferenceKey` for built-in `.automatic` tables | **Fast** |
        | `NumberedListLayout` | center | Single-pass `.firstTextBaseline` alignment across 1-to-3-digit markers | 100% |
        | `DirectTextStyle` | center | Handles ~~strikethrough~~, `code`, *italic*, and links natively | Ready |
        """

      let legacyBasicCell = BlockStyle<TableCellConfiguration> { configuration in
        configuration.label
          .markdownTextStyle {
            if configuration.row == 0 { FontWeight(.semibold) }
          }
          .fixedSize(horizontal: false, vertical: true)
          .relativeLineSpacing(.em(0.15))
          .relativePadding(.horizontal, length: .em(0.72))
          .relativePadding(.vertical, length: .em(0.35))
      }

      let legacyGitHubCell = BlockStyle<TableCellConfiguration> { configuration in
        configuration.label
          .markdownTextStyle {
            if configuration.row == 0 { FontWeight(.semibold) }
            BackgroundColor(nil)
          }
          .fixedSize(horizontal: false, vertical: true)
          .padding(.vertical, 6)
          .padding(.horizontal, 13)
          .relativeLineSpacing(.em(0.25))
      }

      for width in [CGFloat(320), CGFloat(560)] {
        for (name, fastTheme, legacyCell) in [
          ("basic", Theme.basic, legacyBasicCell),
          ("gitHub", Theme.gitHub, legacyGitHubCell),
        ] {
          var legacyTheme = fastTheme
          legacyTheme.tableCell = legacyCell

          let expected = self.render(tableMarkdown, theme: legacyTheme, width: width, settlePasses: 8)
          let actual = self.render(tableMarkdown, theme: fastTheme, width: width, settlePasses: 8)

          XCTAssertEqual(
            actual.firstPassHeight,
            expected.settledHeight,
            accuracy: 0.5,
            "Automatic table first-pass height mismatch for \(name) width=\(width)"
          )
          XCTAssertEqual(
            actual.bitmapData,
            expected.bitmapData,
            "Automatic table pixel mismatch for \(name) width=\(width)"
          )
        }
      }
    }

    // MARK: - 5. Mounted Environment Changes Propagate Through Equatable Blocks

    @MainActor
    func testMountedEnvironmentChangesPropagateThroughEquatableBlocks() {
      let markdown = """
        ## Header

        A wrapping paragraph with **bold** and `code` that changes height under different themes and line limits.

        - Bullet one
        - Bullet two

        1. Numbered one
        2. Numbered two

        | Key | Value |
        | :--- | :--- |
        | Layout | Single-pass automatic and adaptive table layout verification |
        | Cache | Must respond to dynamic environment changes on mounted views |
        """

      final class Model: ObservableObject {
        @Published var theme: Theme = .basic
        @Published var tableLayout: TableLayoutStyle = .automatic
        @Published var lineLimit: Int? = nil
      }

      struct HostView: View {
        @ObservedObject var model: Model
        let markdown: String
        var body: some View {
          Markdown(self.markdown)
            .markdownTheme(self.model.theme)
            .markdownTableLayout(self.model.tableLayout)
            .lineLimit(self.model.lineLimit)
            .frame(width: 340, alignment: .leading)
        }
      }

      let model = Model()
      let harness = MountedHarness(rootView: HostView(model: model, markdown: markdown), width: 340)
      defer { harness.tearDown() }

      let basicHeight = harness.settleAndMeasureHeight()
      let expectedBasic = self.render(markdown, theme: .basic, width: 340, settlePasses: 4).settledHeight
      XCTAssertEqual(basicHeight, expectedBasic, accuracy: 0.5)

      model.theme = .gitHub
      let gitHubHeight = harness.settleAndMeasureHeight()
      let expectedGitHub = self.render(markdown, theme: .gitHub, width: 340, settlePasses: 4).settledHeight
      XCTAssertEqual(gitHubHeight, expectedGitHub, accuracy: 0.5)
      XCTAssertNotEqual(basicHeight, gitHubHeight, accuracy: 2.0, "Theme change must update mounted view height")

      model.tableLayout = .adaptive(availableWidth: 260, minimumColumnWidth: 60, maximumColumnWidth: 160)
      let adaptiveHeight = harness.settleAndMeasureHeight()
      let expectedAdaptive = self.renderHostView(
        Markdown(markdown)
          .markdownTheme(.gitHub)
          .markdownTableLayout(.adaptive(availableWidth: 260, minimumColumnWidth: 60, maximumColumnWidth: 160))
          .frame(width: 340, alignment: .leading),
        width: 340,
        settlePasses: 4
      ).settledHeight
      XCTAssertEqual(adaptiveHeight, expectedAdaptive, accuracy: 0.5)

      model.lineLimit = 1
      let singleLineHeight = harness.settleAndMeasureHeight()
      XCTAssertLessThan(
        singleLineHeight,
        adaptiveHeight - 20,
        "Changing lineLimit on mounted view must invalidate retained prefix sizes"
      )
    }

    // MARK: - 6. Theme.gitHub Custom Blockquote & DirectTextStyle Strikethrough/Underline

    @MainActor
    func testThemeGitHubCustomBlockquotePreservesBackgroundAndDirectDecorations() {
      let quoteMarkdown = """
        Paragraph with ~~strikethrough~~ and *underlined emphasis*.

        > Quoted line inside a custom background blockquote.
        """

      let fast = self.renderHostView(
        Markdown(quoteMarkdown)
          .markdownTextStyle(\.emphasis) {
            UnderlineStyle(.single)
          }
          .markdownBlockStyle(\.blockquote) { configuration in
            configuration.label
              .padding()
              .background(Color.teal.opacity(0.4))
          }
          .markdownTheme(.gitHub)
          .frame(width: 340, alignment: .leading),
        width: 340,
        settlePasses: 6
      )

      // Force AttributedString fallback via BackgroundColor(.clear) and verify strikethrough +
      // underline match pixel-for-pixel in standard Theme.basic too.
      let directDecorations = self.renderHostView(
        Markdown("Text with ~~strikethrough~~ and *underlined* spans in a paragraph.")
          .markdownTextStyle(\.emphasis) {
            UnderlineStyle(.single)
          }
          .markdownTheme(.basic)
          .frame(width: 340, alignment: .leading),
        width: 340,
        settlePasses: 4
      )
      let attributedDecorations = self.renderHostView(
        Markdown("Text with ~~strikethrough~~ and *underlined* spans in a paragraph.")
          .markdownTextStyle(\.text) {
            BackgroundColor(.clear)
          }
          .markdownTextStyle(\.emphasis) {
            UnderlineStyle(.single)
          }
          .markdownTheme(.basic)
          .frame(width: 340, alignment: .leading),
        width: 340,
        settlePasses: 4
      )

      XCTAssertGreaterThan(fast.settledHeight, 60)
      XCTAssertEqual(
        directDecorations.settledHeight,
        attributedDecorations.settledHeight,
        accuracy: 0.5,
        "DirectTextStyle strikethrough/underline height must match AttributedString"
      )
      XCTAssertEqual(
        directDecorations.bitmapData,
        attributedDecorations.bitmapData,
        "DirectTextStyle strikethrough/underline pixels must match AttributedString"
      )
    }

    // MARK: - 7. Streaming Incremental Growth & Safety Invariant #7 (Descendant @State)

    @MainActor
    func testStreamingIncrementalGrowthMatchesColdRenderAndPropagatesDescendantState() {
      let fullMarkdown = """
        ## Streaming Report

        First completed paragraph with **bold**, `code`, and [link](https://example.com).

        - Bullet item one
        - Bullet item two
          - Nested child bullet

        1. First numbered step
        2. Second numbered step

        - [x] Completed check
        - [ ] Remaining check

        | Metric | Value |
        | :--- | ---: |
        | Cold | 12 ms |
        | Stream | 1 ms |

        Final trailing paragraph that grows token by token during streaming.
        """

      final class StreamModel: ObservableObject {
        @Published var text: String = ""
      }

      struct StreamView: View {
        @ObservedObject var model: StreamModel
        var body: some View {
          Markdown(self.model.text)
            .markdownTheme(.chat)
            .frame(width: 360, alignment: .leading)
        }
      }

      let model = StreamModel()
      let harness = MountedHarness(rootView: StreamView(model: model), width: 360)
      defer { harness.tearDown() }

      let steps = 16
      let totalChars = fullMarkdown.count
      for step in 1...steps {
        let count = (totalChars * step) / steps
        model.text = String(fullMarkdown.prefix(count))
        _ = harness.settleAndMeasureHeight(passes: 1)
      }
      let streamedFinalHeight = harness.settleAndMeasureHeight(passes: 4)
      let coldFinalHeight = self.render(fullMarkdown, theme: .chat, width: 360, settlePasses: 4).settledHeight

      XCTAssertEqual(
        streamedFinalHeight,
        coldFinalHeight,
        accuracy: 0.5,
        "Incrementally streamed document height must match cold render"
      )

      // Safety Invariant #7: a descendant @State height mutation inside a codeBlock must
      // propagate immediately through BlockSpacedStackLayout even when rawBlocks is unchanged.
      final class ExpandController: ObservableObject {
        @Published var expanded = false
      }

      struct ExpandableCodeView: View {
        @ObservedObject var controller: ExpandController
        let configuration: CodeBlockConfiguration
        var body: some View {
          VStack(alignment: .leading, spacing: 0) {
            self.configuration.label
            if self.controller.expanded {
              Color.clear.frame(height: 120)
            }
          }
        }
      }

      let expandController = ExpandController()
      let codeDoc = """
        Intro paragraph above code block.

        ```swift
        let answer = 42
        ```

        Closing paragraph below code block.
        """

      let codeHarness = MountedHarness(
        rootView: Markdown(codeDoc)
          .markdownBlockStyle(\.codeBlock) { config in
            ExpandableCodeView(controller: expandController, configuration: config)
          }
          .markdownTheme(.basic)
          .frame(width: 340, alignment: .leading),
        width: 340
      )
      defer { codeHarness.tearDown() }

      let collapsedHeight = codeHarness.settleAndMeasureHeight(passes: 2)
      expandController.expanded = true
      let expandedHeight = codeHarness.settleAndMeasureHeight(passes: 2)

      XCTAssertEqual(
        expandedHeight - collapsedHeight,
        120,
        accuracy: 1.0,
        "Descendant @State height change inside a code block must propagate through BlockSpacedStackLayout"
      )

      // StaticViewBatch prefix stability: appending new blocks across power-of-two counts
      // (3 -> 4 -> 8 -> 10) must NOT destroy/recreate earlier stateful blocks.
      final class IdentityCounter {
        var initCount = 0
      }

      struct StatefulIdentityBox: View {
        let counter: IdentityCounter
        @State private var token: Int
        init(counter: IdentityCounter) {
          self.counter = counter
          self._token = State(initialValue: 0)
        }
        var body: some View {
          Color.clear
            .frame(height: 24)
            .onAppear { self.counter.initCount += 1 }
        }
      }

      final class GrowingDocModel: ObservableObject {
        @Published var blockCount = 3
        var markdown: String {
          var parts = [
            "Intro paragraph.",
            "```swift\nlet stable = true\n```",
            "Paragraph 3.",
          ]
          if self.blockCount > 3 {
            for i in 4...self.blockCount {
              parts.append("Appended paragraph \(i).")
            }
          }
          return parts.joined(separator: "\n\n")
        }
      }

      struct GrowingDocView: View {
        @ObservedObject var model: GrowingDocModel
        let counter: IdentityCounter
        var body: some View {
          Markdown(self.model.markdown)
            .markdownBlockStyle(\.codeBlock) { (_: CodeBlockConfiguration) in
              StatefulIdentityBox(counter: self.counter)
            }
            .markdownTheme(.basic)
            .frame(width: 340, alignment: .leading)
        }
      }

      let idCounter = IdentityCounter()
      let growingModel = GrowingDocModel()
      let idHarness = MountedHarness(
        rootView: GrowingDocView(model: growingModel, counter: idCounter),
        width: 340
      )
      defer { idHarness.tearDown() }

      _ = idHarness.settleAndMeasureHeight(passes: 2)
      XCTAssertEqual(idCounter.initCount, 1)

      for count in [4, 7, 8, 9, 16, 17] {
        growingModel.blockCount = count
        _ = idHarness.settleAndMeasureHeight(passes: 2)
      }
      XCTAssertEqual(
        idCounter.initCount,
        1,
        "Appending blocks across power-of-two boundaries must keep existing block identity intact"
      )
    }

    // MARK: - 8. Parser Integer-Enum Parity Across All GFM Constructs

    func testParserIntegerEnumParityAcrossAllGFMConstructs() {
      let markdown = """
        # Title

        Paragraph with **strong**, *em*, ~~del~~, `code`, [link](https://example.com), and ![img](https://example.com/a.png).

        > Quoted text

        - Bullet A
          - Nested B

        3. Ordered 3
        4. Ordered 4

        - [x] Checked
        - [ ] Unchecked

        ```swift
        let x = 1
        ```

        ---

        | Col A | Col B | Col C |
        | :--- | :---: | ---: |
        | L | C | R |
        """

      let content = MarkdownContent(markdown)
      XCTAssertEqual(content.blocks.count, 9)

      if case .heading(level: 1, _) = content.blocks[0] {} else {
        XCTFail("Expected heading level 1, got \(content.blocks[0])")
      }
      if case .paragraph(let inlines) = content.blocks[1] {
        XCTAssertTrue(inlines.contains { if case .strong = $0 { return true }; return false })
        XCTAssertTrue(inlines.contains { if case .emphasis = $0 { return true }; return false })
        XCTAssertTrue(inlines.contains { if case .strikethrough = $0 { return true }; return false })
        XCTAssertTrue(inlines.contains { if case .code = $0 { return true }; return false })
        XCTAssertTrue(inlines.contains { if case .link = $0 { return true }; return false })
        XCTAssertTrue(inlines.contains { if case .image = $0 { return true }; return false })
      } else {
        XCTFail("Expected paragraph, got \(content.blocks[1])")
      }
      if case .blockquote = content.blocks[2] {} else {
        XCTFail("Expected blockquote, got \(content.blocks[2])")
      }
      if case .bulletedList(_, let items) = content.blocks[3] {
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].children.count, 2)
      } else {
        XCTFail("Expected bulletedList, got \(content.blocks[3])")
      }
      if case .numberedList(_, let start, let items) = content.blocks[4] {
        XCTAssertEqual(start, 3)
        XCTAssertEqual(items.count, 2)
      } else {
        XCTFail("Expected numberedList, got \(content.blocks[4])")
      }
      if case .taskList(_, let items) = content.blocks[5] {
        XCTAssertEqual(items.map(\.isCompleted), [true, false])
      } else {
        XCTFail("Expected taskList, got \(content.blocks[5])")
      }
      if case .codeBlock(let fence, let code) = content.blocks[6] {
        XCTAssertEqual(fence, "swift")
        XCTAssertTrue(code.contains("let x = 1"))
      } else {
        XCTFail("Expected codeBlock, got \(content.blocks[6])")
      }
      if case .thematicBreak = content.blocks[7] {} else {
        XCTFail("Expected thematicBreak, got \(content.blocks[7])")
      }
      if case .table(let alignments, let rows) = content.blocks[8] {
        XCTAssertEqual(alignments, [.left, .center, .right])
        XCTAssertEqual(rows.count, 2)
      } else {
        XCTFail("Expected table, got \(content.blocks[8])")
      }

      // Verify DSL/AST -> cmark rendering via bootstrapped public-API ExtensionNodeTypes (no dlsym).
      let dslContent = MarkdownContent {
        Paragraph {
          "Before "
          Strikethrough("removed")
          " after"
        }
        TextTable([("One", "Two")]) {
          TextTableColumn(title: "Col A", value: \.0)
          TextTableColumn(title: "Col B", value: \.1)
        }
      }
      let renderedMarkdown = dslContent.renderMarkdown()
      XCTAssertTrue(
        renderedMarkdown.contains("~~removed~~"),
        "Expected strikethrough Markdown, got: \(renderedMarkdown)"
      )
      XCTAssertTrue(
        renderedMarkdown.contains("|Col A|Col B|"),
        "Expected table header Markdown, got: \(renderedMarkdown)"
      )
      XCTAssertTrue(
        renderedMarkdown.contains("|One|Two|"),
        "Expected table body Markdown, got: \(renderedMarkdown)"
      )
    }

    // MARK: - Helpers

    private struct Snapshot {
      let firstPassHeight: CGFloat
      let settledHeight: CGFloat
      let bitmapData: Data?
    }

    @MainActor
    private func render(
      _ markdown: String,
      theme: Theme,
      width: CGFloat,
      settlePasses: Int
    ) -> Snapshot {
      self.renderHostView(
        Markdown(markdown)
          .markdownTheme(theme)
          .frame(width: width, alignment: .leading),
        width: width,
        settlePasses: settlePasses
      )
    }

    @MainActor
    private func renderHostView<V: View>(
      _ rootView: V,
      width: CGFloat,
      settlePasses: Int
    ) -> Snapshot {
      #if os(macOS)
        let host = NSHostingView(rootView: rootView.environment(\.colorScheme, .light))
        let window = NSWindow(
          contentRect: NSRect(x: 0, y: 0, width: width, height: 3200),
          styleMask: [.borderless],
          backing: .buffered,
          defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = host
        defer { window.contentView = nil }

        host.layoutSubtreeIfNeeded()
        let firstPassHeight = host.fittingSize.height
        for _ in 0..<settlePasses {
          RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.012))
          host.layoutSubtreeIfNeeded()
        }
        let settledHeight = host.fittingSize.height
        host.frame = NSRect(x: 0, y: 0, width: width, height: max(1, ceil(settledHeight)))
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        host.layoutSubtreeIfNeeded()

        let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)
        if let bitmap {
          host.cacheDisplay(in: host.bounds, to: bitmap)
        }
        return Snapshot(
          firstPassHeight: firstPassHeight,
          settledHeight: settledHeight,
          bitmapData: bitmap?.tiffRepresentation
        )
      #elseif os(iOS)
        let controller = UIHostingController(rootView: rootView.environment(\.colorScheme, .light))
        controller.overrideUserInterfaceStyle = .light
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 3200))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
          window.isHidden = true
          window.rootViewController = nil
        }

        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let target = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        let firstPassHeight = controller.sizeThatFits(in: target).height
        for _ in 0..<settlePasses {
          RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.012))
          controller.view.setNeedsLayout()
          controller.view.layoutIfNeeded()
        }
        let settledHeight = controller.sizeThatFits(in: target).height
        let renderSize = CGSize(width: width, height: max(1, ceil(settledHeight)))
        window.frame = CGRect(origin: .zero, size: renderSize)
        controller.view.frame = CGRect(origin: .zero, size: renderSize)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        controller.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
        let png = renderer.pngData { _ in
          controller.view.drawHierarchy(in: CGRect(origin: .zero, size: renderSize), afterScreenUpdates: true)
        }
        return Snapshot(
          firstPassHeight: firstPassHeight,
          settledHeight: settledHeight,
          bitmapData: png
        )
      #endif
    }

    @MainActor
    private final class MountedHarness<V: View> {
      #if os(macOS)
        private let host: NSHostingView<AnyView>
        private let window: NSWindow
      #elseif os(iOS)
        private let controller: UIHostingController<AnyView>
        private let window: UIWindow
      #endif
      private let width: CGFloat

      init(rootView: V, width: CGFloat) {
        self.width = width
        #if os(macOS)
          let host = NSHostingView(rootView: AnyView(rootView.environment(\.colorScheme, .light)))
          let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 3200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
          )
          window.appearance = NSAppearance(named: .aqua)
          window.contentView = host
          self.host = host
          self.window = window
        #elseif os(iOS)
          let controller = UIHostingController(rootView: AnyView(rootView.environment(\.colorScheme, .light)))
          controller.overrideUserInterfaceStyle = .light
          let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 3200))
          window.overrideUserInterfaceStyle = .light
          window.rootViewController = controller
          window.makeKeyAndVisible()
          self.controller = controller
          self.window = window
        #endif
      }

      func settleAndMeasureHeight(passes: Int = 4) -> CGFloat {
        #if os(macOS)
          self.host.layoutSubtreeIfNeeded()
          for _ in 0..<passes {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.012))
            self.host.layoutSubtreeIfNeeded()
          }
          return self.host.fittingSize.height
        #elseif os(iOS)
          self.controller.view.setNeedsLayout()
          self.controller.view.layoutIfNeeded()
          for _ in 0..<passes {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.012))
            self.controller.view.setNeedsLayout()
            self.controller.view.layoutIfNeeded()
          }
          let target = CGSize(width: self.width, height: UIView.layoutFittingCompressedSize.height)
          return self.controller.sizeThatFits(in: target).height
        #endif
      }

      func tearDown() {
        #if os(macOS)
          self.window.contentView = nil
        #elseif os(iOS)
          self.window.isHidden = true
          self.window.rootViewController = nil
        #endif
      }
    }
  }
#endif
