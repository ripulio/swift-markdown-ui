import SwiftUI

/// Fixed point margins for a Markdown block.
public struct BlockMargin: Equatable, Sendable {
  public var top: CGFloat?
  public var bottom: CGFloat?

  public static let unspecified = BlockMargin()

  public init(top: CGFloat? = nil, bottom: CGFloat? = nil) {
    self.top = top
    self.bottom = bottom
  }

  func combined(with other: BlockMargin) -> BlockMargin {
    BlockMargin(
      top: Self.max(self.top, other.top),
      bottom: Self.max(self.bottom, other.bottom)
    )
  }

  static func max(_ lhs: CGFloat?, _ rhs: CGFloat?) -> CGFloat? {
    switch (lhs, rhs) {
    case let (lhs?, rhs?):
      return Swift.max(lhs, rhs)
    case let (lhs?, nil):
      return lhs
    case let (nil, rhs?):
      return rhs
    case (nil, nil):
      return nil
    }
  }
}

/// Fixed point margins for each kind of Markdown block, allowing `BlockSequence`
/// to compute spacing directly from the parsed block tree on the first pass.
public struct MarkdownBlockMargins: Equatable, Sendable {
  public var heading1: BlockMargin
  public var heading2: BlockMargin
  public var heading3: BlockMargin
  public var heading4: BlockMargin
  public var heading5: BlockMargin
  public var heading6: BlockMargin
  public var paragraph: BlockMargin
  public var blockquote: BlockMargin
  public var codeBlock: BlockMargin
  public var image: BlockMargin
  public var list: BlockMargin
  public var listItem: BlockMargin
  public var table: BlockMargin
  public var thematicBreak: BlockMargin

  public init(
    heading1: BlockMargin = .unspecified,
    heading2: BlockMargin = .unspecified,
    heading3: BlockMargin = .unspecified,
    heading4: BlockMargin = .unspecified,
    heading5: BlockMargin = .unspecified,
    heading6: BlockMargin = .unspecified,
    paragraph: BlockMargin = .unspecified,
    blockquote: BlockMargin = .unspecified,
    codeBlock: BlockMargin = .unspecified,
    image: BlockMargin = .unspecified,
    list: BlockMargin = .unspecified,
    listItem: BlockMargin = .unspecified,
    table: BlockMargin = .unspecified,
    thematicBreak: BlockMargin = .unspecified
  ) {
    self.heading1 = heading1
    self.heading2 = heading2
    self.heading3 = heading3
    self.heading4 = heading4
    self.heading5 = heading5
    self.heading6 = heading6
    self.paragraph = paragraph
    self.blockquote = blockquote
    self.codeBlock = codeBlock
    self.image = image
    self.list = list
    self.listItem = listItem
    self.table = table
    self.thematicBreak = thematicBreak
  }

  public init(
    heading: BlockMargin,
    paragraph: BlockMargin = .unspecified,
    blockquote: BlockMargin = .unspecified,
    codeBlock: BlockMargin = .unspecified,
    image: BlockMargin = .unspecified,
    list: BlockMargin = .unspecified,
    listItem: BlockMargin = .unspecified,
    table: BlockMargin = .unspecified,
    thematicBreak: BlockMargin = .unspecified
  ) {
    self.init(
      heading1: heading,
      heading2: heading,
      heading3: heading,
      heading4: heading,
      heading5: heading,
      heading6: heading,
      paragraph: paragraph,
      blockquote: blockquote,
      codeBlock: codeBlock,
      image: image,
      list: list,
      listItem: listItem,
      table: table,
      thematicBreak: thematicBreak
    )
  }

  func heading(level: Int) -> BlockMargin {
    switch level {
    case 1: return self.heading1
    case 2: return self.heading2
    case 3: return self.heading3
    case 4: return self.heading4
    case 5: return self.heading5
    default: return self.heading6
    }
  }
}

protocol BlockMarginElement: Hashable {
  func effectiveMargin(using margins: MarkdownBlockMargins, inlineImageFlow: Bool) -> BlockMargin
}

extension BlockNode: BlockMarginElement {
  func effectiveMargin(using margins: MarkdownBlockMargins, inlineImageFlow: Bool) -> BlockMargin {
    switch self {
    case .blockquote(let children):
      return children.reduce(margins.blockquote) {
        $0.combined(with: $1.effectiveMargin(using: margins, inlineImageFlow: inlineImageFlow))
      }
    case .bulletedList(_, let items), .numberedList(_, _, let items):
      return items.reduce(margins.list) {
        $0.combined(with: $1.effectiveMargin(using: margins, inlineImageFlow: inlineImageFlow))
      }
    case .taskList(_, let items):
      return items.reduce(margins.list) {
        $0.combined(with: $1.effectiveMargin(using: margins, inlineImageFlow: inlineImageFlow))
      }
    case .codeBlock:
      return margins.codeBlock
    case .htmlBlock:
      return margins.paragraph
    case .paragraph(let content):
      guard margins.image != .unspecified, content.containsImageView else {
        return margins.paragraph
      }
      return margins.paragraph.combined(with: margins.image)
    case .heading(let level, let content):
      let base = margins.heading(level: level)
      guard inlineImageFlow, margins.image != .unspecified, content.containsImageView else {
        return base
      }
      return base.combined(with: margins.image)
    case .table(_, let rows):
      guard #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) else {
        return .unspecified
      }
      guard margins.image != .unspecified,
        rows.contains(where: { $0.cells.contains(where: { $0.content.containsImageFlow }) })
      else {
        return margins.table
      }
      return margins.table.combined(with: margins.image)
    case .thematicBreak:
      return margins.thematicBreak
    }
  }
}

extension RawListItem: BlockMarginElement {
  func effectiveMargin(using margins: MarkdownBlockMargins, inlineImageFlow: Bool) -> BlockMargin {
    self.children.reduce(margins.listItem) {
      $0.combined(with: $1.effectiveMargin(using: margins, inlineImageFlow: inlineImageFlow))
    }
  }
}

extension RawTaskListItem: BlockMarginElement {
  func effectiveMargin(using margins: MarkdownBlockMargins, inlineImageFlow: Bool) -> BlockMargin {
    self.children.reduce(margins.listItem) {
      $0.combined(with: $1.effectiveMargin(using: margins, inlineImageFlow: inlineImageFlow))
    }
  }
}

extension Array where Element == InlineNode {
  fileprivate var containsImageFlow: Bool {
    self.imageFragments().contains {
      if case .image = $0 { return true }
      return false
    }
  }

  fileprivate var containsImageView: Bool {
    if self.count == 1, self.first?.imageData != nil {
      return true
    }
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
      return self.containsImageFlow
    }
    return false
  }
}

extension View {
  /// Sets the preferred top margin for the block content in this view.
  ///
  /// Use this modifier inside a ``BlockStyle`` `body` closure to customize the top spacing
  /// of the block content.
  ///
  /// - Parameter top: The minimum relative top spacing to use when laying out this block
  ///                  together with other blocks.
  public func markdownMargin(top: RelativeSize) -> some View {
    self.markdownMargin(top: top, bottom: nil)
  }

  /// Sets the preferred bottom margin for the block content in this view.
  ///
  /// Use this modifier inside a ``BlockStyle`` `body` closure to customize the bottom spacing
  /// of the block content.
  ///
  /// - Parameter bottom: The minimum relative bottom spacing to use when laying out this
  ///                     block together with other blocks.
  public func markdownMargin(bottom: RelativeSize) -> some View {
    self.markdownMargin(top: nil, bottom: bottom)
  }

  /// Sets the preferred top and bottom margins for the block content in this view.
  ///
  /// Use this modifier inside a ``BlockStyle`` `body` closure to customize the top and
  /// bottom spacing of the block content.
  ///
  /// - Parameters:
  ///   - top: The minimum relative top spacing to use when laying out this block together with
  ///          other blocks. If you set the value to `nil`, MarkdownUI uses the preferred
  ///          maximum value of the child blocks or the system's default padding amount
  ///          if no preference has been set.
  ///   - bottom: The minimum relative bottom spacing to use when laying out this block
  ///             together with other blocks. If you set the value to `nil`, MarkdownUI
  ///             uses the preferred maximum value of the child blocks or the system's
  ///             default padding amount if no preference has been set.
  public func markdownMargin(top: RelativeSize?, bottom: RelativeSize?) -> some View {
    TextStyleAttributesReader { attributes in
      self.markdownMargin(
        top: top?.points(relativeTo: attributes.fontProperties),
        bottom: bottom?.points(relativeTo: attributes.fontProperties)
      )
    }
  }

  /// Sets the preferred top margin for the block content in this view.
  ///
  /// Use this modifier inside a ``BlockStyle`` `body` closure to customize the top spacing
  /// of the block content.
  ///
  /// - Parameter top: The minimum top spacing, given in points, to use when laying out this block
  ///                  together with other blocks.
  public func markdownMargin(top: CGFloat) -> some View {
    self.markdownMargin(top: top, bottom: nil)
  }

  /// Sets the preferred bottom margin for the block content in this view.
  ///
  /// Use this modifier inside a ``BlockStyle`` `body` closure to customize the bottom spacing
  /// of the block content.
  ///
  /// - Parameter bottom: The minimum bottom spacing, given in points, to use when laying out this
  ///                     block together with other blocks.
  public func markdownMargin(bottom: CGFloat) -> some View {
    self.markdownMargin(top: nil, bottom: bottom)
  }

  /// Sets the preferred top and bottom margins for the block content in this view.
  ///
  /// Use this modifier inside a ``BlockStyle`` `body` closure to customize the top and
  /// bottom spacing of the block content.
  ///
  /// - Parameters:
  ///   - top: The minimum top spacing, given in points, to use when laying out this block
  ///          together with other blocks. If you set the value to `nil`, MarkdownUI uses
  ///          the preferred maximum value of the child blocks or the system's default
  ///          padding amount if no preference has been set.
  ///   - bottom: The minimum bottom spacing, given in points, to use when laying out
  ///             this block together with other blocks. If you set the value to `nil`,
  ///             MarkdownUI uses the preferred maximum value of the child blocks or
  ///             the system's default padding amount if no preference has been set.
  public func markdownMargin(top: CGFloat?, bottom: CGFloat?) -> some View {
    self.transformPreference(BlockMarginsPreference.self) { value in
      value = value.combined(with: BlockMargin(top: top, bottom: bottom))
    }
  }
}

struct BlockMarginsPreference: PreferenceKey {
  static let defaultValue: BlockMargin = .unspecified

  static func reduce(value: inout BlockMargin, nextValue: () -> BlockMargin) {
    value = value.combined(with: nextValue())
  }
}
