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
  func testMinimumOverflowCombinesWrappingWithLimitedScrolling() {
    let sample = Fixture(source: """
      | One | Two | Three | Four |
      | --- | --- | --- | --- |
      | A sufficiently long value | A sufficiently long value | A sufficiently long value | A sufficiently long value |
      """, width: 280, overflow: .minimum)
    withHost(sample) { recorder in
      for column in 0..<4 {
        XCTAssertEqual(recorder.cells["1:\(column)"]!.width, 96, accuracy: 0.5)
      }
      XCTAssertLessThanOrEqual(recorder.cells["1:3"]!.maxX, 390)
      XCTAssertGreaterThan(recorder.cells["1:0"]!.height, recorder.cells["0:0"]!.height)
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
  func testLayoutDrivenAdaptiveWidthMatchesStaticAdaptiveFramesAndPixelsOnFirstPass() {
    let sources: [(name: String, text: String, overflow: TableLayoutStyle.Overflow)] = [
      (
        "compact_15x3",
        "| Part | Before | After |\n|---|---|---|\n"
          + (1...14).map { "| Layout part \($0) | \($0 * 3).2 ms | \($0).1 ms |" }.joined(separator: "\n"),
        .minimum
      ),
      (
        "wrapping_prose",
        """
        | Description | Count | Notes |
        | :--- | ---: | :--- |
        | A longer explanation that wraps across several lines when fitted to phone width. | 42 | Keep numeric column compact while prose wraps. |
        | Short | 123 | Done |
        """,
        .minimum
      ),
      (
        "wide_scroll",
        """
        | Col 1 | Col 2 | Col 3 | Col 4 | Col 5 |
        | --- | --- | --- | --- | --- |
        | Longer first cell | Longer second cell | Longer third cell | Longer fourth cell | Longer fifth cell |
        """,
        .minimum
      ),
    ]

    for width in [CGFloat(280), CGFloat(400)] {
      for sample in sources {
        let baseline = self.renderComparison(
          source: sample.text,
          width: width,
          overflow: sample.overflow,
          dynamicProvider: false
        )
        let candidate = self.renderComparison(
          source: sample.text,
          width: width,
          overflow: sample.overflow,
          dynamicProvider: true
        )

        XCTAssertEqual(
          candidate.firstPassHeight,
          baseline.settledHeight,
          accuracy: 0.5,
          "First-pass height mismatch for \(sample.name) width=\(width)"
        )
        XCTAssertEqual(
          candidate.settledHeight,
          baseline.settledHeight,
          accuracy: 0.5,
          "Settled height mismatch for \(sample.name) width=\(width)"
        )
        XCTAssertGreaterThan(candidate.measuredContentWidth, 0)
        XCTAssertEqual(candidate.cells.count, baseline.cells.count)
        for (key, expected) in baseline.cells {
          guard let actual = candidate.cells[key] else {
            XCTFail("Missing cell \(key)")
            continue
          }
          XCTAssertEqual(actual.minX, expected.minX, accuracy: 0.5, "\(sample.name) \(key) minX")
          XCTAssertEqual(actual.minY, expected.minY, accuracy: 0.5, "\(sample.name) \(key) minY")
          XCTAssertEqual(actual.width, expected.width, accuracy: 0.5, "\(sample.name) \(key) width")
          XCTAssertEqual(actual.height, expected.height, accuracy: 0.5, "\(sample.name) \(key) height")
        }
        XCTAssertEqual(
          candidate.tiffData,
          baseline.tiffData,
          "Pixel mismatch for \(sample.name) width=\(width)"
        )
      }
    }
  }

  private struct ComparisonSnapshot {
    let firstPassHeight: CGFloat
    let settledHeight: CGFloat
    let measuredContentWidth: CGFloat
    let cells: [String: CGRect]
    let tiffData: Data?
  }

  @MainActor
  private func renderComparison(
    source: String,
    width: CGFloat,
    overflow: TableLayoutStyle.Overflow,
    dynamicProvider: Bool
  ) -> ComparisonSnapshot {
    let recorder = Recorder()
    let viewport = ViewportProbe()
    let view = Markdown(source)
      .markdownTextStyle { FontSize(14.5) }
      .markdownBlockStyle(\.table) { configuration in
        if dynamicProvider {
          ProposalCaptureLayout(viewport: viewport) {
            ScrollView(.horizontal) {
              configuration.label
                .markdownTableLayout(
                  .adaptive(
                    availableWidth: { viewport.proposedWidth * 1.5 },
                    minimumColumnWidth: 80,
                    maximumColumnWidth: 400,
                    overflow: overflow,
                    onMeasureWidth: { viewport.measuredContentWidth = $0 }
                  )
                )
                .markdownTableBorderStyle(.init(color: .gray))
                .coordinateSpace(name: "table")
            }
          }
        } else {
          ScrollView(.horizontal) {
            configuration.label
              .markdownTableLayout(
                .adaptive(
                  availableWidth: width * 1.5,
                  minimumColumnWidth: 80,
                  maximumColumnWidth: 400,
                  overflow: overflow
                )
              )
              .markdownTableBorderStyle(.init(color: .gray))
              .coordinateSpace(name: "table")
          }
        }
      }
      .markdownBlockStyle(\.tableCell) { configuration in
        let key = "\(configuration.row):\(configuration.column)"
        let alignment: Alignment = configuration.alignment == .leading ? .topLeading
          : configuration.alignment == .trailing ? .topTrailing : .top
        configuration.label
          .multilineTextAlignment(configuration.alignment)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
          .background(GeometryReader { proxy in
            Color.clear.preference(key: CellFrames.self, value: [key: proxy.frame(in: .named("table"))])
          })
      }
      .frame(width: width)
      .onPreferenceChange(CellFrames.self) { recorder.cells = $0 }

    let host = NSHostingView(rootView: view)
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: width, height: 1200),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.appearance = NSAppearance(named: .aqua)
    window.contentView = host
    defer { window.contentView = nil }

    host.layoutSubtreeIfNeeded()
    let firstPassHeight = host.fittingSize.height
    for _ in 0..<6 {
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
    return ComparisonSnapshot(
      firstPassHeight: firstPassHeight,
      settledHeight: settledHeight,
      measuredContentWidth: dynamicProvider ? viewport.measuredContentWidth : width,
      cells: recorder.cells,
      tiffData: bitmap?.tiffRepresentation
    )
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
  var overflow: TableLayoutStyle.Overflow = .natural
  let recorder = Recorder()

  var body: some View {
    Markdown(source)
      .markdownTextStyle { FontSize(15) }
      .markdownBlockStyle(\.table) { configuration in
        ScrollView(.horizontal) {
          configuration.label
            .markdownTableLayout(.adaptive(availableWidth: width, minimumColumnWidth: 96, maximumColumnWidth: 320, overflow: overflow))
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

private final class ViewportProbe {
  var proposedWidth: CGFloat = 0
  var measuredContentWidth: CGFloat = 0
}

private struct ProposalCaptureLayout: Layout {
  let viewport: ViewportProbe

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
    if let width = proposal.width, width.isFinite, width > 0 {
      self.viewport.proposedWidth = width
    }
    guard let first = subviews.first else { return .zero }
    return first.sizeThatFits(proposal)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void
  ) {
    if bounds.width.isFinite, bounds.width > 0 {
      self.viewport.proposedWidth = bounds.width
    }
    subviews.first?.place(
      at: bounds.origin,
      anchor: .topLeading,
      proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
    )
  }
}
#endif
