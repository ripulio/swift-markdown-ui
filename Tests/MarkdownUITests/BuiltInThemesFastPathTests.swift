#if os(macOS) || os(iOS)
  import SwiftUI
  import XCTest
  @testable import MarkdownUI

  #if os(macOS)
    import AppKit
  #elseif os(iOS)
    import UIKit
  #endif

  final class BuiltInThemesFastPathTests: XCTestCase {
    private var corpus: [(name: String, markdown: String)] {
      [
        (
          "headings_1_to_6_and_paragraphs",
          """
          # Heading 1 with `code` and **bold**

          First paragraph after level-1 heading, wrapping across multiple lines to verify exact relative line spacing and margins.

          ## Heading 2 with *italic*

          Paragraph two checks spacing after level-2 heading.

          ### Heading 3

          #### Heading 4

          ##### Heading 5

          ###### Heading 6 with [link](https://example.com)

          Final paragraph at the bottom of the heading sequence.
          """
        ),
        (
          "multi_paragraph_prose",
          """
          The sky above the port was the color of television, tuned to a dead channel.

          It was a bright cold day in April, and the clocks were striking thirteen.

          Use `git status` to list all **new or modified** files that haven't yet been *committed* or ~~discarded~~.
          """
        ),
        (
          "tight_and_loose_lists",
          """
          Intro before bullet list:

          - First tight bullet item with **bold**, `code`, and wrapping text across lines
          - Second tight bullet item with [link](https://example.com)
          - Third tight bullet item

          Nested and ordered lists:

          * Outer disc
            * Inner circle
              * Innermost square
          1. Ordered item one
          2. Ordered item two

          Loose bullet list:

          - Loose bullet A

          - Loose bullet B

          - [x] Completed task item
          - [ ] Unfinished task item
          """
        ),
        (
          "blockquotes_code_thematic_break_and_table",
          """
          Lead-in paragraph before blockquote.

          > Outside of a dog, a book is a person's best friend.
          >
          > > Nested quote with `inline code` and **strong text**.

          ```swift
          struct Renderer {
              func layout(width: Double) -> Double {
                  width * 1.5
              }
          }
          ```

          ---

          | Feature | Upstream 2.4.1 | Ripul 2.5 |
          | :--- | :---: | ---: |
          | Passes | Multi-pass | Single-pass |
          | Lists | `Label` + `PreferenceKey` | `BulletedListLayout` |
          """
        ),
      ]
    }

    @MainActor
    func testBuiltInBasicThemeMatchesLegacy241HeightsAndPixelsInSinglePass() {
      let legacyBasic = Self.makeLegacyBasicTheme()
      for width in [CGFloat(320), CGFloat(390)] {
        for sample in self.corpus {
          let expected = self.render(sample.markdown, theme: legacyBasic, width: width, settlePasses: 8)
          let actual = self.render(sample.markdown, theme: .basic, width: width, settlePasses: 8)

          XCTAssertEqual(
            actual.firstPassHeight,
            expected.settledHeight,
            accuracy: 0.5,
            "Theme.basic first-pass height mismatch on \(sample.name) width=\(width)"
          )
          XCTAssertEqual(
            actual.settledHeight,
            expected.settledHeight,
            accuracy: 0.5,
            "Theme.basic settled height mismatch on \(sample.name) width=\(width)"
          )
          XCTAssertNotNil(expected.bitmapData)
          XCTAssertEqual(
            actual.bitmapData,
            expected.bitmapData,
            "Theme.basic pixel mismatch on \(sample.name) width=\(width)"
          )
        }
      }
    }

    @MainActor
    func testBuiltInGitHubThemeMatchesLegacy241HeightsAndPixelsInSinglePass() {
      let legacyGitHub = Self.makeLegacyGitHubTheme()
      for width in [CGFloat(320), CGFloat(390)] {
        for sample in self.corpus {
          let expected = self.render(sample.markdown, theme: legacyGitHub, width: width, settlePasses: 8)
          let actual = self.render(sample.markdown, theme: .gitHub, width: width, settlePasses: 8)

          XCTAssertEqual(
            actual.firstPassHeight,
            expected.settledHeight,
            accuracy: 0.5,
            "Theme.gitHub first-pass height mismatch on \(sample.name) width=\(width)"
          )
          XCTAssertEqual(
            actual.settledHeight,
            expected.settledHeight,
            accuracy: 0.5,
            "Theme.gitHub settled height mismatch on \(sample.name) width=\(width)"
          )
          XCTAssertNotNil(expected.bitmapData)
          XCTAssertEqual(
            actual.bitmapData,
            expected.bitmapData,
            "Theme.gitHub pixel mismatch on \(sample.name) width=\(width)"
          )
        }
      }
    }

    @MainActor
    func testBuiltInDocCThemeMatchesLegacy241HeightsAndPixelsInSinglePass() {
      let legacyDocC = Self.makeLegacyDocCTheme()
      for width in [CGFloat(320), CGFloat(390)] {
        for sample in self.corpus {
          let expected = self.render(sample.markdown, theme: legacyDocC, width: width, settlePasses: 8)
          let actual = self.render(sample.markdown, theme: .docC, width: width, settlePasses: 8)

          XCTAssertEqual(
            actual.firstPassHeight,
            expected.settledHeight,
            accuracy: 0.5,
            "Theme.docC first-pass height mismatch on \(sample.name) width=\(width)"
          )
          XCTAssertEqual(
            actual.settledHeight,
            expected.settledHeight,
            accuracy: 0.5,
            "Theme.docC settled height mismatch on \(sample.name) width=\(width)"
          )
          XCTAssertNotNil(expected.bitmapData)
          XCTAssertEqual(
            actual.bitmapData,
            expected.bitmapData,
            "Theme.docC pixel mismatch on \(sample.name) width=\(width)"
          )
        }
      }
    }

    @MainActor
    func testCustomBlockStyleOverrideFallsBackCleanlyAndPreservesMargins() {
      let markdown = """
        # Title

        First paragraph with custom zero bottom margin.

        Second paragraph immediately below.

        > Quoted paragraph inside blockquote.

        Final paragraph.
        """

      let themes: [(String, Theme, Theme)] = [
        ("basic", .basic, Self.makeLegacyBasicTheme()),
        ("gitHub", .gitHub, Self.makeLegacyGitHubTheme()),
        ("docC", .docC, Self.makeLegacyDocCTheme()),
      ]

      for (name, fastTheme, legacyTheme) in themes {
        let actual = self.renderHostView(
          Markdown(markdown)
            .markdownBlockStyle(\.paragraph) { configuration in
              configuration.label.markdownMargin(bottom: .zero)
            }
            .markdownTheme(fastTheme)
            .frame(width: 340, alignment: .leading),
          width: 340,
          settlePasses: 8
        )
        let expected = self.renderHostView(
          Markdown(markdown)
            .markdownBlockStyle(\.paragraph) { configuration in
              configuration.label.markdownMargin(bottom: .zero)
            }
            .markdownTheme(legacyTheme)
            .frame(width: 340, alignment: .leading),
          width: 340,
          settlePasses: 8
        )

        XCTAssertEqual(
          actual.settledHeight,
          expected.settledHeight,
          accuracy: 0.5,
          "Custom paragraph override settled height mismatch on \(name)"
        )
        XCTAssertEqual(
          actual.bitmapData,
          expected.bitmapData,
          "Custom paragraph override pixel mismatch on \(name)"
        )
      }
    }

    @MainActor
    func testChatThemeSettlesInSinglePassAcrossAllChatConstructs() {
      for sample in self.corpus {
        let snapshot = self.render(sample.markdown, theme: .chat, width: 360, settlePasses: 6)
        XCTAssertGreaterThan(snapshot.settledHeight, 20)
        XCTAssertEqual(
          snapshot.firstPassHeight,
          snapshot.settledHeight,
          accuracy: 0.5,
          "Theme.chat should settle on pass 1 for \(sample.name)"
        )
      }
    }

    @MainActor
    func testChatThemeHonorsCustomTableCellOverride() {
      let tableMarkdown = """
        | Column A | Column B |
        | :--- | :--- |
        | Cell one | Cell two |
        """
      let defaultChat = self.renderHostView(
        Markdown(tableMarkdown)
          .markdownTheme(.chat)
          .frame(width: 340, alignment: .leading),
        width: 340,
        settlePasses: 4
      )
      let paddedOverride = self.renderHostView(
        Markdown(tableMarkdown)
          .markdownBlockStyle(\.tableCell) { configuration in
            configuration.label
              .padding(.vertical, 24)
              .padding(.horizontal, 12)
          }
          .markdownTheme(.chat)
          .frame(width: 340, alignment: .leading),
        width: 340,
        settlePasses: 4
      )

      XCTAssertGreaterThan(
        paddedOverride.settledHeight,
        defaultChat.settledHeight + 40,
        "Custom .markdownBlockStyle(\\.tableCell) on Theme.chat should take effect"
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
          contentRect: NSRect(x: 0, y: 0, width: width, height: 2600),
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
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 2600))
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

    // MARK: - Exact Upstream 2.4.1 Closure Reference Themes

    private static func makeLegacyBasicTheme() -> Theme {
      Theme()
        .code {
          FontFamilyVariant(.monospaced)
          FontSize(.em(0.94))
        }
        .heading1 { configuration in
          configuration.label
            .markdownMargin(top: .rem(1.5), bottom: .rem(1))
            .markdownTextStyle {
              FontWeight(.semibold)
              FontSize(.em(2))
            }
        }
        .heading2 { configuration in
          configuration.label
            .markdownMargin(top: .rem(1.5), bottom: .rem(1))
            .markdownTextStyle {
              FontWeight(.semibold)
              FontSize(.em(1.5))
            }
        }
        .heading3 { configuration in
          configuration.label
            .markdownMargin(top: .rem(1.5), bottom: .rem(1))
            .markdownTextStyle {
              FontWeight(.semibold)
              FontSize(.em(1.17))
            }
        }
        .heading4 { configuration in
          configuration.label
            .markdownMargin(top: .rem(1.5), bottom: .rem(1))
            .markdownTextStyle {
              FontWeight(.semibold)
              FontSize(.em(1))
            }
        }
        .heading5 { configuration in
          configuration.label
            .markdownMargin(top: .rem(1.5), bottom: .rem(1))
            .markdownTextStyle {
              FontWeight(.semibold)
              FontSize(.em(0.83))
            }
        }
        .heading6 { configuration in
          configuration.label
            .markdownMargin(top: .rem(1.5), bottom: .rem(1))
            .markdownTextStyle {
              FontWeight(.semibold)
              FontSize(.em(0.67))
            }
        }
        .paragraph { configuration in
          configuration.label
            .fixedSize(horizontal: false, vertical: true)
            .relativeLineSpacing(.em(0.15))
            .markdownMargin(top: .zero, bottom: .em(1))
        }
        .blockquote { configuration in
          configuration.label
            .markdownTextStyle {
              FontStyle(.italic)
            }
            .relativePadding(.leading, length: .em(2))
            .relativePadding(.trailing, length: .em(1))
        }
        .codeBlock { configuration in
          ScrollView(.horizontal) {
            configuration.label
              .fixedSize(horizontal: false, vertical: true)
              .relativeLineSpacing(.em(0.15))
              .relativePadding(.leading, length: .rem(1))
              .markdownTextStyle {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.94))
              }
          }
          .markdownMargin(top: .zero, bottom: .em(1))
        }
        .table { configuration in
          configuration.label
            .fixedSize(horizontal: false, vertical: true)
            .markdownMargin(top: .zero, bottom: .em(1))
        }
        .tableCell { configuration in
          configuration.label
            .markdownTextStyle {
              if configuration.row == 0 {
                FontWeight(.semibold)
              }
            }
            .fixedSize(horizontal: false, vertical: true)
            .relativeLineSpacing(.em(0.15))
            .relativePadding(.horizontal, length: .em(0.72))
            .relativePadding(.vertical, length: .em(0.35))
        }
        .thematicBreak {
          Divider().markdownMargin(top: .em(2), bottom: .em(2))
        }
    }

    private static func makeLegacyGitHubTheme() -> Theme {
      let text = Color(light: Color(rgba: 0x0606_06ff), dark: Color(rgba: 0xfbfb_fcff))
      let secondaryText = Color(light: Color(rgba: 0x6b6e_7bff), dark: Color(rgba: 0x9294_a0ff))
      let tertiaryText = Color(light: Color(rgba: 0x6b6e_7bff), dark: Color(rgba: 0x6d70_7dff))
      let background = Color(light: .white, dark: Color(rgba: 0x1819_1dff))
      let secondaryBackground = Color(light: Color(rgba: 0xf7f7_f9ff), dark: Color(rgba: 0x2526_2aff))
      let link = Color(light: Color(rgba: 0x2c65_cfff), dark: Color(rgba: 0x4c8e_f8ff))
      let border = Color(light: Color(rgba: 0xe4e4_e8ff), dark: Color(rgba: 0x4244_4eff))
      let divider = Color(light: Color(rgba: 0xd0d0_d3ff), dark: Color(rgba: 0x3334_38ff))
      let checkbox = Color(rgba: 0xb9b9_bbff)
      let checkboxBackground = Color(rgba: 0xeeee_efff)

      return Theme()
        .text {
          ForegroundColor(text)
          BackgroundColor(background)
          FontSize(16)
        }
        .code {
          FontFamilyVariant(.monospaced)
          FontSize(.em(0.85))
          BackgroundColor(secondaryBackground)
        }
        .strong {
          FontWeight(.semibold)
        }
        .link {
          ForegroundColor(link)
        }
        .heading1 { configuration in
          VStack(alignment: .leading, spacing: 0) {
            configuration.label
              .relativePadding(.bottom, length: .em(0.3))
              .relativeLineSpacing(.em(0.125))
              .markdownMargin(top: 24, bottom: 16)
              .markdownTextStyle {
                FontWeight(.semibold)
                FontSize(.em(2))
              }
            Divider().overlay(divider)
          }
        }
        .heading2 { configuration in
          VStack(alignment: .leading, spacing: 0) {
            configuration.label
              .relativePadding(.bottom, length: .em(0.3))
              .relativeLineSpacing(.em(0.125))
              .markdownMargin(top: 24, bottom: 16)
              .markdownTextStyle {
                FontWeight(.semibold)
                FontSize(.em(1.5))
              }
            Divider().overlay(divider)
          }
        }
        .heading3 { configuration in
          configuration.label
            .relativeLineSpacing(.em(0.125))
            .markdownMargin(top: 24, bottom: 16)
            .markdownTextStyle {
              FontWeight(.semibold)
              FontSize(.em(1.25))
            }
        }
        .heading4 { configuration in
          configuration.label
            .relativeLineSpacing(.em(0.125))
            .markdownMargin(top: 24, bottom: 16)
            .markdownTextStyle {
              FontWeight(.semibold)
            }
        }
        .heading5 { configuration in
          configuration.label
            .relativeLineSpacing(.em(0.125))
            .markdownMargin(top: 24, bottom: 16)
            .markdownTextStyle {
              FontWeight(.semibold)
              FontSize(.em(0.875))
            }
        }
        .heading6 { configuration in
          configuration.label
            .relativeLineSpacing(.em(0.125))
            .markdownMargin(top: 24, bottom: 16)
            .markdownTextStyle {
              FontWeight(.semibold)
              FontSize(.em(0.85))
              ForegroundColor(tertiaryText)
            }
        }
        .paragraph { configuration in
          configuration.label
            .fixedSize(horizontal: false, vertical: true)
            .relativeLineSpacing(.em(0.25))
            .markdownMargin(top: 0, bottom: 16)
        }
        .blockquote { configuration in
          HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 6)
              .fill(border)
              .relativeFrame(width: .em(0.2))
            configuration.label
              .markdownTextStyle { ForegroundColor(secondaryText) }
              .relativePadding(.horizontal, length: .em(1))
          }
          .fixedSize(horizontal: false, vertical: true)
        }
        .codeBlock { configuration in
          ScrollView(.horizontal) {
            configuration.label
              .fixedSize(horizontal: false, vertical: true)
              .relativeLineSpacing(.em(0.225))
              .markdownTextStyle {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.85))
              }
              .padding(16)
          }
          .background(secondaryBackground)
          .clipShape(RoundedRectangle(cornerRadius: 6))
          .markdownMargin(top: 0, bottom: 16)
        }
        .listItem { configuration in
          configuration.label
            .markdownMargin(top: .em(0.25))
        }
        .taskListMarker { configuration in
          Image(systemName: configuration.isCompleted ? "checkmark.square.fill" : "square")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(checkbox, checkboxBackground)
            .imageScale(.small)
            .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
        }
        .table { configuration in
          configuration.label
            .fixedSize(horizontal: false, vertical: true)
            .markdownTableBorderStyle(.init(color: border))
            .markdownTableBackgroundStyle(
              .alternatingRows(background, secondaryBackground)
            )
            .markdownMargin(top: 0, bottom: 16)
        }
        .tableCell { configuration in
          configuration.label
            .markdownTextStyle {
              if configuration.row == 0 {
                FontWeight(.semibold)
              }
              BackgroundColor(nil)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 6)
            .padding(.horizontal, 13)
            .relativeLineSpacing(.em(0.25))
        }
        .thematicBreak {
          Divider()
            .relativeFrame(height: .em(0.25))
            .overlay(border)
            .markdownMargin(top: 24, bottom: 24)
        }
    }

    private static func makeLegacyDocCTheme() -> Theme {
      let text = Color(light: Color(rgba: 0x1d1d_1fff), dark: Color(rgba: 0xf5f5_f7ff))
      let link = Color(light: Color(rgba: 0x0066_ccff), dark: Color(rgba: 0x2997_ffff))
      let asideNoteBackground = Color(light: Color(rgba: 0xf5f5_f7ff), dark: Color(rgba: 0x3232_32ff))
      let asideNoteBorder = Color(light: Color(rgba: 0x6969_69ff), dark: Color(rgba: 0x9a9a_9eff))
      let codeBackground = Color(light: Color(rgba: 0xf5f5_f7ff), dark: Color(rgba: 0x3333_36ff))
      let grid = Color(light: Color(rgba: 0xd2d2_d7ff), dark: Color(rgba: 0x4242_45ff))
      let containerShape = RoundedRectangle(cornerRadius: 15, style: .continuous)

      return Theme()
        .text {
          ForegroundColor(text)
        }
        .link {
          ForegroundColor(link)
        }
        .heading1 { configuration in
          configuration.label
            .markdownMargin(top: .em(0.8), bottom: .zero)
            .markdownTextStyle {
              FontWeight(.semibold)
              FontSize(.em(2))
            }
        }
        .heading2 { configuration in
          configuration.label
            .relativeLineSpacing(.em(0.0625))
            .markdownMargin(top: .em(1.6), bottom: .zero)
            .markdownTextStyle {
              FontWeight(.semibold)
              FontSize(.em(1.88235))
            }
        }
        .heading3 { configuration in
          configuration.label
            .relativeLineSpacing(.em(0.07143))
            .markdownMargin(top: .em(1.6), bottom: .zero)
            .markdownTextStyle {
              FontWeight(.semibold)
              FontSize(.em(1.64706))
            }
        }
        .heading4 { configuration in
          configuration.label
            .relativeLineSpacing(.em(0.083335))
            .markdownMargin(top: .em(1.6), bottom: .zero)
            .markdownTextStyle {
              FontWeight(.semibold)
              FontSize(.em(1.41176))
            }
        }
        .heading5 { configuration in
          configuration.label
            .relativeLineSpacing(.em(0.09091))
            .markdownMargin(top: .em(1.6), bottom: .zero)
            .markdownTextStyle {
              FontWeight(.semibold)
              FontSize(.em(1.29412))
            }
        }
        .heading6 { configuration in
          configuration.label
            .relativeLineSpacing(.em(0.235295))
            .markdownMargin(top: .em(1.6), bottom: .zero)
            .markdownTextStyle {
              FontWeight(.semibold)
            }
        }
        .paragraph { configuration in
          configuration.label
            .fixedSize(horizontal: false, vertical: true)
            .relativeLineSpacing(.em(0.235295))
            .markdownMargin(top: .em(0.8), bottom: .zero)
        }
        .blockquote { configuration in
          configuration.label
            .relativePadding(length: .rem(0.94118))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
              ZStack {
                containerShape.fill(asideNoteBackground)
                containerShape.strokeBorder(asideNoteBorder)
              }
            }
            .markdownMargin(top: .em(1.6), bottom: .zero)
        }
        .codeBlock { configuration in
          ScrollView(.horizontal) {
            configuration.label
              .fixedSize(horizontal: false, vertical: true)
              .relativeLineSpacing(.em(0.333335))
              .markdownTextStyle {
                FontFamilyVariant(.monospaced)
                FontSize(.rem(0.88235))
              }
              .padding(.vertical, 8)
              .padding(.leading, 14)
          }
          .background(codeBackground)
          .clipShape(containerShape)
          .markdownMargin(top: .em(0.8), bottom: .zero)
        }
        .image { configuration in
          configuration.label
            .frame(maxWidth: .infinity)
            .markdownMargin(top: .em(1.6), bottom: .em(1.6))
        }
        .listItem { configuration in
          configuration.label
            .markdownMargin(top: .em(0.8))
        }
        .taskListMarker { _ in
          ListBullet.disc
            .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
        }
        .table { configuration in
          configuration.label
            .fixedSize(horizontal: false, vertical: true)
            .markdownTableBorderStyle(.init(.horizontalBorders, color: grid))
            .markdownMargin(top: .em(1.6), bottom: .zero)
        }
        .tableCell { configuration in
          configuration.label
            .markdownTextStyle {
              if configuration.row == 0 {
                FontWeight(.semibold)
              }
            }
            .fixedSize(horizontal: false, vertical: true)
            .relativeLineSpacing(.em(0.235295))
            .relativePadding(length: .rem(0.58824))
        }
        .thematicBreak {
          Divider()
            .overlay(grid)
            .markdownMargin(top: .em(2.35), bottom: .em(2.35))
        }
    }
  }
#endif
