import SwiftUI

/// A type that applies a custom appearance to specific types of blocks in a Markdown view.
///
/// The styles of the different block types are brought together in a ``Theme``. You can customize
/// the style of a specific block type by using the `markdownBlockStyle(_:body:)` modifier.
///
/// The following example applies a custom appearance to each ``Theme/blockquote`` in
/// a ``Markdown`` view:
///
/// ```swift
/// Markdown {
///   """
///   You can quote text with a `>`.
///
///   > Outside of a dog, a book is man's best friend. Inside of a
///   > dog it's too dark to read.
///
///   – Groucho Marx
///   """
/// }
/// .markdownBlockStyle(\.blockquote) { configuration in
///   configuration.label
///     .padding()
///     .markdownTextStyle {
///       FontCapsVariant(.lowercaseSmallCaps)
///       FontWeight(.semibold)
///       BackgroundColor(nil)
///     }
///     .overlay(alignment: .leading) {
///       Rectangle()
///         .fill(Color.teal)
///         .frame(width: 4)
///     }
///     .background(Color.teal.opacity(0.5))
/// }
/// ```
///
/// ![](CustomBlockquote)
enum BlockMarginLength: Equatable {
  case points(CGFloat)
  case relative(RelativeSize)

  func points(relativeTo fontProperties: FontProperties?) -> CGFloat {
    switch self {
    case .points(let value):
      return value
    case .relative(let size):
      return size.points(relativeTo: fontProperties)
    }
  }
}

struct RelativeBlockMargin: Equatable {
  let top: BlockMarginLength?
  let bottom: BlockMarginLength?
  let fontSizeScale: RelativeSize?

  init(
    top: BlockMarginLength? = nil,
    bottom: BlockMarginLength? = nil,
    fontSizeScale: RelativeSize? = nil
  ) {
    self.top = top
    self.bottom = bottom
    self.fontSizeScale = fontSizeScale
  }

  func resolve(relativeTo fontProperties: FontProperties?) -> BlockMargin {
    var effectiveFontProperties = fontProperties
    if let fontSizeScale = self.fontSizeScale {
      var attrs = AttributeContainer()
      attrs.fontProperties = fontProperties ?? FontProperties()
      FontSize(fontSizeScale)._collectAttributes(in: &attrs)
      effectiveFontProperties = attrs.fontProperties
    }
    return BlockMargin(
      top: self.top?.points(relativeTo: effectiveFontProperties),
      bottom: self.bottom?.points(relativeTo: effectiveFontProperties)
    )
  }
}

public struct BlockStyle<Configuration>: Equatable {
  enum BuiltinBulletMarker: Equatable {
    case disc
    case circle
    case square
    case discCircleSquare
  }

  struct HeadingStyleSpec: Equatable {
    let fontWeight: Font.Weight?
    let fontSize: RelativeSize?
    let lineSpacing: RelativeSize?
    let scalesLineSpacingToHeadingFont: Bool
    let foregroundColor: Color?
    let attachesAnchorID: Bool

    init(
      fontWeight: Font.Weight? = nil,
      fontSize: RelativeSize? = nil,
      lineSpacing: RelativeSize? = nil,
      scalesLineSpacingToHeadingFont: Bool = false,
      foregroundColor: Color? = nil,
      attachesAnchorID: Bool = false
    ) {
      self.fontWeight = fontWeight
      self.fontSize = fontSize
      self.lineSpacing = lineSpacing
      self.scalesLineSpacingToHeadingFont = scalesLineSpacingToHeadingFont
      self.foregroundColor = foregroundColor
      self.attachesAnchorID = attachesAnchorID
    }

    func resolvedLineSpacing(relativeTo fontProperties: FontProperties?) -> CGFloat? {
      guard let lineSpacing = self.lineSpacing else { return nil }
      if self.scalesLineSpacingToHeadingFont, let headingFontSize = self.fontSize {
        var attrs = AttributeContainer()
        attrs.fontProperties = fontProperties ?? FontProperties()
        FontSize(headingFontSize)._collectAttributes(in: &attrs)
        return lineSpacing.points(relativeTo: attrs.fontProperties)
      }
      return lineSpacing.points(relativeTo: fontProperties)
    }
  }

  private let revision: UInt64
  private let body: (Configuration) -> AnyView
  let isIdentity: Bool
  let isMarginOnly: Bool
  let builtinBulletMarker: BuiltinBulletMarker?
  let paragraphLineSpacing: RelativeSize?
  let headingSpec: HeadingStyleSpec?
  let blockMargin: RelativeBlockMargin?

  var hasDeclarativeMargin: Bool {
    self.isIdentity || self.blockMargin != nil
  }

  var isBuiltinChatCell: Bool {
    self.revision == 11
  }

  /// Creates a block style that customizes a block by applying the given body.
  /// - Parameter body: A view builder that returns the customized block.
  public init<Body: View>(@ViewBuilder body: @escaping (_ configuration: Configuration) -> Body) {
    self.revision = StyleRevisionID.next()
    self.body = { AnyView(body($0)) }
    self.isIdentity = false
    self.isMarginOnly = false
    self.builtinBulletMarker = nil
    self.paragraphLineSpacing = nil
    self.headingSpec = nil
    self.blockMargin = nil
  }

  init<Body: View>(
    revision: UInt64? = nil,
    isIdentity: Bool = false,
    isMarginOnly: Bool = false,
    builtinBulletMarker: BuiltinBulletMarker? = nil,
    paragraphLineSpacing: RelativeSize? = nil,
    headingSpec: HeadingStyleSpec? = nil,
    blockMargin: RelativeBlockMargin? = nil,
    @ViewBuilder body: @escaping (_ configuration: Configuration) -> Body
  ) {
    if let revision {
      self.revision = revision
    } else if isIdentity {
      self.revision = 1
    } else if let builtinBulletMarker {
      switch builtinBulletMarker {
      case .disc: self.revision = 2
      case .circle: self.revision = 3
      case .square: self.revision = 4
      case .discCircleSquare: self.revision = 5
      }
    } else {
      self.revision = StyleRevisionID.next()
    }
    self.body = { AnyView(body($0)) }
    self.isIdentity = isIdentity
    self.isMarginOnly = isMarginOnly
    self.builtinBulletMarker = builtinBulletMarker
    self.paragraphLineSpacing = paragraphLineSpacing
    self.headingSpec = headingSpec
    self.blockMargin = blockMargin
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.revision == rhs.revision
      && lhs.isMarginOnly == rhs.isMarginOnly
      && lhs.paragraphLineSpacing == rhs.paragraphLineSpacing
      && lhs.headingSpec == rhs.headingSpec
      && lhs.blockMargin == rhs.blockMargin
  }

  func makeBody(configuration: Configuration) -> AnyView {
    self.body(configuration)
  }

  static func withBlockMargin<Body: View>(
    top: BlockMarginLength? = nil,
    bottom: BlockMarginLength? = nil,
    @ViewBuilder body: @escaping (_ configuration: Configuration) -> Body
  ) -> Self {
    let margin = RelativeBlockMargin(top: top, bottom: bottom)
    return Self(blockMargin: margin) { configuration in
      body(configuration)
        .modifier(DeclarativeBlockMarginModifier(margin: margin))
    }
  }
}

private struct DeclarativeBlockMarginModifier: ViewModifier {
  @Environment(\.markdownBlockMargins) private var staticBlockMargins
  @Environment(\.usesDeclarativeBlockMargins) private var usesDeclarativeBlockMargins
  @Environment(\.textStyleAttributes) private var textStyleAttributes

  let margin: RelativeBlockMargin

  func body(content: Content) -> some View {
    if self.staticBlockMargins != nil || self.usesDeclarativeBlockMargins {
      content
    } else {
      let resolved = self.margin.resolve(relativeTo: self.textStyleAttributes.fontProperties)
      content.transformPreference(BlockMarginsPreference.self) { value in
        value = value.combined(with: resolved)
      }
    }
  }
}

extension BlockStyle where Configuration == BlockConfiguration {
  static var identity: Self {
    Self(isIdentity: true) { $0.label }
  }

  /// A paragraph block style that wraps vertically with the given relative line spacing.
  public static func paragraph(lineSpacing: RelativeSize) -> Self {
    Self(revision: 6, paragraphLineSpacing: lineSpacing) { configuration in
      configuration.label
        .fixedSize(horizontal: false, vertical: true)
        .relativeLineSpacing(lineSpacing)
    }
  }

  static func paragraph(
    lineSpacing: RelativeSize,
    topMargin: BlockMarginLength?,
    bottomMargin: BlockMarginLength?
  ) -> Self {
    let margin = RelativeBlockMargin(top: topMargin, bottom: bottomMargin)
    return Self(
      revision: 8,
      paragraphLineSpacing: lineSpacing,
      blockMargin: margin
    ) { configuration in
      configuration.label
        .fixedSize(horizontal: false, vertical: true)
        .relativeLineSpacing(lineSpacing)
        .modifier(DeclarativeBlockMarginModifier(margin: margin))
    }
  }

  /// A declarative heading block style applying an optional font weight, relative font size,
  /// and relative line spacing without requiring per-heading environment closures when direct
  /// block rendering is enabled.
  public static func heading(
    fontWeight: Font.Weight? = nil,
    fontSize: RelativeSize? = nil,
    lineSpacing: RelativeSize? = nil
  ) -> Self {
    let spec = HeadingStyleSpec(
      fontWeight: fontWeight,
      fontSize: fontSize,
      lineSpacing: lineSpacing
    )
    return Self(revision: 7, headingSpec: spec) { configuration in
      let styled = configuration.label.markdownTextStyle {
        if let fontWeight {
          FontWeight(fontWeight)
        }
        if let fontSize {
          FontSize(fontSize)
        }
      }
      if let lineSpacing {
        styled.relativeLineSpacing(lineSpacing)
      } else {
        styled
      }
    }
  }

  static func heading(
    fontWeight: Font.Weight? = nil,
    fontSize: RelativeSize? = nil,
    lineSpacing: RelativeSize? = nil,
    scalesLineSpacingToHeadingFont: Bool = false,
    foregroundColor: Color? = nil,
    attachesAnchorID: Bool = false,
    topMargin: BlockMarginLength? = nil,
    bottomMargin: BlockMarginLength? = nil,
    scalesMarginToHeadingFont: Bool = false
  ) -> Self {
    let spec = HeadingStyleSpec(
      fontWeight: fontWeight,
      fontSize: fontSize,
      lineSpacing: lineSpacing,
      scalesLineSpacingToHeadingFont: scalesLineSpacingToHeadingFont,
      foregroundColor: foregroundColor,
      attachesAnchorID: attachesAnchorID
    )
    let margin = RelativeBlockMargin(
      top: topMargin,
      bottom: bottomMargin,
      fontSizeScale: scalesMarginToHeadingFont ? fontSize : nil
    )
    return Self(
      revision: 9,
      headingSpec: spec,
      blockMargin: margin
    ) { configuration in
      let base = configuration.label
      let withSpacing: AnyView = {
        guard let lineSpacing else { return AnyView(base) }
        if scalesLineSpacingToHeadingFont {
          return AnyView(base.relativeLineSpacing(lineSpacing))
        }
        return AnyView(base)
      }()
      let withTextStyle = withSpacing.markdownTextStyle {
        if let fontWeight {
          FontWeight(fontWeight)
        }
        if let fontSize {
          FontSize(fontSize)
        }
        if let foregroundColor {
          ForegroundColor(foregroundColor)
        }
      }
      if let lineSpacing, !scalesLineSpacingToHeadingFont {
        withTextStyle
          .relativeLineSpacing(lineSpacing)
          .modifier(DeclarativeBlockMarginModifier(margin: margin))
      } else {
        withTextStyle
          .modifier(DeclarativeBlockMarginModifier(margin: margin))
      }
    }
  }

  static func listItem(
    topMargin: BlockMarginLength?,
    bottomMargin: BlockMarginLength? = nil
  ) -> Self {
    let margin = RelativeBlockMargin(top: topMargin, bottom: bottomMargin)
    return Self(
      revision: 10,
      isMarginOnly: true,
      blockMargin: margin
    ) { configuration in
      configuration.label
        .modifier(DeclarativeBlockMarginModifier(margin: margin))
    }
  }
}

extension BlockStyle where Configuration == Void {
  /// Creates a block style for a block with no content, like a thematic break.
  /// - Parameter body: A view builder that returns the customized block.
  public init<Body: View>(@ViewBuilder body: @escaping () -> Body) {
    self.init { _ in
      body()
    }
  }

  static func withBlockMargin<Body: View>(
    top: BlockMarginLength? = nil,
    bottom: BlockMarginLength? = nil,
    @ViewBuilder body: @escaping () -> Body
  ) -> Self {
    Self.withBlockMargin(top: top, bottom: bottom) { _ in
      body()
    }
  }
}
