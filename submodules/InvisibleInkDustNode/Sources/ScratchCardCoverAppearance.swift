import UIKit
import AppBundle
import Display

public extension ScratchCardCover {
    var placeholderColor: UIColor {
        switch self {
        case .plain: return UIColor(rgb: wallpaperColors[0])
        case .like: return UIColor(red: 0.17, green: 0.35, blue: 0.58, alpha: 1)
        case .dislike: return UIColor(red: 0.28, green: 0.32, blue: 0.43, alpha: 1)
        case .heart: return UIColor(red: 0.58, green: 0.22, blue: 0.36, alpha: 1)
        case .fire: return UIColor(red: 0.66, green: 0.31, blue: 0.15, alpha: 1)
        case .party: return UIColor(red: 0.39, green: 0.25, blue: 0.62, alpha: 1)
        case .poop: return UIColor(red: 0.39, green: 0.30, blue: 0.24, alpha: 1)
        }
    }

    func artwork() -> UIImage? { return UIImage(bundleImageName: assetName) }

    func previewImage() -> UIImage {
        return UIGraphicsImageRenderer(size: CGSize(width: 36, height: 36)).image { renderer in
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 36, height: 36), cornerRadius: 8).addClip()
            UIColor(rgb: stickerColors[0]).setFill()
            renderer.fill(CGRect(x: 0, y: 0, width: 36, height: 36))
            if self == .plain {
                let image = UIImage(systemName: "rectangle.dashed")?.withTintColor(.white, renderingMode: .alwaysOriginal)
                image?.draw(in: CGRect(x: 7, y: 8, width: 22, height: 20))
            } else if let image = artwork() {
                image.draw(in: CGRect(x: 0, y: 0, width: 36, height: 36))
            } else {
                let objects = stickerObjects
                ScratchStickerArtwork.image(for: objects[0]).draw(in: CGRect(x: -2, y: -1, width: 27, height: 27))
                ScratchStickerArtwork.image(for: objects[min(1, objects.count - 1)]).draw(in: CGRect(x: 15, y: 13, width: 25, height: 25))
            }
        }
    }

    func placeholderPattern() -> UIImage {
        return UIGraphicsImageRenderer(size: CGSize(width: 180, height: 240)).image { renderer in
            renderer.cgContext.setAlpha(0.14)
            for row in 0 ..< 4 {
                for column in 0 ..< 3 {
                    let point = CGPoint(x: CGFloat(column * 72 - (row % 2) * 24), y: CGFloat(row * 72 + 8))
                    (emoji as NSString).draw(at: point, withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
                }
            }
        }
    }
}
