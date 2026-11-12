import SwiftUI

extension Theme {
  /// The default Markdown theme.
  ///
  /// Style | Preview
  /// --- | ---
  /// Inline text | ![](BasicInlines)
  /// Headings | ![](Heading)
  /// Blockquote | ![](BlockquoteContent)
  /// Code block | ![](CodeBlock)
  /// Image | ![](Paragraph)
  /// Task list | ![](TaskList)
  /// Bulleted list | ![](NestedBulletedList)
  /// Numbered list | ![](NumberedList)
  /// Table | ![](Table-Collection)
  public static let basic: Theme = {
    var theme = Theme()
      .code {
        FontFamilyVariant(.monospaced)
        FontSize(.em(0.94))
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

    let headingSizes: [RelativeSize] = [
      .em(2), .em(1.5), .em(1.17), .em(1), .em(0.83), .em(0.67),
    ]
    theme.headings = headingSizes.map { size in
      .heading(
        fontWeight: .semibold,
        fontSize: size,
        attachesAnchorID: true,
        topMargin: .relative(.rem(1.5)),
        bottomMargin: .relative(.rem(1))
      )
    }
    theme.paragraph = .paragraph(
      lineSpacing: .em(0.15),
      topMargin: .relative(.zero),
      bottomMargin: .relative(.em(1))
    )
    theme.blockquote = .withBlockMargin { configuration in
      configuration.label
        .markdownTextStyle {
          FontStyle(.italic)
        }
        .relativePadding(.leading, length: .em(2))
        .relativePadding(.trailing, length: .em(1))
    }
    theme.codeBlock = .withBlockMargin(
      top: .relative(.zero),
      bottom: .relative(.em(1))
    ) { configuration in
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
    }
    theme.table = .withBlockMargin(
      top: .relative(.zero),
      bottom: .relative(.em(1))
    ) { configuration in
      configuration.label
        .fixedSize(horizontal: false, vertical: true)
    }
    theme.thematicBreak = .withBlockMargin(
      top: .relative(.em(2)),
      bottom: .relative(.em(2))
    ) {
      Divider()
    }
    return theme
  }()
}
