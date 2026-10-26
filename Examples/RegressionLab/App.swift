import SwiftUI
@testable import MarkdownUI

@main
struct MarkdownRegressionLab: App {
    var body: some Scene { WindowGroup { FixtureView() } }
}

private struct FixtureView: View {
    @State private var fixture: MarkdownFixture = {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--fixture"), args.indices.contains(index + 1) {
            return MarkdownFixture(rawValue: args[index + 1]) ?? .spacing
        }
        return .spacing
    }()
    @State private var largeText = false
    @State private var revision = 0
    @State private var openedLink = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                if !openedLink.isEmpty { Text(openedLink).accessibilityIdentifier("lab.openedLink") }
                if fixture == .dynamicType {
                    Text("Reference").font(.body).accessibilityIdentifier("lab.referenceText")
                }
                Markdown(fixture.source + (revision == 0 ? "" : "\n\nUpdate \(revision)"))
                    .markdownTheme(.gitHub)
                    .markdownSoftBreakMode(.lineBreak)
                    .textSelection(.enabled)
                    .markdownImageProvider(FixtureImageProvider())
                    .markdownInlineImageProvider(FixtureInlineImageProvider())
                    .environment(\.openURL, OpenURLAction { url in
                        openedLink = "Opened " + (url.host ?? url.absoluteString)
                        return .handled
                    })
                    .frame(maxWidth: 320, alignment: .leading)
                    .padding(16)
            }
            .dynamicTypeSize(largeText ? .accessibility3 : .large)
            .navigationTitle("Markdown Lab")
            .toolbar {
                Menu("Fixture") {
                    Picker("Fixture", selection: $fixture) {
                        ForEach(MarkdownFixture.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Button("Larger text") { largeText.toggle() }
                    .accessibilityIdentifier("lab.largerText")
                Button("Update") { revision += 1 }
                    .accessibilityIdentifier("lab.update")
            }
        }
    }
}

private enum FixtureImage {
    static let large = make(width: 1_600, height: 800)
    static let small = make(width: 24, height: 20)

    static func make(width: Int, height: Int) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height,
                                bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    static func image(_ url: URL?) -> CGImage { url?.host == "small" ? small : large }
}

private struct FixtureImageProvider: ImageProvider {
    func makeImage(url: URL?) -> some View {
        let image = FixtureImage.image(url)
        return ResizeToFit(idealSize: CGSize(width: image.width, height: image.height)) {
            Image(decorative: image, scale: 1).resizable()
        }
    }
}

private struct FixtureInlineImageProvider: InlineImageProvider {
    func image(with url: URL, label: String) async throws -> Image {
        Image(FixtureImage.image(url), scale: 1, label: Text(label))
    }
}
