import UIKit

/// Runtime emoji rendering, with a paper edge. No exported system emoji bitmaps are shipped.
enum ScratchStickerArtwork {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 48
        return cache
    }()

    static func image(for emoji: String) -> UIImage {
        if let image = cache.object(forKey: emoji as NSString) { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let glyph = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128), format: format).image { _ in
            let text = NSAttributedString(string: emoji, attributes: [.font: UIFont.systemFont(ofSize: 108)])
            let size = text.size()
            text.draw(at: CGPoint(x: (128 - size.width) / 2, y: (128 - size.height) / 2))
        }
        let silhouette = UIGraphicsImageRenderer(size: glyph.size, format: format).image { context in
            glyph.draw(at: .zero)
            context.cgContext.setBlendMode(.sourceIn)
            UIColor(white: 1, alpha: 1).setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: glyph.size))
        }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 144, height: 144), format: format).image { _ in
            for index in 0 ..< 16 {
                let angle = CGFloat(index) / 16 * .pi * 2
                silhouette.draw(at: CGPoint(x: 8 + cos(angle) * 5, y: 8 + sin(angle) * 5))
            }
            glyph.draw(at: CGPoint(x: 8, y: 8))
        }
        cache.setObject(image, forKey: emoji as NSString)
        return image
    }
}
