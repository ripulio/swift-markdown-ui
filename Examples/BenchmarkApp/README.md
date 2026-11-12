# MarkdownBenchmark

Interactive iOS & macOS benchmark and streaming preview app for **MarkdownUI 2.5**.

## What It Demonstrates

1. **Cold Layout Benchmark (`400pt` width):** Measures median millisecond host layout time and pass-1 vs settled height convergence (`Δ 0.0pt`) across 7 Markdown constructs (`Theme.chat`, `Theme.basic`, `Theme.gitHub`, and plain `SwiftUI.Text`).
2. **120 Hz Token Streaming:** Streams headings, inline code, bullet lists, fenced code blocks, and adaptive GFM tables live using `.markdownTheme(.chat)`.
3. **Built-In Theme Gallery:** Switch live between `.chat`, `.gitHub`, `.docC`, and `.basic`.

## Running Locally

Generate the Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen) and run on an iPhone or Mac (use **Release** build configuration for device benchmark numbers):

```bash
cd Examples/BenchmarkApp
xcodegen
open MarkdownBenchmark.xcodeproj
```
