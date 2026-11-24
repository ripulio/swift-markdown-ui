# MarkdownBenchmark

Interactive iOS & macOS benchmark and streaming preview app for **MarkdownUI 2.5**.

## What It Demonstrates

1. **Attached-Host Settled Layout Benchmark (`400pt` width):** Attaches each SwiftUI view inside a real `UIWindow` / `UIHostingController` (or `NSWindow` / `NSHostingView`), runs settle ticks until height converges, and compares median settled time and pass-1 height jump (`Δ pt`) across:
   - `Theme.chat` (MarkdownUI 2.5 single-pass)
   - `Theme.basic` (MarkdownUI 2.5 single-pass, pixel-identical to Legacy 2.4.1)
   - `Theme.gitHub` (MarkdownUI 2.5 single-pass)
   - `Legacy 2.4.1` (upstream closure-based theme triggering multi-pass `PreferenceKey` re-layout)
   - `Plain Text` (unstyled `SwiftUI.Text` baseline)
2. **120 Hz Token Streaming:** Streams headings, inline code, bullet lists, fenced code blocks, and adaptive GFM tables live using `.markdownTheme(.chat)`.
3. **Built-In Theme Gallery:** Switch live between `.chat`, `.gitHub`, `.docC`, and `.basic`.

## Running Locally

Generate the Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen) and run on an iPhone or Mac (use **Release** build configuration for accurate timing numbers):

```bash
cd Examples/BenchmarkApp
xcodegen
open MarkdownBenchmark.xcodeproj
```
