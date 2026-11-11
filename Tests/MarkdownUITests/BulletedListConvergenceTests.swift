#if canImport(AppKit) || canImport(UIKit)
  #if canImport(AppKit)
    import AppKit
  #elseif canImport(UIKit)
    import UIKit
  #endif
  import SwiftUI
  import XCTest
  @_spi(Testing) @testable import MarkdownUI

  @available(iOS 16.0, macOS 13.0, *)
  final class BulletedListConvergenceTests: XCTestCase {
    private let chatMargins = MarkdownBlockMargins(
      heading: BlockMargin(top: 8, bottom: 4),
      paragraph: BlockMargin(top: 0, bottom: 8),
      blockquote: BlockMargin(top: 4, bottom: 8),
      codeBlock: BlockMargin(top: 8, bottom: 8),
      list: BlockMargin(top: 4, bottom: 8),
      listItem: BlockMargin(top: 2, bottom: 2),
      table: BlockMargin(top: 8, bottom: 8),
      thematicBreak: BlockMargin(top: 12, bottom: 12)
    )

    private func makeTheme() -> Theme {
      Theme.basic
        .text {
          FontSize(14.5)
          ForegroundColor(.primary)
        }
        .strong { FontWeight(.semibold) }
        .link {
          ForegroundColor(.blue)
          UnderlineStyle(.single)
        }
        .code {
          FontFamilyVariant(.monospaced)
          FontSize(.em(0.88))
          BackgroundColor(Color.primary.opacity(0.08))
        }
        .headings(fontWeight: .semibold, fontSize: .em(1.1), lineSpacing: .em(0.15))
        .paragraph(lineSpacing: .em(0.2))
    }

    @ViewBuilder
    private func makeHostedMarkdown(
      _ text: String,
      directBlocks: Bool,
      selectable: Bool,
      onHeightReport: @escaping (CGFloat) -> Void
    ) -> some View {
      let body = Markdown(MarkdownContent(text))
        .markdownTheme(self.makeTheme())
        .markdownBlockMargins(self.chatMargins)
        .markdownLightweightListMarkers(true)
        .markdownLightweightBlocks(true)
        .markdownCompactLayout(true)
        .markdownDirectBlocks(directBlocks)
        .markdownSoftBreakMode(.lineBreak)
        .frame(maxWidth: .infinity, alignment: .leading)

      RowIdealTopLayout {
        Group {
          if selectable {
            body.textSelection(.enabled)
          } else {
            body
          }
        }
        .background(
          GeometryReader { geo in
            Color.clear.preference(key: RowHeightPrefKey.self, value: geo.size.height)
          }
        )
      }
      .onPreferenceChange(RowHeightPrefKey.self, perform: onHeightReport)
    }

    @MainActor
    func testStreamingAndIdleListLayoutConverges() {
      let streamingReply = """
      Canary #8 (build 202611111534, b7304295d) is published.

      - **Studio:** already running the batch code; its Trainyard restarted on the new checkout at 15:30.
      - **Mac mini:** still on the previous canary. Its host installs canary #8 once its agents are idle, and the Antigravity agent there is busy getting the acceptance run ready.
      - **MacBook:** still stuck on c83d32c62. A `sudo` prompt has been waiting for your password there for 15 hours: the Shell chat running the Xcode 27.3 migration (`~/.ripul/xcode-migration-27.3/activate.sh`).

      Once the mini is on the new build and the Antigravity agent has replied with its plan, I'll check the plan and tell it to start the run.
      """

      let nestedAcceptanceReply = """
      The acceptance fixture is staged and pre-checked on the mini at `/Users/petermaude/repos/batch-acceptance-20261111` (no batch started yet).

      ### 1. Prepared Fixture
      - **Outside any git repository:** `/Users/petermaude/repos` has no `.git` above it and is outside guarded folders.
      - **Script (`transcribe_sim.py`, 922 B, invoked via `/usr/bin/python3`):**
        - Probing Studio + mini showed differing login-shell `node`/`python3` versions (`node` 23.6 vs 24.x), whereas `/usr/bin/python3` matches on both.
        - Runs `115,000,000` PBKDF2-HMAC-SHA256 iterations (~22 s of CPU work per item) and writes `{ input, host, digest }` to `{out}`.
      - **Inputs omitted from snapshot (~10.8 MB total):**
        - `inbox/item-01.raw` … `inbox/item-42.raw`: **42 files × 256 KB** passed via `--each 'inbox/*.raw'`.
        - `config/vocab.bin`: **64 KB** shared input passed via `--in config/vocab.bin`.
        - Pre-checked with `takeSnapshot`: `git ls-tree -r` lists **only `transcribe_sim.py`**.

      1. **What is already proven today without live changes:**
         - `xcode-signin.test.mjs` verifies `macInUse` (`HIDIdleTime < 300s && !screenLocked()`).
         - `batches.test.mjs` proves end-to-end that `inUse: true` starts 0 items with a clear `waitReason`.
      2. **If we also want a live multi-Mac daemon proof across Studio + mini:**
         - Add a **batch-scoped** `pretendInUse` list stored on that batch record only.
         - Start a 12-item batch across Studio + mini\nwith soft break inside bullet item.
      """

      for directBlocks in [false, true] {
        for selectable in [true, false] {
          for clearCache in [true, false] {
            self.runStreamingScenario(
              name: "streamingReply",
              fullText: streamingReply,
              directBlocks: directBlocks,
              selectable: selectable,
              clearCache: clearCache
            )
            self.runStreamingScenario(
              name: "nestedAcceptanceReply",
              fullText: nestedAcceptanceReply,
              directBlocks: directBlocks,
              selectable: selectable,
              clearCache: clearCache
            )
          }
        }
      }
    }

    @MainActor
    private func runStreamingScenario(
      name: String,
      fullText: String,
      directBlocks: Bool,
      selectable: Bool,
      clearCache: Bool
    ) {
      let width: CGFloat = 400
      _BulletedListLayoutDebug.reset(clearProbeCache: clearCache, enabled: true)
      defer { _ = _BulletedListLayoutDebug.stop() }

      // Build streaming prefixes ~24 chars per step, ending with fullText.
      var prefixes: [String] = []
      var idx = fullText.startIndex
      while idx < fullText.endIndex {
        idx = fullText.index(idx, offsetBy: 28, limitedBy: fullText.endIndex) ?? fullText.endIndex
        prefixes.append(String(fullText[..<idx]))
      }

      #if canImport(UIKit)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 900))
        let parent = UIViewController()
        window.rootViewController = parent
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        var measuredHeight: CGFloat = 10
        weak var weakHost: UIHostingController<AnyView>?
        var heightCorrections = 0

        let makeRoot: (String) -> AnyView = { text in
          AnyView(
            self.makeHostedMarkdown(
              text,
              directBlocks: directBlocks,
              selectable: selectable,
              onHeightReport: { reported in
                let rounded = max(0, reported.rounded(.up))
                if abs(measuredHeight - rounded) > 0.5 {
                  heightCorrections += 1
                  measuredHeight = rounded
                  weakHost?.view.frame = CGRect(x: 0, y: 0, width: width, height: max(1, measuredHeight))
                  weakHost?.view.setNeedsLayout()
                }
              }
            )
          )
        }

        let host = UIHostingController(rootView: makeRoot(prefixes[0]))
        weakHost = host
        if #available(iOS 16.0, *) {
          host.sizingOptions = []
        }
        if #available(iOS 16.4, *) {
          host.safeAreaRegions = []
        }
        parent.addChild(host)
        parent.view.addSubview(host.view)
        host.didMove(toParent: parent)
        defer {
          host.willMove(toParent: nil)
          host.view.removeFromSuperview()
          host.removeFromParent()
        }

        for prefix in prefixes {
          host.rootView = makeRoot(prefix)
          let fitting = host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
          measuredHeight = max(1, fitting.height.rounded(.up))
          host.view.frame = CGRect(x: 0, y: 0, width: width, height: measuredHeight)
          host.view.setNeedsLayout()
          host.view.layoutIfNeeded()
          RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.004))
        }

        let afterStream = _BulletedListLayoutDebug.snapshot()
        // Let the run loop sit completely idle for 300ms (20 ticks x 15ms) and verify convergence.
        var perTickCounts: [Int] = []
        for _ in 0..<20 {
          let beforeTick = _BulletedListLayoutDebug.snapshot().sizeThatFitsCalls
          RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.015))
          let afterTick = _BulletedListLayoutDebug.snapshot().sizeThatFitsCalls
          perTickCounts.append(afterTick - beforeTick)
        }
        let afterIdle = _BulletedListLayoutDebug.snapshot()
        let idleDelta = afterIdle.sizeThatFitsCalls - afterStream.sizeThatFitsCalls
        print(
          "[CONVERGE-IOS] \(name) direct=\(directBlocks) sel=\(selectable) cold=\(clearCache) stream=\(afterStream) idleDelta=\(idleDelta) corr=\(heightCorrections) ticks=\(perTickCounts)"
        )
        XCTAssertLessThanOrEqual(
          idleDelta,
          4,
          "Non-converging layout on iOS for \(name) direct=\(directBlocks) sel=\(selectable) cold=\(clearCache): idleDelta=\(idleDelta) ticks=\(perTickCounts)"
        )
      #elseif canImport(AppKit)
        let window = NSWindow(
          contentRect: NSRect(x: 0, y: 0, width: width, height: 900),
          styleMask: [.borderless],
          backing: .buffered,
          defer: false
        )
        var measuredHeight: CGFloat = 10
        weak var weakHost: NSHostingView<AnyView>?
        var heightCorrections = 0

        let makeRoot: (String) -> AnyView = { text in
          AnyView(
            self.makeHostedMarkdown(
              text,
              directBlocks: directBlocks,
              selectable: selectable,
              onHeightReport: { reported in
                let rounded = max(0, reported.rounded(.up))
                if abs(measuredHeight - rounded) > 0.5 {
                  heightCorrections += 1
                  measuredHeight = rounded
                  weakHost?.frame = NSRect(x: 0, y: 0, width: width, height: max(1, measuredHeight))
                  weakHost?.needsLayout = true
                }
              }
            )
          )
        }

        let host = NSHostingView(rootView: makeRoot(prefixes[0]))
        weakHost = host
        if #available(macOS 13.0, *) {
          host.sizingOptions = []
        }
        window.contentView = host
        defer { window.contentView = nil }

        for prefix in prefixes {
          host.rootView = makeRoot(prefix)
          host.frame = NSRect(x: 0, y: 0, width: width, height: 2400)
          host.layoutSubtreeIfNeeded()
          let fitting = host.fittingSize
          measuredHeight = max(1, fitting.height.rounded(.up))
          host.frame = NSRect(x: 0, y: 0, width: width, height: measuredHeight)
          host.layoutSubtreeIfNeeded()
          RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.004))
        }

        let afterStream = _BulletedListLayoutDebug.snapshot()
        var perTickCounts: [Int] = []
        for _ in 0..<20 {
          let beforeTick = _BulletedListLayoutDebug.snapshot().sizeThatFitsCalls
          RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.015))
          let afterTick = _BulletedListLayoutDebug.snapshot().sizeThatFitsCalls
          perTickCounts.append(afterTick - beforeTick)
        }
        let afterIdle = _BulletedListLayoutDebug.snapshot()
        let idleDelta = afterIdle.sizeThatFitsCalls - afterStream.sizeThatFitsCalls
        print(
          "[CONVERGE-MAC] \(name) direct=\(directBlocks) sel=\(selectable) cold=\(clearCache) stream=\(afterStream) idleDelta=\(idleDelta) corr=\(heightCorrections) ticks=\(perTickCounts)"
        )
        XCTAssertEqual(
          idleDelta,
          0,
          "Non-converging layout on macOS for \(name) direct=\(directBlocks) sel=\(selectable) cold=\(clearCache): idleDelta=\(idleDelta) ticks=\(perTickCounts)"
        )
      #endif
    }

    @MainActor
    func testColdMultiWidthContainerDoesNotReprobeOrThrashCache() {
      let nested = """
      - **Outer item one:**
        - Level 2 circle item one with `inline code` and wrapping words.
        - Level 2 circle item two:
          - Level 3 square item one with **bold** text.
          - Level 3 square item two.
      - **Outer item two:**
        - Second level 2 list sharing the same `BulletProbeKey` as the first level 2 list.
      """
      for directBlocks in [false, true] {
        _BulletedListLayoutDebug.reset(clearProbeCache: true, enabled: true)
        defer { _ = _BulletedListLayoutDebug.stop() }

        let root = DualWidthProbeLayout {
          Markdown(MarkdownContent(nested))
            .markdownTheme(self.makeTheme())
            .markdownBlockMargins(self.chatMargins)
            .markdownLightweightListMarkers(true)
            .markdownLightweightBlocks(true)
            .markdownCompactLayout(true)
            .markdownDirectBlocks(directBlocks)
            .markdownSoftBreakMode(.lineBreak)
        }

        #if canImport(UIKit)
          let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 420, height: 900))
          let vc = UIViewController()
          window.rootViewController = vc
          window.makeKeyAndVisible()
          defer { window.isHidden = true }

          let host = UIHostingController(rootView: root)
          if #available(iOS 16.0, *) { host.sizingOptions = [] }
          if #available(iOS 16.4, *) { host.safeAreaRegions = [] }
          vc.addChild(host)
          vc.view.addSubview(host.view)
          host.didMove(toParent: vc)
          defer {
            host.willMove(toParent: nil)
            host.view.removeFromSuperview()
            host.removeFromParent()
          }

          let s1 = host.sizeThatFits(in: CGSize(width: 400, height: .greatestFiniteMagnitude))
          host.view.frame = CGRect(x: 0, y: 0, width: 400, height: ceil(s1.height))
          host.view.setNeedsLayout()
          host.view.layoutIfNeeded()
          let afterFirstLayout = _BulletedListLayoutDebug.snapshot()
          // Repeat sizeThatFits + layout without content changes: multi-width cache must hit with 0 new measures or probe stores.
          _ = host.sizeThatFits(in: CGSize(width: 400, height: .greatestFiniteMagnitude))
          host.view.setNeedsLayout()
          host.view.layoutIfNeeded()
          RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
          let afterSecondLayout = _BulletedListLayoutDebug.snapshot()
        #elseif canImport(AppKit)
          let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 900),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
          )
          let host = NSHostingView(rootView: root)
          if #available(macOS 13.0, *) { host.sizingOptions = [] }
          window.contentView = host
          defer { window.contentView = nil }
          host.frame = NSRect(x: 0, y: 0, width: 400, height: 900)
          host.layoutSubtreeIfNeeded()
          let afterFirstLayout = _BulletedListLayoutDebug.snapshot()
          host.needsLayout = true
          host.layoutSubtreeIfNeeded()
          RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
          let afterSecondLayout = _BulletedListLayoutDebug.snapshot()
        #endif

        // Only 2 compact bulleted list levels exist here (level 2 circle and level 3 square; level 1 has nested children),
        // so cold probe storage must run at most once per unique level (<= 2), never per width probe or per list instance.
        XCTAssertLessThanOrEqual(afterFirstLayout.probeStoreCalls, 2)
        XCTAssertEqual(afterSecondLayout.probeStoreCalls, afterFirstLayout.probeStoreCalls)
        XCTAssertEqual(afterSecondLayout.measureCalls, afterFirstLayout.measureCalls)
      }
    }
  }

  @available(iOS 16.0, macOS 13.0, *)
  private struct DualWidthProbeLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
      guard let child = subviews.first else { return .zero }
      let totalWidth = proposal.width ?? 400
      let side = child.sizeThatFits(ProposedViewSize(width: totalWidth - 108, height: nil))
      let under = child.sizeThatFits(ProposedViewSize(width: totalWidth - 27, height: nil))
      return CGSize(width: totalWidth, height: min(side.height + 26, under.height + 28))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
      guard let child = subviews.first else { return }
      let side = child.sizeThatFits(ProposedViewSize(width: bounds.width - 108, height: nil))
      let under = child.sizeThatFits(ProposedViewSize(width: bounds.width - 27, height: nil))
      let useUnder = under.height + 28 < side.height + 26
      let width = useUnder ? (bounds.width - 27) : (bounds.width - 108)
      let height = useUnder ? under.height : side.height
      child.place(
        at: bounds.origin,
        anchor: .topLeading,
        proposal: ProposedViewSize(width: width, height: height)
      )
    }
  }

  @available(iOS 16.0, macOS 13.0, *)
  private struct RowIdealTopLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
      let ideal = subviews.first?.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil)) ?? .zero
      let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? ideal.width
      if let height = proposal.height, height.isFinite, height < 1_000_000 {
        return CGSize(width: width, height: height)
      }
      return CGSize(width: width, height: ideal.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
      guard let row = subviews.first else { return }
      let size = row.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
      row.place(
        at: bounds.origin,
        anchor: .topLeading,
        proposal: ProposedViewSize(width: bounds.width, height: size.height)
      )
    }
  }

  private struct RowHeightPrefKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
      value = max(value, nextValue())
    }
  }
#endif
