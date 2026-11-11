#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import MarkdownUI

final class LightweightListMarkersTests: XCTestCase {
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
    let bullets16 = (1...16).map {
      "- Item \($0): rows near the screen are placed once per layout, with `code` and **bold**."
    }.joined(separator: "\n")
    let numbered9 = (1...9).map { "\($0). Single-digit item \($0) with *emphasis*." }
      .joined(separator: "\n")
    let numbered12 = (1...12).map { "\($0). Double-digit item \($0) with **bold** and `code`." }
      .joined(separator: "\n")
    let numbered102 = (98...102).map { "\($0). Triple-digit item \($0) starting at 98." }
      .joined(separator: "\n")

    return [
      ("bullets_16_tight", bullets16),
      (
        "nested_bullets_four_levels",
        """
        - Level 1 disc A
          - Level 2 circle A1
            - Level 3 square A1a
              - Level 4 square A1a-i
            - Level 3 square A1b
          - Level 2 circle A2
        - Level 1 disc B with wrapping prose that continues onto a second line at phone width
        """
      ),
      (
        "loose_and_mixed_lists",
        """
        - Loose bullet 1

        - Loose bullet 2
          1. Nested numbered 1
          2. Nested numbered 2

        1. Outer numbered 1
           - Nested bullet inside numbered 1
           - Nested bullet inside numbered 2
        2. Outer numbered 2
        """
      ),
      (
        "numbered_1_9_12_102",
        """
        1. Single numbered item alone.

        ---

        \(numbered9)

        ---

        \(numbered12)

        ---

        \(numbered102)
        """
      ),
      (
        "task_and_quoted_lists",
        """
        - [x] Completed task item
          - Nested bullet under task
        - [ ] Pending task item

        > Quoted intro
        >
        > - Quoted bullet one
        > - Quoted bullet two with `inline code`
        >   1. Quoted nested ordered one
        >   2. Quoted nested ordered two
        """
      ),
    ]
  }

  @MainActor
  func testLightweightListMarkersMatchHeightsFramesAndPixels() {
    for width in [CGFloat(300), CGFloat(400)] {
      for sample in self.corpus {
        let baseline = self.measure(
          sample.markdown,
          width: width,
          lightweightMarkers: false,
          staticMargins: false
        )
        let lightweightOnly = self.measure(
          sample.markdown,
          width: width,
          lightweightMarkers: true,
          staticMargins: false
        )
        let combined = self.measure(
          sample.markdown,
          width: width,
          lightweightMarkers: true,
          staticMargins: true
        )

        for (label, candidate) in [("lightweight", lightweightOnly), ("combined", combined)] {
          XCTAssertEqual(
            candidate.settledHeight,
            baseline.settledHeight,
            accuracy: 0.5,
            "Settled height mismatch (\(label)) for \(sample.name) at width=\(width)"
          )
          XCTAssertEqual(
            Set(candidate.frames.keys),
            Set(baseline.frames.keys),
            "Recorded block keys differ (\(label)) for \(sample.name) at width=\(width)"
          )
          for (key, expected) in baseline.frames {
            guard let actual = candidate.frames[key] else { continue }
            XCTAssertEqual(actual.minX, expected.minX, accuracy: 0.5, "\(label) minX \(sample.name) \(key)")
            XCTAssertEqual(actual.minY, expected.minY, accuracy: 0.5, "\(label) minY \(sample.name) \(key)")
            XCTAssertEqual(actual.width, expected.width, accuracy: 0.5, "\(label) width \(sample.name) \(key)")
            XCTAssertEqual(actual.height, expected.height, accuracy: 0.5, "\(label) height \(sample.name) \(key)")
          }
          XCTAssertNotNil(baseline.tiffData)
          XCTAssertEqual(
            candidate.tiffData,
            baseline.tiffData,
            "Rendered pixels differ (\(label)) for \(sample.name) at width=\(width)"
          )
        }
      }
    }
  }

  @MainActor
  func testCustomDashAndRomanMarkersMatchPixels() {
    let markdown = """
    - Dash item one
      - Dash item nested
    - Dash item two

    1. Roman I
    2. Roman II
    3. Roman III
    4. Roman IV
    5. Roman V
    6. Roman VI
    7. Roman VII
    8. Roman VIII
    """
    let customTheme = self.makeTheme(includeMargins: true)
      .bulletedListMarker(.dash)
      .numberedListMarker(.upperRoman)

    let baseline = self.runHost(
      Markdown(markdown)
        .markdownTheme(customTheme)
        .frame(width: 340, alignment: .leading),
      width: 340
    )
    let candidate = self.runHost(
      Markdown(markdown)
        .markdownTheme(customTheme)
        .markdownLightweightListMarkers()
        .frame(width: 340, alignment: .leading),
      width: 340
    )
    XCTAssertEqual(candidate.settledHeight, baseline.settledHeight, accuracy: 0.5)
    XCTAssertEqual(candidate.tiffData, baseline.tiffData)
  }

  private struct Measurement {
    let settledHeight: CGFloat
    let frames: [String: CGRect]
    let tiffData: Data?
  }

  @MainActor
  private func measure(
    _ markdown: String,
    width: CGFloat,
    lightweightMarkers: Bool,
    staticMargins: Bool
  ) -> Measurement {
    let recorder = ListFrameRecorder()
    let view = Markdown(markdown)
      .markdownTheme(self.makeTheme(includeMargins: !staticMargins))
      .markdownBlockMargins(staticMargins ? self.chatMargins : nil)
      .markdownLightweightListMarkers(lightweightMarkers)
      .markdownSoftBreakMode(.lineBreak)
      .frame(width: width, alignment: .leading)
      .coordinateSpace(name: "listDoc")
      .onPreferenceChange(ListBlockFramesKey.self) { recorder.frames = $0 }
    return self.runHost(view, width: width, recorder: recorder)
  }

  private func makeTheme(includeMargins: Bool) -> Theme {
    func withMargin<V: View>(_ view: V, top: CGFloat, bottom: CGFloat) -> AnyView {
      includeMargins ? AnyView(view.markdownMargin(top: top, bottom: bottom)) : AnyView(view)
    }

    return Theme.basic
      .text { FontSize(14.5) }
      .paragraph { configuration in
        let base = configuration.label
          .fixedSize(horizontal: false, vertical: true)
          .relativeLineSpacing(.em(0.2))
          .recordListFrame(tag: "p")
        withMargin(base, top: 0, bottom: 8)
      }
      .list { configuration in
        withMargin(configuration.label.recordListFrame(tag: "list"), top: 4, bottom: 8)
      }
      .listItem { configuration in
        withMargin(configuration.label.recordListFrame(tag: "item"), top: 2, bottom: 2)
      }
      .blockquote { configuration in
        withMargin(configuration.label.padding(.leading, 14).recordListFrame(tag: "quote"), top: 4, bottom: 8)
      }
      .thematicBreak {
        withMargin(Rectangle().frame(height: 1).recordListFrame(tag: "rule"), top: 12, bottom: 12)
      }
  }

  @MainActor
  private func runHost<V: View>(
    _ rootView: V,
    width: CGFloat,
    recorder: ListFrameRecorder = ListFrameRecorder()
  ) -> Measurement {
    let host = NSHostingView(rootView: rootView)
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: width, height: 2200),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.appearance = NSAppearance(named: .aqua)
    window.contentView = host
    defer { window.contentView = nil }

    for _ in 0..<8 {
      host.layoutSubtreeIfNeeded()
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.015))
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
    return Measurement(
      settledHeight: settledHeight,
      frames: recorder.frames,
      tiffData: bitmap?.tiffRepresentation
    )
  }
}

private final class ListFrameRecorder {
  var frames: [String: CGRect] = [:]
}

private struct ListBlockFrameModifier: ViewModifier {
  let tag: String
  @Environment(\.markdownBlockPath) private var path

  func body(content: Content) -> some View {
    let key = "\(self.tag):" + self.path.map(String.init).joined(separator: ".")
    content.background(
      GeometryReader { proxy in
        Color.clear.preference(
          key: ListBlockFramesKey.self,
          value: [key: proxy.frame(in: .named("listDoc"))]
        )
      }
    )
  }
}

extension View {
  fileprivate func recordListFrame(tag: String) -> some View {
    self.modifier(ListBlockFrameModifier(tag: tag))
  }
}

private struct ListBlockFramesKey: PreferenceKey {
  static let defaultValue: [String: CGRect] = [:]
  static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}
#endif
