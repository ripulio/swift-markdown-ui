import SwiftUI

struct ListBullet: View {
  fileprivate let image: Image

  var body: some View {
    TextStyleAttributesReader { attributes in
      let fontSize = attributes.fontProperties?.scaledSize ?? FontProperties.defaultSize
      self.image.font(.system(size: round(fontSize / 3)))
    }
  }

  func markerFrame() -> some View {
    BulletMarkerFrame(image: self.image)
  }

  static var disc: Self {
    .init(image: .init(systemName: "circle.fill"))
  }

  static var circle: Self {
    .init(image: .init(systemName: "circle"))
  }

  static var square: Self {
    .init(image: .init(systemName: "square.fill"))
  }
}

private struct BulletMarkerFrame: View {
  @Environment(\.lightweightListMarkers) private var lightweightListMarkers
  let image: Image

  var body: some View {
    if self.lightweightListMarkers {
      TextStyleAttributesReader { attributes in
        let fontSize = attributes.fontProperties?.scaledSize ?? FontProperties.defaultSize
        self.image
          .font(.system(size: round(fontSize / 3)))
          .frame(minWidth: round(1.5 * fontSize), alignment: .trailing)
      }
    } else {
      ListBullet(image: self.image)
        .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
    }
  }
}
