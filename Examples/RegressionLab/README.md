# Standalone Markdown regression app

This app uses the local MarkdownUI package directly. It has fixtures for inline
spacing, mixed formatting, a 1,200-line paragraph, nested lists, images and tables.
The controls change the fixture, Dynamic Type size and content without relaunching.
UI tests read actual accessibility text and operate the app; no screenshot
comparison is required.

Borrow an iPhone simulator with `ripul-train acquire simulators os=27 type=iPhone`,
then run from the package root:

```sh
xcodegen generate --spec Examples/RegressionLab/project.yml
xcodebuild -project Examples/RegressionLab/MarkdownRegressionLab.xcodeproj \
  -scheme MarkdownRegressionLab -configuration Debug \
  -destination 'platform=iOS Simulator,id=<leased-udid>' \
  -derivedDataPath /tmp/ripul-markdown-lab-derived \
  -parallel-testing-enabled NO -collect-test-diagnostics never test
```

Keep the DerivedData path stable between iterations and release the simulator
lease when finished. Use the installed Xcode with the required simulator SDK.

Baseline on 26 October 2026: the iOS 27.1 standalone app reproduced issue #402:
`Linkwithout`, `Emphasis Textshould`, `Strong emphasisshould`, `Deleted textshould`
and `inline codeshould`. The seven-level nested-list interaction case passed;
that does not establish a general performance bound for all nested documents.

After fixes: all five UI tests pass. The long-text fixture also exposed an
accessibility bottleneck: SwiftUI recomputed each link's geometry against one
huge Text while XCTest took a snapshot. Splitting at existing rendered line
breaks into bounded Text views restored interaction. Linked images now render
within 320 points and their actual button opens the link. Nested alt labels are
accessible. The larger-text control grows Markdown at the same rate as native
body text (within the test's rounding tolerance).
