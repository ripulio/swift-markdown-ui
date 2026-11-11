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
public struct BlockStyle<Configuration> {
  enum BuiltinBulletMarker {
    case disc
    case circle
    case square
    case discCircleSquare
  }

  private let body: (Configuration) -> AnyView
  let isIdentity: Bool
  let builtinBulletMarker: BuiltinBulletMarker?
  let paragraphLineSpacing: RelativeSize?

  /// Creates a block style that customizes a block by applying the given body.
  /// - Parameter body: A view builder that returns the customized block.
  public init<Body: View>(@ViewBuilder body: @escaping (_ configuration: Configuration) -> Body) {
    self.body = { AnyView(body($0)) }
    self.isIdentity = false
    self.builtinBulletMarker = nil
    self.paragraphLineSpacing = nil
  }

  init<Body: View>(
    isIdentity: Bool = false,
    builtinBulletMarker: BuiltinBulletMarker? = nil,
    paragraphLineSpacing: RelativeSize? = nil,
    @ViewBuilder body: @escaping (_ configuration: Configuration) -> Body
  ) {
    self.body = { AnyView(body($0)) }
    self.isIdentity = isIdentity
    self.builtinBulletMarker = builtinBulletMarker
    self.paragraphLineSpacing = paragraphLineSpacing
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
    Self(paragraphLineSpacing: lineSpacing) { configuration in
      configuration.label
        .fixedSize(horizontal: false, vertical: true)
        .relativeLineSpacing(lineSpacing)
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
