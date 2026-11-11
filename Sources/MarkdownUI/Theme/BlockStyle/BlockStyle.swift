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
  }

  private let revision: UInt64
  private let body: (Configuration) -> AnyView
  let isIdentity: Bool
  let builtinBulletMarker: BuiltinBulletMarker?
  let paragraphLineSpacing: RelativeSize?
  let headingSpec: HeadingStyleSpec?

  /// Creates a block style that customizes a block by applying the given body.
  /// - Parameter body: A view builder that returns the customized block.
  public init<Body: View>(@ViewBuilder body: @escaping (_ configuration: Configuration) -> Body) {
    self.revision = StyleRevisionID.next()
    self.body = { AnyView(body($0)) }
    self.isIdentity = false
    self.builtinBulletMarker = nil
    self.paragraphLineSpacing = nil
    self.headingSpec = nil
  }

  init<Body: View>(
    revision: UInt64? = nil,
    isIdentity: Bool = false,
    builtinBulletMarker: BuiltinBulletMarker? = nil,
    paragraphLineSpacing: RelativeSize? = nil,
    headingSpec: HeadingStyleSpec? = nil,
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
    self.builtinBulletMarker = builtinBulletMarker
    self.paragraphLineSpacing = paragraphLineSpacing
    self.headingSpec = headingSpec
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.revision == rhs.revision
      && lhs.paragraphLineSpacing == rhs.paragraphLineSpacing
      && lhs.headingSpec == rhs.headingSpec
  }

  func makeBody(configuration: Configuration) -> AnyView {
    self.body(configuration)
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
}

extension BlockStyle where Configuration == Void {
  /// Creates a block style for a block with no content, like a thematic break.
  /// - Parameter body: A view builder that returns the customized block.
  public init<Body: View>(@ViewBuilder body: @escaping () -> Body) {
    self.init { _ in
      body()
    }
  }
}
