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
  let plainTextMs: Double
  let heightDeltaPt: CGFloat
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
            Text("Cold Host Layout Benchmark (Width 400pt)")
              .font(.headline)
            Text(
              "Measures median cold SwiftUI host sizing & layout time across \(rounds) rounds per sample, plus pass-1 vs settled height convergence (Δ pt)."
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
          Section("Results (Lower ms is faster)") {
            ForEach(results) { item in
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                      .font(.headline)
                    Text(item.subtitle)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                  Spacer()
                  Text(String(format: "Δ %.1fpt", item.heightDeltaPt))
                    .font(.caption.monospaced().weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                      (item.heightDeltaPt <= 0.5 ? Color.green : Color.orange).opacity(0.16),
                      in: Capsule()
                    )
                }

                let maxMs = max(item.chatMs, item.basicMs, item.gitHubMs, item.plainTextMs, 0.1)
                MetricBar(label: "Theme.chat", ms: item.chatMs, maxMs: maxMs, tint: .blue)
                MetricBar(label: "Theme.basic", ms: item.basicMs, maxMs: maxMs, tint: .teal)
                MetricBar(label: "Theme.gitHub", ms: item.gitHubMs, maxMs: maxMs, tint: .indigo)
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
    var measured: [SampleBenchmarkResult] = []

    // Warm font caches once before timing.
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
      let plainRuns = (0..<rounds).map { _ in
        HostMeasurer.measure(
          Text(sample.markdown).fixedSize(horizontal: false, vertical: true),
          width: 400
        )
      }

      measured.append(
        SampleBenchmarkResult(
          id: sample.id,
          title: sample.title,
          subtitle: sample.subtitle,
          chatMs: Self.median(chatRuns.map(\.elapsedMs)),
          basicMs: Self.median(basicRuns.map(\.elapsedMs)),
          gitHubMs: Self.median(gitHubRuns.map(\.elapsedMs)),
          plainTextMs: Self.median(plainRuns.map(\.elapsedMs)),
          heightDeltaPt: chatRuns.first?.heightDelta ?? 0
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
        .frame(width: 92, alignment: .leading)

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

private enum HostMeasurer {
  struct Timing {
    let elapsedMs: Double
    let heightDelta: CGFloat
  }

  @MainActor
  static func measure<V: View>(_ view: V, width: CGFloat) -> Timing {
    let constrained = view.frame(width: width, alignment: .leading)
    #if canImport(UIKit)
      let start = CACurrentMediaTime()
      let controller = UIHostingController(rootView: constrained)
      let target = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
      let firstHeight = controller.sizeThatFits(in: target).height
      controller.view.frame = CGRect(x: 0, y: 0, width: width, height: max(1, ceil(firstHeight)))
      controller.view.layoutIfNeeded()
      let elapsedMs = (CACurrentMediaTime() - start) * 1000
      let settledHeight = controller.sizeThatFits(in: target).height
      return Timing(elapsedMs: elapsedMs, heightDelta: abs(settledHeight - firstHeight))
    #elseif canImport(AppKit)
      let start = CACurrentMediaTime()
      let host = NSHostingView(rootView: constrained)
      host.frame = NSRect(x: 0, y: 0, width: width, height: 2400)
      host.layoutSubtreeIfNeeded()
      let firstHeight = host.fittingSize.height
      let elapsedMs = (CACurrentMediaTime() - start) * 1000
      host.layoutSubtreeIfNeeded()
      let settledHeight = host.fittingSize.height
      return Timing(elapsedMs: elapsedMs, heightDelta: abs(settledHeight - firstHeight))
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
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
