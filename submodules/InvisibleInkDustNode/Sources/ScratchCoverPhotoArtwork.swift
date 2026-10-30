import UIKit
import FastBlur

/// Only a strongly blurred luminance thumbnail reaches the cover. Original colours
/// and small details never appear through its opaque, theme-coloured backing.
enum ScratchCoverPhotoArtwork {
    static let queue = DispatchQueue(label: "org.telegram.scratch-cover-photo", qos: .userInitiated)

    static func image(photo: UIImage, cover: ScratchCardCover) -> UIImage? {
        guard photo.size.width > 0, photo.size.height > 0 else { return nil }
        let scale = 64 / max(photo.size.width, photo.size.height)
        let width = max(8, Int((photo.size.width * scale).rounded()))
        let height = max(8, Int((photo.size.height * scale).rounded()))
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let thumbnail = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            UIColor(white: 0.5, alpha: 1).setFill()
            renderer.fill(CGRect(origin: .zero, size: size))
            photo.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let image = thumbnail.cgImage else { return nil }
        let stride = width * 4
        var pixels = [UInt8](repeating: 0, count: stride * height)
        return pixels.withUnsafeMutableBytes { bytes -> UIImage? in
            guard let base = bytes.baseAddress,
                  let context = CGContext(data: base, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: stride, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.draw(image, in: CGRect(origin: .zero, size: size))
            // Same CPU blur used by Telegram's media picker, on at most 64×64 pixels.
            imageFastBlur(Int32(width), Int32(height), Int32(stride), base)
            imageFastBlur(Int32(width), Int32(height), Int32(stride), base)
            imageFastBlur(Int32(width), Int32(height), Int32(stride), base)
            let data = bytes.bindMemory(to: UInt8.self)
            var luma = [CGFloat](repeating: 0, count: width * height)
            var mean: CGFloat = 0
            for index in luma.indices {
                let offset = index * 4
                let value = (CGFloat(data[offset]) * 0.2126 + CGFloat(data[offset + 1]) * 0.7152 + CGFloat(data[offset + 2]) * 0.0722) / 255
                luma[index] = value
                mean += value
            }
            mean /= CGFloat(luma.count)
            let colors = cover.stickerColors
            for y in 0 ..< height {
                for x in 0 ..< width {
                    let index = y * width + x
                    let t = (CGFloat(x) / CGFloat(max(1, width - 1)) + CGFloat(y) / CGFloat(max(1, height - 1))) * 0.5
                    let segment = t < 0.55 ? 0 : 1
                    let mix = segment == 0 ? t / 0.55 : (t - 0.55) / 0.45
                    // Add bounded light, rather than multiplying: a dark Plain
                    // palette must retain the same perceptible broad contours.
                    let light = min(42, max(-42, (luma[index] - mean) * 105))
                    for (channel, shift) in [16, 8, 0].enumerated() {
                        let a = CGFloat((colors[segment] >> shift) & 255)
                        let b = CGFloat((colors[segment + 1] >> shift) & 255)
                        data[index * 4 + channel] = UInt8(min(255, max(0, (a + (b - a) * mix + light).rounded())))
                    }
                    data[index * 4 + 3] = 255
                }
            }
            return context.makeImage().map { UIImage(cgImage: $0) }
        }
    }

    /// Shared small tile: no particle simulation or per-card random generation.
    static let grain: UIImage = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        var seed: UInt32 = 74191
        func random() -> CGFloat {
            seed = seed &* 1664525 &+ 1013904223
            return CGFloat(seed) / CGFloat(UInt32.max)
        }
        return UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96), format: format).image { renderer in
            for _ in 0 ..< 1800 {
                let x = random() * 96, y = random() * 96
                let side = 0.4 + random() * 0.55
                let white = random() > 0.2
                renderer.cgContext.setFillColor(UIColor(white: white ? 1 : 0, alpha: 0.05 + random() * 0.13).cgColor)
                renderer.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: side, height: side))
            }
        }
    }()
}
