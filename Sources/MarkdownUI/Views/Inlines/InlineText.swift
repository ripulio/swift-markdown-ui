import SwiftUI

struct InlineText: View {
  @Environment(\.inlineImageProvider) private var inlineImageProvider
  @Environment(\.baseURL) private var baseURL
  @Environment(\.imageBaseURL) private var imageBaseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.theme) private var theme
  @Environment(\.multilineTextAlignment) private var alignment
  @Environment(\.lineSpacing) private var lineSpacing
  @Environment(\.inlineImageFlow) private var inlineImageFlow

  @State private var inlineImages: [String: Image] = [:]

  private let inlines: [InlineNode]

  init(_ inlines: [InlineNode]) {
    self.inlines = inlines
  }

  var body: some View {
    if self.inlineImageFlow, #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *),
      let flow = ImageFlow(self.inlines)
    {
      flow
    } else {
      self.textBody
    }
  }

  private var textBody: some View {
    TextStyleAttributesReader { attributes in
      let chunks = self.inlines.textChunks(softBreakMode: self.softBreakMode)
      VStack(alignment: self.alignment.alignment.horizontal, spacing: self.lineSpacing) {
        ForEach(chunks.indices, id: \.self) { index in
          chunks[index].renderText(
            baseURL: self.baseURL,
            textStyles: .init(
              code: self.theme.code,
              emphasis: self.theme.emphasis,
              strong: self.theme.strong,
              strikethrough: self.theme.strikethrough,
              link: self.theme.link
            ),
            images: self.inlineImages,
            softBreakMode: self.softBreakMode,
            attributes: attributes
          )
        }
      }
    }
    .task(id: self.inlines) {
      self.inlineImages = (try? await self.loadInlineImages()) ?? [:]
    }
  }

  private func loadInlineImages() async throws -> [String: Image] {
    let images = Set(self.inlines.compactMap(\.imageData))
    guard !images.isEmpty else { return [:] }

    return try await withThrowingTaskGroup(of: (String, Image).self) { taskGroup in
      for image in images {
        guard let url = URL(string: image.source, relativeTo: self.imageBaseURL) else {
          continue
        }

        taskGroup.addTask {
          (image.source, try await self.inlineImageProvider.image(with: url, label: image.alt))
        }
      }

      var inlineImages: [String: Image] = [:]

      for try await result in taskGroup {
        inlineImages[result.0] = result.1
      }

      return inlineImages
    }
  }
}
