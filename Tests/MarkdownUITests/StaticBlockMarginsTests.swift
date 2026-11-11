#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import MarkdownUI

final class StaticBlockMarginsTests: XCTestCase {
  private let chatMargins = MarkdownBlockMargins(
    heading: BlockMargin(top: 8, bottom: 4),
    paragraph: BlockMargin(top: 0, bottom: 8),
    blockquote: BlockMargin(top: 4, bottom: 8),
    codeBlock: BlockMargin(top: 8, bottom: 8),
    list: BlockMargin(top: 4, bottom: 8),
    listItem: BlockMargin(top: 2, bottom: 2),
    table: BlockMargin(top: 8, bottom: 8),
    thematicBreak: BlockMargin(top: 12, bottom: 12)
  )

  private var corpus: [(name: String, markdown: String)] {
    let numbered12 = (1...12).map { "\($0). Numbered item \($0) with **bold** and `code`." }
      .joined(separator: "\n")
    return [
      (
        "paragraphs_and_headings",
        """
        # Heading one

        First paragraph with **bold**, *emphasis*, `inline code`, and [a link](https://example.com)
        continuing across a soft break.

        ## Heading two

        ### Heading three

        #### Heading four

        ##### Heading five

        ###### Heading six

        Second paragraph after six headings.

        Third paragraph at the end.
        """
      ),
      (
        "tight_and_loose_lists",
        """
        - Tight one
        - Tight two
        - Tight three

        Paragraph between lists.

        - Loose one

        - Loose two with a second line

        - Loose three
        """
      ),
      (
        "nested_lists_mixed_tightness",
        """
        - Outer tight one
          - Inner tight A
            - Leaf 1
            - Leaf 2
          - Inner tight B
        - Outer tight two
          1. Nested ordered one
          2. Nested ordered two

        1. Outer loose ordered one

           - Nested loose bullet A

           - Nested loose bullet B

        2. Outer loose ordered two
        """
      ),
      (
        "numbered_lists_1_to_12",
        """
        1. Single numbered item

        1. One
        2. Two
        3. Three
        4. Four
        5. Five
        6. Six
        7. Seven
        8. Eight
        9. Nine

        \(numbered12)
        """
      ),
      (
        "task_lists",
        """
        - [x] Completed task item
        - [ ] Open task item with wrapping prose that spans more than one line at 320 points
          - [x] Nested completed task
          - [ ] Nested open task

        - [x] Loose completed task

        - [ ] Loose open task
        """
      ),
      (
        "containers_with_larger_descendant_margins",
        """
        > Quoted intro
        >
        > - Quoted list item one
        > - Quoted list item two
        >
        > ```swift
        > let x = 42
        > ```
        >
        > ---
        >
        > Quoted outro

        After quote with a thematic break descendant (must use max bottom margin 12).

        - Tight item before code item
        - Tight item containing code:

          ```swift
          print("descendant code margin 8 exceeds listItem margin 2")
          ```
        - Tight item after code item
        - Tight item containing rule:

          ---

        - Tight item after rule item
        """
      ),
      (
        "tables_code_rules_html",
        """
        Intro paragraph.

        | Component | Baseline | Target |
        | :--- | :---: | ---: |
        | BlockSequence | Two passes | One pass |
        | Lists | Preference | Direct |

        ---

        ```swift
        func sum(_ values: [Int]) -> Int {
          values.reduce(0, +)
        }
        ```

        <div>Raw HTML block treated as paragraph</div>

        Closing paragraph.
        """
      ),
    ]
  }

  @MainActor
  func testStaticMarginsMatchDynamicHeightsFramesAndPixelsAcrossCorpus() {
    for sample in self.corpus {
      let dynamicResult = self.measure(
        markdown: sample.markdown,
        width: 340,
        staticMargins: nil,
        includeThemeMargins: true,
        settlePasses: 10
      )
      let staticWithoutPreference = self.measure(
        markdown: sample.markdown,
        width: 340,
        staticMargins: self.chatMargins,
        includeThemeMargins: false,
        settlePasses: 1
      )
      let staticWithPreference = self.measure(
        markdown: sample.markdown,
        width: 340,
        staticMargins: self.chatMargins,
        includeThemeMargins: true,
        settlePasses: 4
      )

      XCTAssertEqual(
        staticWithoutPreference.firstPassHeight,
        dynamicResult.settledHeight,
        accuracy: 0.5,
        "First-pass height mismatch in \(sample.name)"
      )
      XCTAssertEqual(
        staticWithoutPreference.settledHeight,
        dynamicResult.settledHeight,
        accuracy: 0.5,
        "Settled height mismatch in \(sample.name)"
      )
      XCTAssertEqual(
        staticWithPreference.settledHeight,
        dynamicResult.settledHeight,
        accuracy: 0.5,
        "Coexisting preference height mismatch in \(sample.name)"
      )

      XCTAssertEqual(
        Set(staticWithoutPreference.frames.keys),
        Set(dynamicResult.frames.keys),
        "Recorded block paths differed in \(sample.name)"
      )
      for (path, expected) in dynamicResult.frames {
        guard let actual = staticWithoutPreference.frames[path] else { continue }
        XCTAssertEqual(actual.minX, expected.minX, accuracy: 0.5, "\(sample.name) path \(path) minX")
        XCTAssertEqual(actual.minY, expected.minY, accuracy: 0.5, "\(sample.name) path \(path) minY")
        XCTAssertEqual(actual.width, expected.width, accuracy: 0.5, "\(sample.name) path \(path) width")
        XCTAssertEqual(actual.height, expected.height, accuracy: 0.5, "\(sample.name) path \(path) height")
      }

      XCTAssertEqual(
        staticWithoutPreference.tiffData,
        dynamicResult.tiffData,
        "Rendered bitmap differed in \(sample.name)"
      )
    }
  }

  @MainActor
  func testUnspecifiedStaticMarginsMatchSystemDefaultAndTightZeroFallback() {
    let markdown = """
      First paragraph with unspecified margins.

      Second paragraph separated by SwiftUI default padding.

      - Tight unspecified item one
      - Tight unspecified item two

      - Loose unspecified item one

      - Loose unspecified item two
      """
    let schedule = MarkdownBlockMargins()
    let dynamicResult = self.measureCustomUnspecified(markdown: markdown, staticMargins: nil, settlePasses: 8)
    let staticResult = self.measureCustomUnspecified(markdown: markdown, staticMargins: schedule, settlePasses: 1)
    XCTAssertEqual(staticResult.firstPassHeight, dynamicResult.settledHeight, accuracy: 0.5)
    XCTAssertEqual(staticResult.settledHeight, dynamicResult.settledHeight, accuracy: 0.5)
    XCTAssertEqual(staticResult.tiffData, dynamicResult.tiffData)
  }

  @MainActor
  func testPerHeadingLevelAndImageMarginsMatchDynamicPreferences() {
    let markdown = """
      # H1

      ## H2

      ### H3

      ![Alt](https://example.com/pic.png)

      Text with ![inline](https://example.com/pic.png) image.

      Trailing paragraph.
      """
    let schedule = MarkdownBlockMargins(
      heading1: BlockMargin(top: 20, bottom: 10),
      heading2: BlockMargin(top: 16, bottom: 8),
      heading3: BlockMargin(top: 12, bottom: 6),
      paragraph: BlockMargin(top: 0, bottom: 8),
      image: BlockMargin(top: 14, bottom: 18)
    )
    let dynamicResult = self.measureImageAndHeadingLevels(
      markdown: markdown,
      staticMargins: nil,
      includeThemeMargins: true,
      settlePasses: 8
    )
    let staticResult = self.measureImageAndHeadingLevels(
      markdown: markdown,
      staticMargins: schedule,
      includeThemeMargins: false,
      settlePasses: 1
    )
    XCTAssertEqual(staticResult.firstPassHeight, dynamicResult.settledHeight, accuracy: 0.5)
    XCTAssertEqual(staticResult.settledHeight, dynamicResult.settledHeight, accuracy: 0.5)
  }

  private struct LayoutMeasurement {
    let firstPassHeight: CGFloat
    let settledHeight: CGFloat
    let frames: [String: CGRect]
    let tiffData: Data?
  }

  @MainActor
  private func measure(
    markdown: String,
    width: CGFloat,
    staticMargins: MarkdownBlockMargins?,
    includeThemeMargins: Bool,
    settlePasses: Int
  ) -> LayoutMeasurement {
    let recorder = FrameRecorder()
    let theme = self.makeChatTheme(includeMargins: includeThemeMargins)
    let view = Markdown(markdown)
      .markdownTheme(theme)
      .markdownSoftBreakMode(.lineBreak)
      .markdownInlineImageFlow()
      .markdownBlockMargins(staticMargins)
      .frame(width: width, alignment: .leading)
      .coordinateSpace(name: "doc")
      .onPreferenceChange(BlockFramesKey.self) { recorder.frames = $0 }
    return self.runHost(view, width: width, recorder: recorder, settlePasses: settlePasses)
  }

  @MainActor
  private func measureCustomUnspecified(
    markdown: String,
    staticMargins: MarkdownBlockMargins?,
    settlePasses: Int
  ) -> LayoutMeasurement {
    let recorder = FrameRecorder()
    let emptyTheme = Theme()
      .paragraph { $0.label.fixedSize(horizontal: false, vertical: true) }
    let view = Markdown(markdown)
      .markdownTheme(emptyTheme)
      .markdownBlockMargins(staticMargins)
      .frame(width: 300, alignment: .leading)
    return self.runHost(view, width: 300, recorder: recorder, settlePasses: settlePasses)
  }

  @MainActor
  private func measureImageAndHeadingLevels(
    markdown: String,
    staticMargins: MarkdownBlockMargins?,
    includeThemeMargins: Bool,
    settlePasses: Int
  ) -> LayoutMeasurement {
    let recorder = FrameRecorder()
    var theme = Theme.basic
      .heading1 { cfg in
        let v = cfg.label.markdownTextStyle { FontSize(22); FontWeight(.bold) }
        if includeThemeMargins { v.markdownMargin(top: 20, bottom: 10) } else { v }
      }
      .heading2 { cfg in
        let v = cfg.label.markdownTextStyle { FontSize(18); FontWeight(.semibold) }
        if includeThemeMargins { v.markdownMargin(top: 16, bottom: 8) } else { v }
      }
      .heading3 { cfg in
        let v = cfg.label.markdownTextStyle { FontSize(16); FontWeight(.semibold) }
        if includeThemeMargins { v.markdownMargin(top: 12, bottom: 6) } else { v }
      }
      .paragraph { cfg in
        let v = cfg.label.fixedSize(horizontal: false, vertical: true)
        if includeThemeMargins { v.markdownMargin(top: 0, bottom: 8) } else { v }
      }
      .image { cfg in
        if includeThemeMargins { cfg.label.markdownMargin(top: 14, bottom: 18) } else { cfg.label }
      }
    _ = theme
    let view = Markdown(markdown)
      .markdownTheme(theme)
      .markdownImageProvider(FixedBoxImageProvider())
      .markdownInlineImageFlow()
      .markdownBlockMargins(staticMargins)
      .frame(width: 300, alignment: .leading)
    return self.runHost(view, width: 300, recorder: recorder, settlePasses: settlePasses)
  }

  private func makeChatTheme(includeMargins: Bool) -> Theme {
    func withMargin<V: View>(_ view: V, top: CGFloat, bottom: CGFloat) -> AnyView {
      if includeMargins {
        return AnyView(view.markdownMargin(top: top, bottom: bottom))
      }
      return AnyView(view)
    }

    func heading(_ configuration: BlockConfiguration) -> some View {
      let base = configuration.label
        .markdownTextStyle {
          FontWeight(.semibold)
          FontSize(.em(1.1))
        }
        .relativeLineSpacing(.em(0.15))
        .recordFrame(tag: "h")
      return withMargin(base, top: 8, bottom: 4)
    }

    return Theme.basic
      .text { FontSize(14.5) }
      .heading1 { heading($0) }
      .heading2 { heading($0) }
      .heading3 { heading($0) }
      .heading4 { heading($0) }
      .heading5 { heading($0) }
      .heading6 { heading($0) }
      .paragraph { configuration in
        let base = configuration.label
          .fixedSize(horizontal: false, vertical: true)
          .relativeLineSpacing(.em(0.2))
          .recordFrame(tag: "p")
        withMargin(base, top: 0, bottom: 8)
      }
      .list { configuration in
        withMargin(configuration.label.recordFrame(tag: "list"), top: 4, bottom: 8)
      }
      .listItem { configuration in
        withMargin(configuration.label.recordFrame(tag: "item"), top: 2, bottom: 2)
      }
      .blockquote { configuration in
        let base = configuration.label
          .padding(.leading, 14)
          .recordFrame(tag: "quote")
        withMargin(base, top: 4, bottom: 8)
      }
      .codeBlock { configuration in
        let base = configuration.label
          .padding(8)
          .recordFrame(tag: "code")
        withMargin(base, top: 8, bottom: 8)
      }
      .table { configuration in
        let base = configuration.label
          .markdownTableLayout(.adaptive(availableWidth: 340, minimumColumnWidth: 70, maximumColumnWidth: 260, overflow: .minimum))
          .recordFrame(tag: "table")
        withMargin(base, top: 8, bottom: 8)
      }
      .thematicBreak {
        let base = Rectangle().frame(height: 1).recordFrame(tag: "rule")
        withMargin(base, top: 12, bottom: 12)
      }
  }

  @MainActor
  private func runHost<V: View>(
    _ rootView: V,
    width: CGFloat,
    recorder: FrameRecorder,
    settlePasses: Int
  ) -> LayoutMeasurement {
    let host = NSHostingView(rootView: rootView)
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: width, height: 2000),
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
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.015))
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
    return LayoutMeasurement(
      firstPassHeight: firstPassHeight,
      settledHeight: settledHeight,
      frames: recorder.frames,
      tiffData: bitmap?.tiffRepresentation
    )
  }
}

private struct FixedBoxImageProvider: ImageProvider {
  func makeImage(url: URL?) -> some View {
    Rectangle().fill(Color.gray).frame(width: 48, height: 32)
  }
}

private final class FrameRecorder {
  var frames: [String: CGRect] = [:]
}

private struct BlockFrameModifier: ViewModifier {
  let tag: String
  @Environment(\.markdownBlockPath) private var path

  func body(content: Content) -> some View {
    let key = "\(self.tag):" + self.path.map(String.init).joined(separator: ".")
    content.background(
      GeometryReader { proxy in
        Color.clear.preference(key: BlockFramesKey.self, value: [key: proxy.frame(in: .named("doc"))])
      }
    )
  }
}

extension View {
  fileprivate func recordFrame(tag: String) -> some View {
    self.modifier(BlockFrameModifier(tag: tag))
  }
}

private struct BlockFramesKey: PreferenceKey {
  static let defaultValue: [String: CGRect] = [:]
  static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}
#endif
