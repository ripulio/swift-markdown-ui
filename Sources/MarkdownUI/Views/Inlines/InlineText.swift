import SwiftUI

struct InlineText: View {
  @Environment(\.lightweightBlocks) private var lightweightBlocks
  @Environment(\.baseURL) private var baseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.theme) private var theme
  @Environment(\.multilineTextAlignment) private var alignment
  @Environment(\.lineSpacing) private var lineSpacing
  @Environment(\.inlineImageFlow) private var inlineImageFlow
  @Environment(\.textStyleAttributes) private var textStyleAttributes

  private let inlines: [InlineNode]
  private let hasImages: Bool

  init(_ inlines: [InlineNode]) {
    self.inlines = inlines
    self.hasImages = inlines.contains(where: \.containsImage)
  }

  var body: some View {
    if self.lightweightBlocks, !self.hasImages {
      self.lightweightTextBody
    } else if self.hasImages, self.inlineImageFlow,
      #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *),
      let flow = ImageFlow(self.inlines)
    {
      flow
    } else {
      InlineTextWithImages(inlines: self.inlines)
    }
  }

  @ViewBuilder private var lightweightTextBody: some View {
    let chunks = self.inlines.textChunks(softBreakMode: self.softBreakMode)
    let styles = InlineTextStyles(
      code: self.theme.code,
      emphasis: self.theme.emphasis,
      strong: self.theme.strong,
      strikethrough: self.theme.strikethrough,
      link: self.theme.link
    )
    if chunks.count == 1 {
      chunks[0].renderText(
        baseURL: self.baseURL,
        textStyles: styles,
        images: [:],
        softBreakMode: self.softBreakMode,
        attributes: self.textStyleAttributes,
        preResolveFonts: true
      )
    } else {
      VStack(alignment: self.alignment.alignment.horizontal, spacing: self.lineSpacing) {
        ForEach(chunks.indices, id: \.self) { index in
          chunks[index].renderText(
            baseURL: self.baseURL,
            textStyles: styles,
            images: [:],
            softBreakMode: self.softBreakMode,
            attributes: self.textStyleAttributes,
            preResolveFonts: true
          )
        }
      }
    }
  }
}

private struct InlineTextWithImages: View {
  @Environment(\.inlineImageProvider) private var inlineImageProvider
  @Environment(\.baseURL) private var baseURL
  @Environment(\.imageBaseURL) private var imageBaseURL
  @Environment(\.softBreakMode) private var softBreakMode
  @Environment(\.theme) private var theme
  @Environment(\.multilineTextAlignment) private var alignment
  @Environment(\.lineSpacing) private var lineSpacing
  @Environment(\.lightweightBlocks) private var lightweightBlocks

  @State private var inlineImages: [String: Image] = [:]

  let inlines: [InlineNode]

  var body: some View {
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
            attributes: attributes,
            preResolveFonts: self.lightweightBlocks
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
