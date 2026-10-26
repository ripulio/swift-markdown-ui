#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import MarkdownUI

final class AdaptiveTableTests: XCTestCase {
  @MainActor
  func testDescriptionWrapsWhileShortNumericColumnStaysCompact() {
    let sample = Fixture(source: """
      | Description | Count |
      | :--- | ---: |
      | A long description with enough words to wrap naturally on a narrow phone screen. | 42 |
      | Short | 123 |
      """, width: 300)
    withHost(sample) { recorder in
      let description = recorder.cells["1:0"]!
      let count = recorder.cells["1:1"]!
      XCTAssertGreaterThan(description.width, count.width * 2)
      XCTAssertLessThanOrEqual(count.maxX, 300.5)
      XCTAssertEqual(description.minY, count.minY, accuracy: 0.5)
      XCTAssertEqual(description.height, count.height, accuracy: 0.5)
      XCTAssertGreaterThan(description.height, recorder.cells["2:0"]!.height)
      XCTAssertEqual(recorder.alignments["1:1"], .trailing)
    }
  }

  @MainActor
  func testWideTableRetainsReadableColumnsAndScrolls() {
    let sample = Fixture(source: """
      | One | Two | Three | Four |
      | --- | --- | --- | --- |
      | A sufficiently long value | A sufficiently long value | A sufficiently long value | A sufficiently long value |
      """, width: 280)
    withHost(sample) { recorder in
      XCTAssertGreaterThan(recorder.cells["1:3"]!.maxX, 280)
      for column in 0..<4 {
        let width = recorder.cells["1:\(column)"]!.width
        XCTAssertGreaterThanOrEqual(width, 96)
        XCTAssertLessThanOrEqual(width, 320)
      }
    }
  }

  @MainActor
  func testColumnAlignmentAndTopAlignmentSurviveWrapping() {
    let sample = Fixture(source: """
      | Left | Middle | Right |
      | :--- | :---: | ---: |
      | L | C | R |
      | A deliberately longer cell with several words to wrap | Middle column heading | Right column heading |
      """, width: 380)
    withHost(sample) { recorder in
      let left = recorder.cells["1:0"]!
      let center = recorder.cells["1:1"]!
      let right = recorder.cells["1:2"]!
      XCTAssertEqual(recorder.text["1:0"]!.minX, left.minX + 10, accuracy: 0.5)
      XCTAssertEqual(recorder.text["1:1"]!.midX, center.midX, accuracy: 0.5)
      XCTAssertEqual(recorder.text["1:2"]!.maxX, right.maxX - 10, accuracy: 0.5)
      XCTAssertEqual(recorder.text["2:0"]!.minY, recorder.text["2:1"]!.minY, accuracy: 0.5)
    }
  }

  @MainActor
  func testRightToLeftLayoutKeepsColumnOrder() {
    let sample = Fixture(source: "| First | Second |\n| --- | --- |\n| A | B |", width: 300,
                         direction: .rightToLeft)
    withHost(sample) { recorder in
      XCTAssertGreaterThan(recorder.cells["1:0"]!.minX, recorder.cells["1:1"]!.minX)
      XCTAssertGreaterThanOrEqual(recorder.cells["1:1"]!.minX, 0)
      XCTAssertLessThanOrEqual(recorder.cells["1:0"]!.maxX, 300.5)
    }
  }

  @MainActor
  func testHeaderOnlyAndEmptyCellsHaveFiniteBounds() {
    for source in ["| Name | Value |\n| --- | --- |", "| | |\n| --- | --- |\n| | |"] {
      withHost(Fixture(source: source, width: 240)) { recorder in
        XCTAssertGreaterThanOrEqual(recorder.cells.count, 2)
        for rect in recorder.cells.values {
          XCTAssertTrue(rect.width.isFinite && rect.height.isFinite)
          XCTAssertGreaterThan(rect.width, 0)
          XCTAssertGreaterThan(rect.height, 0)
        }
      }
    }
  }

  @MainActor
  private func withHost(_ fixture: Fixture, check: (Recorder) -> Void) {
    let host = NSHostingView(rootView: fixture)
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: fixture.width, height: 800),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host
    defer { window.contentView = nil }
    for _ in 0..<8 {
      host.layoutSubtreeIfNeeded()
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
    }
    check(fixture.recorder)
  }
}

private final class Recorder {
  var cells: [String: CGRect] = [:]
  var text: [String: CGRect] = [:]
  var alignments: [String: TextAlignment] = [:]
}

private struct Fixture: View {
  let source: String
  let width: CGFloat
  var direction: LayoutDirection = .leftToRight
  let recorder = Recorder()

  var body: some View {
    Markdown(source)
      .markdownTextStyle { FontSize(15) }
      .markdownBlockStyle(\.table) { configuration in
        ScrollView(.horizontal) {
          configuration.label
            .markdownTableLayout(.adaptive(availableWidth: width, minimumColumnWidth: 96, maximumColumnWidth: 320))
            .coordinateSpace(name: "table")
        }
      }
      .markdownBlockStyle(\.tableCell) { configuration in
        let key = "\(configuration.row):\(configuration.column)"
        let alignment: Alignment = configuration.alignment == .leading ? .topLeading
          : configuration.alignment == .trailing ? .topTrailing : .top
        configuration.label
          .multilineTextAlignment(configuration.alignment)
          .fixedSize(horizontal: false, vertical: true)
          .background(GeometryReader { proxy in
            Color.clear.preference(key: TextFrames.self, value: [key: proxy.frame(in: .named("table"))])
          })
          .padding(.horizontal, 10).padding(.vertical, 7)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
          .background(GeometryReader { proxy in
            Color.clear.preference(key: CellFrames.self, value: [key: proxy.frame(in: .named("table"))])
          })
          .onAppear { recorder.alignments[key] = configuration.alignment }
      }
      .frame(width: width)
      .environment(\.layoutDirection, direction)
      .onPreferenceChange(CellFrames.self) { recorder.cells = $0 }
      .onPreferenceChange(TextFrames.self) { recorder.text = $0 }
  }
}

private struct CellFrames: PreferenceKey {
  static let defaultValue: [String: CGRect] = [:]
  static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}

private struct TextFrames: PreferenceKey {
  static let defaultValue: [String: CGRect] = [:]
  static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}
#endif
