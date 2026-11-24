import Foundation

struct BenchmarkSample: Identifiable, Hashable {
  let id: String
  let title: String
  let subtitle: String
  let markdown: String

  static let all: [BenchmarkSample] = {
    let bullets16 = (1...16).map {
      "- **Step \($0):** Rows near the viewport measure in a single pass with `DirectTextStyle`, *emphasis*, and [links](https://example.com)."
    }.joined(separator: "\n")

    let table15x3 =
      "| Stage | Layout Path | Behavior |\n| :--- | :--- | ---: |\n"
      + (1...14).map {
        "| Pass #\($0) (`400pt`) | Single-pass tree margin & shape batch | **0.0 pt Δ** |"
      }.joined(separator: "\n")

    return [
      BenchmarkSample(
        id: "reply",
        title: "Rich AI Reply",
        subtitle: "Headings, prose, bullets, code & GFM table",
        markdown: """
          ## Release Summary

          `MarkdownUI` 2.6 resolves block margins, lists, and tables directly from the parsed syntax tree on pass 1, eliminating **all** `PreferenceKey` height jumps during scrolling and token streaming.

          - **Single-pass heights:** First-pass height matches settled height (`Δ 0.0pt`).
          - **Direct `Text(verbatim:)` runs:** Avoids per-span `AttributedString` dictionary bridging across all built-in themes.
          - **Adaptive & automatic GFM tables:** Keeps narrow columns compact and scrolls wide tables cleanly.
          - **O(1) live streaming:** Completed blocks stay memoized as tokens stream into the trailing block.

          ```swift
          Markdown(message.markdown)
            .markdownTheme(.chat)
            .textSelection(.enabled)
          ```

          | Component | Layout Strategy | Height Jump |
          | :--- | :--- | ---: |
          | Prose & Headings | `DirectBlockSequenceView` | **0.0 pt** |
          | Bulleted Lists | `BulletedListLayout` | **0.0 pt** |
          | GFM Tables | `AdaptiveTableLayout` | **0.0 pt** |
          """
      ),
      BenchmarkSample(
        id: "list",
        title: "Bullet List (16 Items)",
        subtitle: "BulletedListLayout + cached cap-center probe",
        markdown: bullets16
      ),
      BenchmarkSample(
        id: "ordered_and_tasks",
        title: "Numbered, Nested & Task Lists",
        subtitle: "Single-pass NumberedListLayout + flattened nested bullets",
        markdown:
          (1...10).map {
            "\($0). **Step \($0):** Single-pass baseline-aligned marker with `code` and **bold**."
          }.joined(separator: "\n")
          + "\n\n"
          + (1...3).map { s in
            "- **Group \(s):** Parent bullet\n  - Child A with *emphasis*\n  - Child B with `inline_code()`"
          }.joined(separator: "\n")
          + "\n\n- [x] Single-pass automatic tables\n- [x] Prefix-stable streaming batches\n- [ ] Ship `2.6.0`"
      ),
      BenchmarkSample(
        id: "table",
        title: "GFM Table (15×3)",
        subtitle: "AdaptiveTableLayout + shape-batched grid",
        markdown: table15x3
      ),
      BenchmarkSample(
        id: "paragraphs",
        title: "Paragraph Stack (8 Blocks)",
        subtitle: "ParagraphStackLayout + PrecomputedInlineAttributes",
        markdown: (1...8).map {
          "Paragraph \($0) renders **semibold**, *italic*, `monospaced code`, and [inline links](https://example.com) without intermediate `VStack` or `AnyView` wrappers."
        }.joined(separator: "\n\n")
      ),
      BenchmarkSample(
        id: "code",
        title: "Fenced Code Block",
        subtitle: "Horizontal scroll container + language header",
        markdown: """
          ```swift
          struct StreamingMessageView: View {
            let markdown: String

            var body: some View {
              Markdown(markdown)
                .markdownTheme(.chat)
                .textSelection(.enabled)
            }
          }
          ```
          """
      ),
      BenchmarkSample(
        id: "notice",
        title: "Callout Blockquote",
        subtitle: "Nested quote + inline code & bold spans",
        markdown: """
          > **Tip:** Built-in themes (`.chat`, `.basic`, `.gitHub`, and `.docC`) automatically activate single-pass block margins with zero configuration.
          """
      ),
      BenchmarkSample(
        id: "short",
        title: "Short Bubble",
        subtitle: "Single-line chat acknowledgment",
        markdown: "Updated to `MarkdownUI 2.6.0` — single-pass layout and O(1) streaming verified across all themes."
      ),
    ]
  }()
}
