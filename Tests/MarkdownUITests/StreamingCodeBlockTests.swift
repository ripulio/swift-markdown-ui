#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import MarkdownUI

/// Exercise the real SwiftUI tree: a value-based ForEach recreates both probes
/// when either the enclosing list item or the trailing code block changes.
final class StreamingCodeBlockTests: XCTestCase {
  @MainActor
  func testStreamingKeepsCodeViewsAndIndependentNestedPaths() {
    let model = Model()
    let recorder = Recorder()
    let host = NSHostingView(rootView: Fixture(model: model, recorder: recorder))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host
    defer { window.contentView = nil }
    pump(host)

    XCTAssertEqual(recorder.created.count, 2)
    let initialPaths = Set(recorder.created)
    XCTAssertEqual(initialPaths.count, 2)
    XCTAssertTrue(initialPaths.contains { $0.count > 1 }, "Nested code needs its full path")
    XCTAssertEqual(Set(recorder.languages.values), ["swift"])

    model.tail = "123456"
    pump(host)

    XCTAssertEqual(recorder.created.count, 2, "Streaming must update existing code views")
    XCTAssertEqual(Set(recorder.sources.keys), initialPaths)
    XCTAssertTrue(recorder.sources.values.allSatisfy { $0.contains("123456") })
  }

  @MainActor
  private func pump(_ view: NSView) {
    for _ in 0..<5 {
      view.layoutSubtreeIfNeeded()
      RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
    }
  }
}

private final class Model: ObservableObject {
  @Published var tail = "1"
  var source: String {
    "1. Example\n\n   ```swift title=Example.swift\n   let nested = \(tail)\n   ```\n\n```swift\nlet outer = \(tail)\n```"
  }
}

private final class Recorder {
  var created: [[Int]] = []
  var sources: [[Int]: String] = [:]
  var languages: [[Int]: String] = [:]
}

private struct Fixture: View {
  @ObservedObject var model: Model
  let recorder: Recorder
  var body: some View {
    Markdown(model.source)
      .markdownBlockStyle(\.codeBlock) { configuration in
        Probe(configuration: configuration, recorder: recorder).frame(height: 30)
      }
      .frame(width: 480)
  }
}

private struct Probe: NSViewRepresentable {
  let configuration: CodeBlockConfiguration
  let recorder: Recorder
  func makeNSView(context: Context) -> NSView {
    recorder.created.append(configuration.blockPath)
    return NSView()
  }
  func updateNSView(_ view: NSView, context: Context) {
    recorder.sources[configuration.blockPath] = configuration.content
    recorder.languages[configuration.blockPath] = configuration.language
  }
}
#endif
