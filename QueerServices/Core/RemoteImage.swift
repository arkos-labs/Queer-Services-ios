import SwiftUI
import UIKit

/// Image distante avec cache mémoire et décodage réduit à la taille affichée :
/// elle apparaît vite et ne fait pas saccader la liste (AsyncImage retélécharge et décode en pleine résolution).
struct RemoteImage<Placeholder: View>: View {
    let url: URL
    /// Plus grand côté en pixels : 240 pour un avatar, 900 pour une photo d'événement.
    var maxPixel: CGFloat = 600
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                placeholder()
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        let key = "\(url.absoluteString)|\(Int(maxPixel))" as NSString
        if let cached = RemoteImageCache.store.object(forKey: key) {
            image = cached
            return
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let decoded = RemoteImageCache.downsample(data, maxPixel: maxPixel)
        else { return }
        RemoteImageCache.store.setObject(decoded, forKey: key)
        withAnimation(.easeOut(duration: 0.2)) { image = decoded }
    }
}

enum RemoteImageCache {
    static let store: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 300
        return cache
    }()

    static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
