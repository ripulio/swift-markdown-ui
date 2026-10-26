import SwiftUI

/// The properties of a Markdown code block.
///
/// The theme ``Theme/codeBlock`` block style receives a `CodeBlockConfiguration`
/// input in its `body` closure.
public struct CodeBlockConfiguration {
  /// A type-erased view of a Markdown code block.
  public struct Label: View {
    init<L: View>(_ label: L) {
      self.body = AnyView(label)
    }

    public let body: AnyView
  }

  /// The code block language, if present.
  public let language: String?

  /// The code block contents.
  public let content: String

  /// The block's zero-based position through the document's nested containers.
  ///
  /// Use this to scope controls such as wrapping or expansion independently for
  /// each code block. It remains stable when text is appended while streaming.
  /// Positions are document-local and can change when blocks are inserted before
  /// this one; scope persisted state to the enclosing message or document.
  public let blockPath: [Int]

  /// The code block view.
  public let label: Label
}
