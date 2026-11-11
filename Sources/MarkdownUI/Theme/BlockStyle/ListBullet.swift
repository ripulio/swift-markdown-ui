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

  static func builtinImage(
    for marker: BlockStyle<ListMarkerConfiguration>.BuiltinBulletMarker,
    listLevel: Int
  ) -> Image {
    switch marker {
    case .disc:
      return Self.disc.image
    case .circle:
      return Self.circle.image
    case .square:
      return Self.square.image
    case .discCircleSquare:
      switch min(listLevel, 3) {
      case 1:
        return Self.disc.image
      case 2:
        return Self.circle.image
      default:
        return Self.square.image
      }
    }
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
