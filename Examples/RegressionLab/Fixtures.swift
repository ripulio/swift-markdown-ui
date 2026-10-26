import Foundation

enum MarkdownFixture: String, CaseIterable, Identifiable {
    case spacing, formatting, longText, nestedLists, images, tables, dynamicType
    var id: String { rawValue }

    var source: String {
        switch self {
        case .spacing:
            return """
            Beginning text
            [Link](https://example.com) without missing spaces.
            **Emphasis Text** should stay separate.
            ***Strong emphasis*** should stay separate.
            ~~Deleted text~~ should stay separate.
            `inline code` should stay separate.
            """
        case .formatting:
            return "Normal **bold** *italic* ~~deleted~~ `code` [linked](https://example.com)."
        case .dynamicType:
            return "Text size"
        case .longText:
            return (1...1_200).map { "Line \($0): **bold** and [link](https://example.com)." }.joined(separator: "\n")
        case .nestedLists:
            return """
            # Nested list
            - Level one
              - Level two
                - Level three
                  - Level four
                    - Level five
                      - Level six
                        - Level seven
            """
        case .images:
            return """
            Text before [![Linked image](fixture://large)](https://example.com) text after.

            ![Large image](fixture://large)

            A **bold ![nested image](fixture://small)** within text.
            """
        case .tables:
            return """
            | Name | Count | Description |
            |:---|---:|:---|
            | Alpha | 12 | A longer explanation that wraps in a narrow screen. |
            | Beta | 2 | Short |
            """
        }
    }
}
