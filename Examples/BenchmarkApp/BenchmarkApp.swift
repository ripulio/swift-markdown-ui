import MarkdownUI
import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

@main
struct MarkdownBenchmarkApp: App {
  var body: some Scene {
    WindowGroup {
      RootBenchmarkView()
    }
  }
}

private struct RootBenchmarkView: View {
  var body: some View {
    TabView {
      BenchmarkSuiteView()
        .tabItem {
          Label("Benchmark", systemImage: "speedometer")
        }

      StreamingDemoView()
        .tabItem {
          Label("120 Hz Stream", systemImage: "bolt.horizontal.fill")
        }

      ThemeGalleryView()
        .tabItem {
          Label("Themes", systemImage: "paintbrush.fill")
        }
    }
  }
}

// MARK: - Benchmark Tab

private struct SampleBenchmarkResult: Identifiable {
  let id: String
  let title: String
  let subtitle: String
  let chatMs: Double
  let basicMs: Double
  let gitHubMs: Double
  let legacy241Ms: Double
  let plainTextMs: Double
  let chatHeightDeltaPt: CGFloat
  let legacyHeightDeltaPt: CGFloat
}

private struct BenchmarkSuiteView: View {
  @State private var results: [SampleBenchmarkResult] = []
  @State private var isRunning = false
  @State private var rounds = 5

  var body: some View {
    NavigationStack {
      List {
        Section {
          VStack(alignment: .leading, spacing: 10) {
            Text("Attached-Host Settled Layout Benchmark (400pt)")
              .font(.headline)
            Text(
              "Attaches each view inside a real window/hosting controller, runs settle ticks until height converges, and reports median settled time across \(rounds) rounds plus pass-1 vs settled height jump (Δ pt). Legacy 2.4.1 uses upstream closure-based styles on the same host."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack {
              Picker("Rounds", selection: $rounds) {
                Text("3 rounds").tag(3)
                Text("5 rounds").tag(5)
                Text("9 rounds").tag(9)
              }
              .pickerStyle(.segmented)

              Button {
                runBenchmarks()
              } label: {
                Label(isRunning ? "Running…" : "Run Benchmark", systemImage: "play.fill")
                  .fontWeight(.semibold)
              }
              .buttonStyle(.borderedProminent)
              .disabled(isRunning)
            }
          }
          .padding(.vertical, 4)
        }

        if !results.isEmpty {
          Section("Results — Settled Time (Lower ms is faster)") {
            ForEach(results) { item in
              VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                  VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                      .font(.headline)
                    Text(item.subtitle)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                  Spacer()
                  VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "2.5 Δ %.1fpt", item.chatHeightDeltaPt))
                      .font(.caption2.monospaced().weight(.semibold))
                      .padding(.horizontal, 7)
                      .padding(.vertical, 2)
                      .background(
                        (item.chatHeightDeltaPt <= 0.5 ? Color.green : Color.orange).opacity(0.16),
                        in: Capsule()
                      )
                    Text(String(format: "2.4.1 Δ %.1fpt", item.legacyHeightDeltaPt))
                      .font(.caption2.monospaced())
                      .foregroundStyle(.secondary)
                  }
                }

                let maxMs = max(
                  item.chatMs, item.basicMs, item.gitHubMs, item.legacy241Ms, item.plainTextMs, 0.1)
                MetricBar(label: "Theme.chat", ms: item.chatMs, maxMs: maxMs, tint: .blue)
                MetricBar(label: "Theme.basic", ms: item.basicMs, maxMs: maxMs, tint: .teal)
                MetricBar(label: "Theme.gitHub", ms: item.gitHubMs, maxMs: maxMs, tint: .indigo)
                MetricBar(label: "Legacy 2.4.1", ms: item.legacy241Ms, maxMs: maxMs, tint: .orange)
                MetricBar(label: "Plain Text", ms: item.plainTextMs, maxMs: maxMs, tint: .secondary)
              }
              .padding(.vertical, 4)
            }
          }
        }
      }
      .navigationTitle("MarkdownUI 2.5")
    }
  }

  @MainActor
  private func runBenchmarks() {
    isRunning = true
    let legacyBasic = LegacyUpstreamThemes.basic
    var measured: [SampleBenchmarkResult] = []

    // Warm font and layout caches once before timing.
    _ = HostMeasurer.measure(
      Markdown("Warmup **bold** `code`").markdownTheme(.chat),
      width: 400
    )

    for sample in BenchmarkSample.all {
      let chatRuns = (0..<rounds).map { _ in
        HostMeasurer.measure(
          Markdown(sample.markdown).markdownTheme(.chat),
          width: 400
        )
      }
      let basicRuns = (0..<rounds).map { _ in
        HostMeasurer.measure(
          Markdown(sample.markdown).markdownTheme(.basic),
          width: 400
        )
      }
      let gitHubRuns = (0..<rounds).map { _ in
        HostMeasurer.measure(
          Markdown(sample.markdown).markdownTheme(.gitHub),
          width: 400
        )
      }
      let legacyRuns = (0..<rounds).map { _ in
        HostMeasurer.measure(
          Markdown(sample.markdown).markdownTheme(legacyBasic),
          width: 400
        )
      }
      let plainRuns = (0..<rounds).map { _ in
        HostMeasurer.measure(
          Text(verbatim: sample.markdown).fixedSize(horizontal: false, vertical: true),
          width: 400
        )
      }

      measured.append(
        SampleBenchmarkResult(
          id: sample.id,
          title: sample.title,
          subtitle: sample.subtitle,
          chatMs: Self.median(chatRuns.map(\.settledMs)),
          basicMs: Self.median(basicRuns.map(\.settledMs)),
          gitHubMs: Self.median(gitHubRuns.map(\.settledMs)),
          legacy241Ms: Self.median(legacyRuns.map(\.settledMs)),
          plainTextMs: Self.median(plainRuns.map(\.settledMs)),
          chatHeightDeltaPt: chatRuns.first?.heightDelta ?? 0,
          legacyHeightDeltaPt: legacyRuns.first?.heightDelta ?? 0
        )
      )
    }

    results = measured
    isRunning = false
  }

  private static func median(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    return sorted[sorted.count / 2]
  }
}

private struct MetricBar: View {
  let label: String
  let ms: Double
  let maxMs: Double
  let tint: Color

  var body: some View {
    HStack(spacing: 8) {
      Text(label)
        .font(.caption.monospaced())
        .frame(width: 96, alignment: .leading)

      GeometryReader { geo in
        let fraction = max(0.03, min(1, ms / maxMs))
        RoundedRectangle(cornerRadius: 4, style: .continuous)
          .fill(tint.gradient)
          .frame(width: geo.size.width * fraction, height: 10)
          .frame(maxHeight: .infinity, alignment: .center)
      }
      .frame(height: 14)

      Text(String(format: "%.2f ms", ms))
        .font(.caption.monospaced().weight(.medium))
        .frame(width: 66, alignment: .trailing)
    }
  }
}

/// Exact upstream 2.4.1 closure-based `Theme.basic` definition (triggers multi-pass
/// `BlockMarginsPreference` and dynamic block styles on the exact same host).
private enum LegacyUpstreamThemes {
  static let basic: Theme = Theme()
    .code {
      FontFamilyVariant(.monospaced)
      FontSize(.em(0.94))
    }
    .heading1 { configuration in
      configuration.label
        .markdownMargin(top: .rem(1.5), bottom: .rem(1))
        .markdownTextStyle {
          FontWeight(.semibold)
          FontSize(.em(2))
        }
    }
    .heading2 { configuration in
      configuration.label
        .markdownMargin(top: .rem(1.5), bottom: .rem(1))
        .markdownTextStyle {
          FontWeight(.semibold)
          FontSize(.em(1.5))
        }
    }
    .heading3 { configuration in
      configuration.label
        .markdownMargin(top: .rem(1.5), bottom: .rem(1))
        .markdownTextStyle {
          FontWeight(.semibold)
          FontSize(.em(1.25))
        }
    }
    .heading4 { configuration in
      configuration.label
        .markdownMargin(top: .rem(1.5), bottom: .rem(1))
        .markdownTextStyle {
          FontWeight(.semibold)
        }
    }
    .heading5 { configuration in
      configuration.label
        .markdownMargin(top: .rem(1.5), bottom: .rem(1))
        .markdownTextStyle {
          FontWeight(.semibold)
          FontSize(.em(0.875))
        }
    }
    .heading6 { configuration in
      configuration.label
        .markdownMargin(top: .rem(1.5), bottom: .rem(1))
        .markdownTextStyle {
          FontWeight(.semibold)
          FontSize(.em(0.85))
        }
    }
    .paragraph { configuration in
      configuration.label
        .relativeLineSpacing(.em(0.15))
        .markdownMargin(top: .zero, bottom: .em(1))
    }
    .blockquote { configuration in
      configuration.label
        .markdownTextStyle {
          FontStyle(.italic)
        }
        .relativePadding(.leading, length: .em(1))
        .overlay(alignment: .leading) {
          Rectangle()
            .fill(Color.secondary)
            .frame(width: 4)
        }
        .markdownMargin(top: .zero, bottom: .em(1))
    }
    .codeBlock { configuration in
      configuration.label
        .relativeLineSpacing(.em(0.25))
        .markdownTextStyle {
          FontFamilyVariant(.monospaced)
          FontSize(.em(0.85))
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .markdownMargin(top: .zero, bottom: .em(1))
    }
    .listItem { configuration in
      configuration.label
        .markdownMargin(top: .em(0.25))
    }
    .table { configuration in
      configuration.label
        .fixedSize(horizontal: false, vertical: true)
        .markdownTableBorderStyle(.init(color: Color.secondary.opacity(0.4)))
        .markdownMargin(top: .zero, bottom: .em(1))
    }
    .tableCell { configuration in
      configuration.label
        .markdownTextStyle {
          if configuration.row == 0 {
            FontWeight(.semibold)
          }
          BackgroundColor(nil)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 6)
        .padding(.horizontal, 13)
        .relativeLineSpacing(.em(0.25))
    }
    .thematicBreak {
      Divider()
        .markdownMargin(top: .em(1.5), bottom: .em(1.5))
    }
}

private enum HostMeasurer {
  struct Timing {
    let firstPassMs: Double
    let settledMs: Double
    let heightDelta: CGFloat
  }

  @MainActor
  static func measure<V: View>(_ view: V, width: CGFloat) -> Timing {
    let constrained = view.frame(width: width, alignment: .leading)
    #if canImport(UIKit)
      let hostWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 2400))
      let parent = UIViewController()
      hostWindow.rootViewController = parent
      hostWindow.isHidden = false
      defer {
        hostWindow.isHidden = true
        hostWindow.rootViewController = nil
      }

      let target = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
      let start = CACurrentMediaTime()
      let controller = UIHostingController(rootView: constrained)
      if #available(iOS 16.0, *) {
        controller.sizingOptions = []
      }
      parent.addChild(controller)
      parent.view.addSubview(controller.view)
      controller.didMove(toParent: parent)
      defer {
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
      }

      let firstHeight = controller.sizeThatFits(in: target).height
      controller.view.frame = CGRect(x: 0, y: 0, width: width, height: max(1, ceil(firstHeight)))
      controller.view.setNeedsLayout()
      controller.view.layoutIfNeeded()
      let firstPassMs = (CACurrentMediaTime() - start) * 1000

      var settledHeight = firstHeight
      var settledMs = firstPassMs
      for _ in 0..<4 {
        let tickStart = CACurrentMediaTime()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.002))
        let nextHeight = controller.sizeThatFits(in: target).height
        let changed = abs(nextHeight - settledHeight) > 0.5
        if changed {
          settledHeight = nextHeight
          controller.view.frame = CGRect(
            x: 0, y: 0, width: width, height: max(1, ceil(settledHeight)))
          controller.view.setNeedsLayout()
          controller.view.layoutIfNeeded()
          settledMs += (CACurrentMediaTime() - tickStart) * 1000
        } else {
          break
        }
      }
      return Timing(
        firstPassMs: firstPassMs,
        settledMs: settledMs,
        heightDelta: abs(settledHeight - firstHeight)
      )
    #elseif canImport(AppKit)
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: width, height: 2400),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
      )
      defer { window.contentView = nil }

      let start = CACurrentMediaTime()
      let host = NSHostingView(rootView: constrained)
      window.contentView = host
      host.frame = NSRect(x: 0, y: 0, width: width, height: 2400)
      host.layoutSubtreeIfNeeded()
      let firstHeight = host.fittingSize.height
      let firstPassMs = (CACurrentMediaTime() - start) * 1000

      var settledHeight = firstHeight
      var settledMs = firstPassMs
      for _ in 0..<4 {
        let tickStart = CACurrentMediaTime()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.002))
        host.layoutSubtreeIfNeeded()
        let nextHeight = host.fittingSize.height
        if abs(nextHeight - settledHeight) > 0.5 {
          settledHeight = nextHeight
          host.frame = NSRect(x: 0, y: 0, width: width, height: max(1, ceil(settledHeight)))
          host.layoutSubtreeIfNeeded()
          settledMs += (CACurrentMediaTime() - tickStart) * 1000
        } else {
          break
        }
      }
      return Timing(
        firstPassMs: firstPassMs,
        settledMs: settledMs,
        heightDelta: abs(settledHeight - firstHeight)
      )
    #endif
  }
}

// MARK: - Streaming Demo Tab

private struct StreamingDemoView: View {
  private let fullText = BenchmarkSample.all[0].markdown
  @State private var charCount = 0
  @State private var isStreaming = false
  @State private var streamTask: Task<Void, Never>?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            Button {
              startStreaming()
            } label: {
              Label(isStreaming ? "Restart Stream" : "Stream Reply", systemImage: "sparkles")
                .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)

            Button("Show Full") {
              streamTask?.cancel()
              isStreaming = false
              charCount = fullText.count
            }
            .buttonStyle(.bordered)

            Spacer()

            Text("\(charCount)/\(fullText.count) chars")
              .font(.caption.monospaced())
              .foregroundStyle(.secondary)
          }

          Markdown(String(fullText.prefix(charCount)))
            .markdownTheme(.chat)
            .textSelection(.enabled)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding()
      }
      .navigationTitle("Streaming Preview")
      .onAppear {
        if charCount == 0 {
          startStreaming()
        }
      }
      .onDisappear {
        streamTask?.cancel()
      }
    }
  }

  private func startStreaming() {
    streamTask?.cancel()
    charCount = 0
    isStreaming = true
    let total = fullText.count
    streamTask = Task { @MainActor in
      while charCount < total, !Task.isCancelled {
        charCount = min(total, charCount + 6)
        try? await Task.sleep(for: .milliseconds(16))
      }
      isStreaming = false
    }
  }
}

// MARK: - Theme Gallery Tab

private enum PresetThemeChoice: String, CaseIterable, Identifiable {
  case chat = "Chat (New)"
  case gitHub = "GitHub"
  case docC = "DocC"
  case basic = "Basic"

  var id: String { rawValue }

  var theme: Theme {
    switch self {
    case .chat: return .chat
    case .gitHub: return .gitHub
    case .docC: return .docC
    case .basic: return .basic
    }
  }
}

private struct ThemeGalleryView: View {
  @State private var selectedTheme: PresetThemeChoice = .chat
  @State private var selectedSample: BenchmarkSample = BenchmarkSample.all[0]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Picker("Theme", selection: $selectedTheme) {
            ForEach(PresetThemeChoice.allCases) { preset in
              Text(preset.rawValue).tag(preset)
            }
          }
          .pickerStyle(.segmented)

          Picker("Sample", selection: $selectedSample) {
            ForEach(BenchmarkSample.all) { sample in
              Text(sample.title).tag(sample)
            }
          }
          .pickerStyle(.menu)

          Markdown(selectedSample.markdown)
            .markdownTheme(selectedTheme.theme)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
              RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1))
            )
        }
        .padding()
      }
      .navigationTitle("Built-In Themes")
    }
  }
}
