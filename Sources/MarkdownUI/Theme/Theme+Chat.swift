import SwiftUI

extension Theme {
  /// A theme tuned for conversational AI, streaming replies, and chat interfaces.
  ///
  /// `Theme.chat` activates every single-pass layout fast path in `MarkdownUI` out of the box:
  /// - Declarative block margins for single-pass settled heights with zero `PreferenceKey` scroll jumps.
  /// - Compact paragraph, heading, and bulleted-list layouts with direct `Text(verbatim:)` inline runs.
  /// - Viewport-aware horizontal-scrolling GFM tables (`AdaptiveTableLayout`) with shape-batched borders
  ///   and alternating row fills on iOS 16+ / macOS 13+.
  /// - Proportioned chat headings, rounded callout blockquotes, and fenced code blocks with an optional
  ///   language header bar, adapting automatically to Light Mode, Dark Mode, and Dynamic Type.
  ///
  /// ```swift
  /// Markdown(message.markdown)
  ///   .markdownTheme(.chat)
  ///   .textSelection(.enabled)
  /// ```
  public static let chat: Theme = {
    var theme = Theme()
      .code {
        FontFamilyVariant(.monospaced)
        FontSize(.em(0.88))
        BackgroundColor(Color.primary.opacity(0.07))
      }
      .strong {
        FontWeight(.semibold)
      }
      .link {
        ForegroundColor(.accentColor)
      }

    theme.heading1 = .heading(
      fontWeight: .semibold,
      fontSize: .em(1.35),
      lineSpacing: .em(0.15),
      topMargin: .relative(.em(0.95)),
      bottomMargin: .relative(.em(0.45))
    )
    theme.heading2 = .heading(
      fontWeight: .semibold,
      fontSize: .em(1.2),
      lineSpacing: .em(0.15),
      topMargin: .relative(.em(0.9)),
      bottomMargin: .relative(.em(0.4))
    )
    theme.heading3 = .heading(
      fontWeight: .semibold,
      fontSize: .em(1.08),
      lineSpacing: .em(0.15),
      topMargin: .relative(.em(0.8)),
      bottomMargin: .relative(.em(0.35))
    )
    theme.heading4 = .heading(
      fontWeight: .semibold,
      fontSize: nil,
      lineSpacing: .em(0.15),
      topMargin: .relative(.em(0.75)),
      bottomMargin: .relative(.em(0.3))
    )
    theme.heading5 = .heading(
      fontWeight: .semibold,
      fontSize: .em(0.94),
      lineSpacing: .em(0.15),
      topMargin: .relative(.em(0.7)),
      bottomMargin: .relative(.em(0.25))
    )
    theme.heading6 = .heading(
      fontWeight: .semibold,
      fontSize: .em(0.88),
      lineSpacing: .em(0.15),
      foregroundColor: .secondary,
      topMargin: .relative(.em(0.7)),
      bottomMargin: .relative(.em(0.25))
    )

    theme.paragraph = .paragraph(
      lineSpacing: .em(0.2),
      topMargin: .relative(.zero),
      bottomMargin: .relative(.em(0.75))
    )

    theme.listItem = .listItem(topMargin: .relative(.em(0.25)))

    theme.blockquote = .withBlockMargin(
      top: .relative(.zero),
      bottom: .relative(.em(0.75))
    ) { configuration in
      configuration.label
        .markdownTextStyle {
          ForegroundColor(.secondary)
        }
        .relativePadding(.leading, length: .em(0.9))
        .overlay(alignment: .leading) {
          RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color.primary.opacity(0.22))
            .frame(width: 3)
        }
    }

    theme.codeBlock = .withBlockMargin(
      top: .relative(.zero),
      bottom: .relative(.em(0.75))
    ) { configuration in
      VStack(alignment: .leading, spacing: 0) {
        if let language = configuration.language, !language.isEmpty {
          Text(verbatim: language)
            .font(.caption.monospaced().weight(.medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
          Divider()
            .opacity(0.5)
        }
        ScrollView(.horizontal, showsIndicators: true) {
          configuration.label
            .fixedSize(horizontal: false, vertical: true)
            .relativeLineSpacing(.em(0.2))
            .markdownTextStyle {
              FontFamilyVariant(.monospaced)
              FontSize(.em(0.86))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
      }
      .background(Color.primary.opacity(0.05))
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
      }
    }

    theme.tableCell = BlockStyle(revision: 11) { configuration in
      let frameAlignment: Alignment =
        configuration.alignment == .leading
        ? .topLeading
        : (configuration.alignment == .trailing ? .topTrailing : .top)
      configuration.label
        .markdownTextStyle {
          if configuration.row == 0 {
            FontWeight(.semibold)
          }
          BackgroundColor(nil)
        }
        .multilineTextAlignment(configuration.alignment)
        .fixedSize(horizontal: false, vertical: true)
        .relativeLineSpacing(.em(0.2))
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
    }

    theme.table = .withBlockMargin(
      top: .relative(.zero),
      bottom: .relative(.em(0.75))
    ) { configuration in
      if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
        ChatAdaptiveTableView(configuration: configuration)
      } else {
        configuration.label
          .fixedSize(horizontal: false, vertical: true)
      }
    }

    theme.thematicBreak = .withBlockMargin(
      top: .relative(.em(1.1)),
      bottom: .relative(.em(1.1))
    ) {
      Divider()
    }

    return theme
  }()
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private final class ChatTableViewportState {
  var availableWidth: CGFloat = 360
  var placedWidth: CGFloat = 0
  var measuredAtAvailableWidth: CGFloat?
  var sizedAtAvailableWidth: CGFloat?
  var scheduledResizeWidth: CGFloat?
  var lastUnsettledMeasuredWidth: CGFloat?
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct ChatAdaptiveTableView: View {
  let configuration: BlockConfiguration

  @Environment(\.theme.tableCell) private var tableCell
  @State private var viewport = ChatTableViewportState()
  @State private var resizeRevision = 0
  @ScaledMetric(relativeTo: .body) private var columnScale = 1.0

  private static let directCellStyle = MarkdownTableCellStyle(
    headerFontWeight: .semibold,
    lineSpacing: .em(0.2),
    padding: EdgeInsets(top: 7, leading: 10, bottom: 7, trailing: 10)
  )

  var body: some View {
    let _ = self.resizeRevision
    ChatTableViewportLayout(
      viewport: self.viewport,
      onViewportResize: {
        DispatchQueue.main.async {
          self.resizeRevision &+= 1
        }
      }
    ) {
      ScrollView(.horizontal, showsIndicators: true) {
        self.configuration.label
          .markdownTableLayout(
            .adaptive(
              availableWidth: {
                let width =
                  self.viewport.placedWidth > 0
                  ? self.viewport.placedWidth : self.viewport.availableWidth
                self.viewport.measuredAtAvailableWidth = width
                if let scheduled = self.viewport.scheduledResizeWidth,
                  abs(scheduled - width) <= 0.5
                {
                  self.viewport.scheduledResizeWidth = nil
                }
                return width * 1.5
              },
              minimumColumnWidth: 80 * self.columnScale,
              maximumColumnWidth: 380 * self.columnScale,
              overflow: .minimum
            )
          )
          .markdownTableCellStyle(self.tableCell.isBuiltinChatCell ? Self.directCellStyle : nil)
          .markdownTableBorderStyle(.init(color: Color.primary.opacity(0.14)))
          .markdownTableBackgroundStyle(
            .alternatingRows(
              Color.clear,
              Color.primary.opacity(0.03),
              header: Color.primary.opacity(0.055)
            )
          )
      }
    }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct ChatTableViewportLayout: Layout {
  let viewport: ChatTableViewportState
  let onViewportResize: () -> Void

  func explicitAlignment(
    of guide: HorizontalAlignment,
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Void
  ) -> CGFloat? {
    nil
  }

  func explicitAlignment(
    of guide: VerticalAlignment,
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Void
  ) -> CGFloat? {
    nil
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
    guard let scroll = subviews.first else { return .zero }
    if self.viewport.placedWidth <= 0, let width = proposal.width, width.isFinite, width > 0 {
      self.viewport.availableWidth = width
    }
    let size = scroll.sizeThatFits(proposal)
    if proposal.height == nil {
      self.viewport.sizedAtAvailableWidth = self.viewport.measuredAtAvailableWidth
    }
    return size
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Void
  ) {
    guard let scroll = subviews.first else { return }
    let sizedWidth = self.viewport.sizedAtAvailableWidth ?? self.viewport.measuredAtAvailableWidth
    if bounds.width.isFinite, bounds.width > 0 {
      self.viewport.placedWidth = bounds.width
      self.viewport.availableWidth = bounds.width
    }
    scroll.place(
      at: bounds.origin,
      anchor: .topLeading,
      proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
    )
    if bounds.width.isFinite, bounds.width > 0, let measuredWidth = sizedWidth {
      if abs(measuredWidth - bounds.width) <= 0.5 {
        self.viewport.lastUnsettledMeasuredWidth = nil
      } else if self.viewport.lastUnsettledMeasuredWidth.map({ abs($0 - bounds.width) > 0.5 })
        ?? true,
        self.viewport.scheduledResizeWidth.map({ abs($0 - bounds.width) > 0.5 }) ?? true
      {
        self.viewport.lastUnsettledMeasuredWidth = measuredWidth
        self.viewport.scheduledResizeWidth = bounds.width
        self.onViewportResize()
      }
    }
  }
}
