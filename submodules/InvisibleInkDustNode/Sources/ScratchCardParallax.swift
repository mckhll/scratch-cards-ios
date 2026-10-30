import CoreGraphics

/// One clipped plane for the photograph, coating and stickers. Bounded shear,
/// rotation and moving light create depth without crossing sibling z-planes.
enum ScratchCardParallax {
    static func transform(at point: CGPoint, size: CGSize, reduceMotion: Bool) -> CGAffineTransform {
        guard !reduceMotion, size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0, point.x.isFinite, point.y.isFinite else { return .identity }
        let x = min(1, max(-1, point.x / size.width * 2 - 1))
        let y = min(1, max(-1, point.y / size.height * 2 - 1))
        return CGAffineTransform(a: 1 - abs(y) * 0.014, b: y * 0.018, c: -x * 0.022, d: 1 - abs(x) * 0.014, tx: x * 4, ty: y * 4)
            .rotated(by: x * 0.045 + y * 0.012)
    }
}
