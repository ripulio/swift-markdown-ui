---
name: Bug report
about: Report a rendering, layout, streaming, or performance issue in MarkdownUI
title: ''
labels: ''
assignees: ''

---

Thank you for reporting an issue in `ripulio/swift-markdown-ui`!

**Describe the bug**
A clear and concise description of what went wrong.

**Checklist**
- [ ] I can reproduce this issue on the latest release tag (or `ripul` branch).
- [ ] This bug hasn't already been reported in an [existing GitHub issue](https://github.com/ripulio/swift-markdown-ui/issues).

**Minimal reproduction**
Include the Markdown input, theme/modifiers used (e.g., `.markdownTheme(.chat)`), and container (`List`, `ScrollView`, etc.):

```swift
Markdown(
  """
  ...
  """
)
.markdownTheme(.chat)
```

**Expected behavior**
What you expected to happen.

**Screenshots or recordings**
If applicable, add screenshots or a short screen recording.

**Environment**
- MarkdownUI version: [e.g. `2.5.1`]
- OS & Device: [e.g. iOS 18.4 on iPhone 16 Pro, macOS 15.4]
- Xcode / Swift version: [e.g. Xcode 16.3, Swift 6.1]

**Additional context**
Any extra details, thermal/perf traces, or workarounds.
