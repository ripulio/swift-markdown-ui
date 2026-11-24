# Contributing to `ripulio/swift-markdown-ui`

Thanks for your interest in contributing! This repository is an actively maintained, source-compatible continuation of `gonzalezreal/swift-markdown-ui` maintained by [Ripul](https://ripul.io).

## Guiding Principles

1. **100% source compatibility with `MarkdownUI 2.x`:** Keep `import MarkdownUI` and existing `Theme`, `BlockStyle`, and `TextStyle` APIs working unchanged.
2. **Single-pass settled heights:** Built-in themes (`.basic`, `.gitHub`, `.docC`, `.chat`) must settle on pass 1 (`Δ 0.0 pt`) without `PreferenceKey` height jumps, while custom `.markdownBlockStyle(...)` closures fall back cleanly to the dynamic path.
3. **Preserve deployment targets:** Maintain the `iOS 15+` / `macOS 12+` / `tvOS 15+` / `watchOS 8+` baseline (gating `Layout`-based enhancements cleanly behind `@available(iOS 16.0, macOS 13.0, ...)`).
4. **Verify parity & performance:** Before opening a PR that touches layout, margins, or inline rendering, read [`ARCHITECTURE.md`](ARCHITECTURE.md) (especially the safety invariants at the bottom).

## Running Tests Locally

Run the Swift Package Manager test suite on macOS:

```bash
swift test --skip FontPropertiesTests
```

> **Why `--skip FontPropertiesTests`?** On newer macOS / Xcode toolchains, the unchanged upstream `FontPropertiesTests` fails eight opaque SwiftUI `Font` equality assertions (reproducible on the unmodified upstream `2.4.1` tag). All 94 remaining unit, layout convergence, adaptive table, link hit-testing, and built-in theme pixel-parity tests run and must pass.

Validate the package manifest:

```bash
swift package dump-package > /dev/null
```

## Sample & Verification Apps

- **Benchmarks & Streaming:** `cd Examples/BenchmarkApp && xcodegen && open MarkdownBenchmark.xcodeproj`
- **iOS UI Regressions:** `xcodegen generate --spec Examples/RegressionLab/project.yml` (see [`Examples/RegressionLab/README.md`](Examples/RegressionLab/README.md))
- **Demo Gallery:** Open `Examples/Demo/Demo.xcodeproj`

## Pull Requests

- Target the `ripul` branch (the repository's default branch).
- Include focused regression tests for bug fixes (prefer real hosted `NSHostingView` / `UIHostingController` checks over fragile snapshots where practical).
- Keep synthetic test fixtures self-contained and free of private/internal data.
- Follow the formatting rules in `.swiftformat` (`make format`).

## Code of Conduct

Participation in this project is governed by the [Code of Conduct](.github/CODE_OF_CONDUCT.md).
