# Standalone Markdown Regression App

This standalone iOS app links the local `MarkdownUI` package directly and provides interactive fixtures plus automated XCUITest coverage for:

- Whitespace preservation after styled line-start spans (upstream `#402`)
- Long newline-heavy linked paragraphs (1,200 links) without UI or accessibility hangs (upstream `#312`)
- Deeply nested lists (7 levels)
- Inline/mixed linked images, nested alt labels, and `markdownInlineImageFlow()` in headings and table cells (upstream `#420` / `#439`)
- Dynamic Type scaling compared against native SwiftUI body text

UI tests inspect accessibility elements and interact with real controls directly—no snapshot baseline files are required.

## Running Locally

Generate the Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen) and run the UI test suite against an available iOS Simulator from the repository root:

```sh
xcodegen generate --spec Examples/RegressionLab/project.yml
xcodebuild -project Examples/RegressionLab/MarkdownRegressionLab.xcodeproj \
  -scheme MarkdownRegressionLab \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

You can also open `Examples/RegressionLab/MarkdownRegressionLab.xcodeproj` in Xcode to toggle fixtures, Dynamic Type sizes, and content interactively without relaunching.
