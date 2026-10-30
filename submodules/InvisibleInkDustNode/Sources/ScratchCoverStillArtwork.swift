import UIKit

/// Closed chat cards share one baked texture instead of dozens of shadowed layers.
/// The same layout and runtime emoji artwork are used by the interactive scene.
enum ScratchCoverStillArtwork {
    private static let queue = DispatchQueue(label: "org.telegram.scratch-cover-stickers", qos: .userInitiated)
    // Accessed only by the main-thread request/publish path. Identical requests
    // from picker, sending message and chat cells share a single rasterization.
    private static var pending: [String: [(UIImage?) -> Void]] = [:]
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        cache.countLimit = 24
        return cache
    }()

    static func requestImage(cover: ScratchCardCover, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        assert(Thread.isMainThread)
        guard let layout = layout(cover: cover, size: size) else { completion(nil); return }
        if pending[layout.key] != nil {
            pending[layout.key]?.append(completion)
            return
        }
        if let image = cache.object(forKey: layout.key as NSString) { completion(image); return }
        pending[layout.key] = [completion]
        queue.async {
            let image = autoreleasepool { Self.image(cover: cover, size: size) }
            DispatchQueue.main.async {
                let callbacks = pending.removeValue(forKey: layout.key) ?? []
                callbacks.forEach { $0(image) }
            }
        }
    }

    private static func layout(cover: ScratchCardCover, size: CGSize) -> (key: String, canvas: CGSize)? {
        guard cover.hasThemedEffects, size.width.isFinite, size.height.isFinite,
              size.width > 6, size.height > 6 else { return nil }
        let height = min(3600, max(1, Int((360 * size.height / size.width).rounded())))
        return ("\(cover.rawValue):\(height)", CGSize(width: 360, height: CGFloat(height)))
    }

    static func image(cover: ScratchCardCover, size: CGSize) -> UIImage? {
        guard let layout = layout(cover: cover, size: size) else { return nil }
        let key = layout.key as NSString
        if let image = cache.object(forKey: key) { return image }
        let canvas = layout.canvas
        let model = ScratchStickerLayout(size: canvas, seed: 271021 + UInt64(cover.rawValue) * 7919, objectCount: cover.stickerObjects.count)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { renderer in
            let context = renderer.cgContext
            for sticker in model.stickers {
                context.saveGState()
                context.translateBy(x: sticker.home.x, y: sticker.home.y)
                context.rotate(by: sticker.angle)
                context.setShadow(offset: CGSize(width: 0, height: 2), blur: 3,
                    color: UIColor(red: 0.25, green: 0.08, blue: 0.22, alpha: 0.16).cgColor)
                ScratchStickerArtwork.image(for: cover.stickerObjects[sticker.index]).draw(in: CGRect(x: -sticker.size / 2, y: -sticker.size / 2, width: sticker.size, height: sticker.size))
                context.restoreGState()
            }
        }
        cache.setObject(image, forKey: key, cost: (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0))
        return image
    }
}
