#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import MarkdownUI

final class LightweightBlocksTests: XCTestCase {
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
      "- Item \($0): rows near the screen are placed once per layout, with `code`, *emphasis*, ~~strike~~, [link](https://example.com) and **bold**."
    }.joined(separator: "\n")
    let table15x3 = "| Part | Before | After |\n| :--- | ---: | :---: |\n"
      + (1...14).map { "| Layout part \($0) with `code` | \($0 * 3).2 ms | **\($0).1 ms** |" }
      .joined(separator: "\n")
    let longChunkedParagraph = (1...40).map {
      "Line \($0) with **bold** and `code` across soft breaks"
    }.joined(separator: "\n")

    return [
      ("single_short_paragraph", "Thanks, that's done: the build is on the phone."),
      ("bullets_16_tight", bullets16),
      ("table_15x3_adaptive", table15x3),
      (
        "mixed_reply_with_breaks_and_nested_lists",
        """
        ## Summary

        First line with trailing soft break
          indented continuation after soft break<br>  and after HTML br, plus *styled<br>* kept space.

        - Outer disc 1
          - Nested circle 1a
            - Nested square 1a-i
          1. Nested ordered 1
          2. Nested ordered 2
        - [x] Done task
        - [ ] Open task

        > Quoted note with `inline code` and **strong *nested* emphasis**.

        \(table15x3)
        """
      ),
      ("chunked_40_line_paragraph", longChunkedParagraph),
    ]
  }

  @MainActor
  func testLightweightBlocksMatchSettledHeightsAndRenderedPixelsAcrossCorpus() {
    for width in [CGFloat(300), CGFloat(400)] {
      for sample in self.corpus {
        let baseline = self.render(
          sample.markdown,
          width: width,
          lightweight: false
        )
        let candidate = self.render(
          sample.markdown,
          width: width,
          lightweight: true
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
        XCTAssertNotNil(baseline.tiffData)
        XCTAssertEqual(
          candidate.tiffData,
          baseline.tiffData,
          "Pixel mismatch for \(sample.name) width=\(width)"
        )
      }
    }
  }

  @MainActor
  func testCustomParagraphBlockStyleOverrideDisablesFastParagraphPathCleanly() {
    let markdown = "Custom paragraph override with **bold** and `code`."
    let theme = self.makeTheme(lightweight: true)
      .paragraph { configuration in
        configuration.label
          .padding(6)
          .fixedSize(horizontal: false, vertical: true)
      }

    let baseline = self.runHost(
      Markdown(markdown)
        .markdownTheme(theme)
        .markdownBlockMargins(self.chatMargins)
        .frame(width: 320, alignment: .leading),
      width: 320
    )
    let candidate = self.runHost(
      Markdown(markdown)
        .markdownTheme(theme)
        .markdownBlockMargins(self.chatMargins)
        .markdownLightweightBlocks()
        .frame(width: 320, alignment: .leading),
      width: 320
    )

    XCTAssertEqual(candidate.settledHeight, baseline.settledHeight, accuracy: 0.5)
    XCTAssertEqual(candidate.tiffData, baseline.tiffData)
  }

  private struct Snapshot {
    let firstPassHeight: CGFloat
    let settledHeight: CGFloat
    let tiffData: Data?
  }

  @MainActor
  private func render(_ markdown: String, width: CGFloat, lightweight: Bool) -> Snapshot {
    let view = Markdown(markdown)
      .markdownTheme(self.makeTheme(lightweight: lightweight))
      .markdownBlockMargins(self.chatMargins)
      .markdownLightweightListMarkers(lightweight)
      .markdownLightweightBlocks(lightweight)
      .markdownSoftBreakMode(.lineBreak)
      .frame(width: width, alignment: .leading)
    return self.runHost(view, width: width)
  }

  private func makeTheme(lightweight: Bool) -> Theme {
    let borderColor = Color.primary.opacity(0.18)
    let base = Theme.basic
      .text {
        FontSize(14.5)
        ForegroundColor(.primary)
      }
      .strong { FontWeight(.semibold) }
      .link {
        ForegroundColor(.blue)
        UnderlineStyle(.single)
      }
      .code {
        FontFamilyVariant(.monospaced)
        FontSize(.em(0.88))
        BackgroundColor(Color.primary.opacity(0.08))
      }
      .heading2 { configuration in
        configuration.label
          .markdownTextStyle {
            FontWeight(.semibold)
            FontSize(.em(1.1))
          }
          .relativeLineSpacing(.em(0.15))
      }
      .blockquote { configuration in
        configuration.label
          .markdownTextStyle { ForegroundColor(.secondary) }
          .padding(.leading, 14)
      }
      .tableCell { configuration in
        let alignment: Alignment = configuration.alignment == .leading ? .topLeading
          : configuration.alignment == .trailing ? .topTrailing : .top
        configuration.label
          .markdownTextStyle {
            if configuration.row == 0 { FontWeight(.semibold) }
          }
          .multilineTextAlignment(configuration.alignment)
          .fixedSize(horizontal: false, vertical: true)
          .relativeLineSpacing(.em(0.2))
          .padding(.vertical, 7)
          .padding(.horizontal, 10)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
      }
      .table { configuration in
        LightweightTableHarness(
          configuration: configuration,
          borderColor: borderColor,
          lightweight: lightweight
        )
      }

    if lightweight {
      return base.paragraph(lineSpacing: .em(0.2))
    } else {
      return base.paragraph { configuration in
        configuration.label
          .fixedSize(horizontal: false, vertical: true)
          .relativeLineSpacing(.em(0.2))
      }
    }
  }

  @MainActor
  private func runHost<V: View>(_ rootView: V, width: CGFloat) -> Snapshot {
    let host = NSHostingView(rootView: rootView)
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: width, height: 2400),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.appearance = NSAppearance(named: .aqua)
    window.contentView = host
    defer { window.contentView = nil }

    host.layoutSubtreeIfNeeded()
    let firstPassHeight = host.fittingSize.height
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
    return Snapshot(
      firstPassHeight: firstPassHeight,
      settledHeight: settledHeight,
      tiffData: bitmap?.tiffRepresentation
    )
  }
}

private final class LightweightViewportProbe {
  var width: CGFloat = 0
}

private struct LightweightViewportCapture: Layout {
  let probe: LightweightViewportProbe

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
    if let width = proposal.width, width.isFinite, width > 0 {
      self.probe.width = width
    }
    return subviews.first?.sizeThatFits(proposal) ?? .zero
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void
  ) {
    if bounds.width.isFinite, bounds.width > 0 {
      self.probe.width = bounds.width
    }
    subviews.first?.place(
      at: bounds.origin,
      anchor: .topLeading,
      proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
    )
  }
}

private struct LightweightTableHarness: View {
  let configuration: BlockConfiguration
  let borderColor: Color
  let lightweight: Bool
  @State private var probe = LightweightViewportProbe()

  var body: some View {
    LightweightViewportCapture(probe: self.probe) {
      ScrollView(.horizontal) {
        configuration.label
          .markdownTableLayout(
            .adaptive(
              availableWidth: { self.probe.width * 1.5 },
              minimumColumnWidth: 80,
              maximumColumnWidth: 400,
              overflow: .minimum
            )
          )
          .markdownTableCellStyle(
            self.lightweight
              ? MarkdownTableCellStyle(
                headerFontWeight: .semibold,
                lineSpacing: .em(0.2),
                padding: EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)
              )
              : nil
          )
          .markdownTableBorderStyle(.init(color: self.borderColor))
          .markdownTableBackgroundStyle(
            .alternatingRows(
              Color.clear,
              Color.primary.opacity(0.035),
              header: Color.primary.opacity(0.06)
            )
          )
      }
    }
  }
}
#endif
