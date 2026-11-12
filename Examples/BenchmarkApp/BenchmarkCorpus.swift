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
      "| Construct | Upstream 2.4.1 | Ripul 2.5 |\n| :--- | ---: | ---: |\n"
      + (1...14).map {
        "| Layout pass #\($0) (`400pt`) | \(18 + $0).4 ms | **\(3 + ($0 % 3)).\(($0 * 3) % 10) ms** |"
      }.joined(separator: "\n")

    return [
      BenchmarkSample(
        id: "reply",
        title: "Rich AI Reply",
        subtitle: "Headings, prose, bullets, code & GFM table",
        markdown: """
          ## Release Summary

          `MarkdownUI` 2.5 computes block spacing directly from the parsed syntax tree on pass 1, eliminating **all** `PreferenceKey` height jumps during scrolling and token streaming.

          - **Single-pass heights:** First-pass height equals settled height (`Δ 0.0pt`).
          - **Direct `Text(verbatim:)` runs:** Skips per-span `AttributedString` dictionary bridging.
          - **Adaptive GFM tables:** Fits readable columns to the viewport and scrolls wide data cleanly.
          - **Native selection:** Supports `.textSelection(.enabled)` across paragraphs, lists, and code.

          ```swift
          Markdown(message.markdown)
            .markdownTheme(.chat)
            .textSelection(.enabled)
          ```

          | Sample | Markdown (`Theme.chat`) | Plain `SwiftUI.Text` |
          | :--- | ---: | ---: |
          | Rich AI Reply | **4.6 ms** | 7.2 ms |
          | Bullet List | **3.5 ms** | 4.6 ms |
          | Code Block | **2.4 ms** | 10.6 ms |
          """
      ),
      BenchmarkSample(
        id: "list",
        title: "Bullet List (16 Items)",
        subtitle: "BulletedListLayout + cached cap-center probe",
        markdown: bullets16
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
        markdown: "Deployed commit `2.5.0` — all 86 tests and 35 pixel snapshots matched."
      ),
    ]
  }()
}
