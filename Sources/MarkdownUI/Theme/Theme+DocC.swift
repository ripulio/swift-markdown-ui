import SwiftUI

extension Theme {
  /// A theme that mimics the DocC style.
  ///
  /// Style | Preview
  /// --- | ---
  /// Inline text | ![](DocCInlines)
  /// Headings | ![](DocCHeading)
  /// Blockquote | ![](DocCBlockquote)
  /// Code block | ![](DocCCodeBlock)
  /// Image | ![](DocCImage)
  /// Task list | Not applicable
  /// Bulleted list | ![](DocCNestedBulletedList)
  /// Numbered list | ![](DocCNumberedList)
  /// Table | ![](DocCTable)
  public static let docC: Theme = {
    var theme = Theme()
      .text {
        ForegroundColor(.text)
      }
      .link {
        ForegroundColor(.link)
      }
      .taskListMarker { _ in
        // DocC renders task lists as bullet lists
        ListBullet.disc
          .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
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

    theme.heading1 = .heading(
      fontWeight: .semibold,
      fontSize: .em(2),
      attachesAnchorID: true,
      topMargin: .relative(.em(0.8)),
      bottomMargin: .relative(.zero),
      scalesMarginToHeadingFont: true
    )
    theme.heading2 = .heading(
      fontWeight: .semibold,
      fontSize: .em(1.88235),
      lineSpacing: .em(0.0625),
      scalesLineSpacingToHeadingFont: true,
      attachesAnchorID: true,
      topMargin: .relative(.em(1.6)),
      bottomMargin: .relative(.zero),
      scalesMarginToHeadingFont: true
    )
    theme.heading3 = .heading(
      fontWeight: .semibold,
      fontSize: .em(1.64706),
      lineSpacing: .em(0.07143),
      scalesLineSpacingToHeadingFont: true,
      attachesAnchorID: true,
      topMargin: .relative(.em(1.6)),
      bottomMargin: .relative(.zero),
      scalesMarginToHeadingFont: true
    )
    theme.heading4 = .heading(
      fontWeight: .semibold,
      fontSize: .em(1.41176),
      lineSpacing: .em(0.083335),
      scalesLineSpacingToHeadingFont: true,
      attachesAnchorID: true,
      topMargin: .relative(.em(1.6)),
      bottomMargin: .relative(.zero),
      scalesMarginToHeadingFont: true
    )
    theme.heading5 = .heading(
      fontWeight: .semibold,
      fontSize: .em(1.29412),
      lineSpacing: .em(0.09091),
      scalesLineSpacingToHeadingFont: true,
      attachesAnchorID: true,
      topMargin: .relative(.em(1.6)),
      bottomMargin: .relative(.zero),
      scalesMarginToHeadingFont: true
    )
    theme.heading6 = .heading(
      fontWeight: .semibold,
      fontSize: nil,
      lineSpacing: .em(0.235295),
      scalesLineSpacingToHeadingFont: true,
      attachesAnchorID: true,
      topMargin: .relative(.em(1.6)),
      bottomMargin: .relative(.zero),
      scalesMarginToHeadingFont: true
    )
    theme.paragraph = .paragraph(
      lineSpacing: .em(0.235295),
      topMargin: .relative(.em(0.8)),
      bottomMargin: .relative(.zero)
    )
    theme.blockquote = .withBlockMargin(
      top: .relative(.em(1.6)),
      bottom: .relative(.zero)
    ) { configuration in
      configuration.label
        .relativePadding(length: .rem(0.94118))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
          ZStack {
            RoundedRectangle.container
              .fill(Color.asideNoteBackground)
            RoundedRectangle.container
              .strokeBorder(Color.asideNoteBorder)
          }
        }
    }
    theme.codeBlock = .withBlockMargin(
      top: .relative(.em(0.8)),
      bottom: .relative(.zero)
    ) { configuration in
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
      .background(Color.codeBackground)
      .clipShape(.container)
    }
    theme.image = .withBlockMargin(
      top: .relative(.em(1.6)),
      bottom: .relative(.em(1.6))
    ) { configuration in
      configuration.label
        .frame(maxWidth: .infinity)
    }
    theme.listItem = .listItem(topMargin: .relative(.em(0.8)))
    theme.table = .withBlockMargin(
      top: .relative(.em(1.6)),
      bottom: .relative(.zero)
    ) { configuration in
      configuration.label
        .fixedSize(horizontal: false, vertical: true)
        .markdownTableBorderStyle(.init(.horizontalBorders, color: .grid))
    }
    theme.thematicBreak = .withBlockMargin(
      top: .relative(.em(2.35)),
      bottom: .relative(.em(2.35))
    ) {
      Divider()
        .overlay(Color.grid)
    }
    return theme
  }()
}

extension Shape where Self == RoundedRectangle {
  fileprivate static var container: Self {
    .init(cornerRadius: 15, style: .continuous)
  }
}

extension Color {
  fileprivate static let text = Color(
    light: Color(rgba: 0x1d1d_1fff), dark: Color(rgba: 0xf5f5_f7ff)
  )
  fileprivate static let secondaryLabel = Color(
    light: Color(rgba: 0x6e6e_73ff), dark: Color(rgba: 0x8686_8bff)
  )
  fileprivate static let link = Color(
    light: Color(rgba: 0x0066_ccff), dark: Color(rgba: 0x2997_ffff)
  )
  fileprivate static let asideNoteBackground = Color(
    light: Color(rgba: 0xf5f5_f7ff), dark: Color(rgba: 0x3232_32ff)
  )
  fileprivate static let asideNoteBorder = Color(
    light: Color(rgba: 0x6969_69ff), dark: Color(rgba: 0x9a9a_9eff)
  )
  fileprivate static let codeBackground = Color(
    light: Color(rgba: 0xf5f5_f7ff), dark: Color(rgba: 0x3333_36ff)
  )
  fileprivate static let grid = Color(
    light: Color(rgba: 0xd2d2_d7ff), dark: Color(rgba: 0x4242_45ff)
  )
}
