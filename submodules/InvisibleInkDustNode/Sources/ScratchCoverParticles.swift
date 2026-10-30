import UIKit
import Display

/// Small local fragments, never a screen-filling emitter. All animation is planar.
enum ScratchCoverParticles {
    static func emit(in container: CALayer, at point: CGPoint, cover: ScratchCardCover, count: Int = 3) {
        guard cover.hasThemedEffects else { return }
        let active = container.sublayers?.filter { $0.name == "scratch-fragment" }.count ?? 0
        guard active < 64 else { return }
        for index in 0 ..< min(count, 64 - active) {
            let particle = CAShapeLayer()
            particle.name = "scratch-fragment"
            let size = CGFloat.random(in: 2 ... 4)
            var path = UIBezierPath()
            switch cover {
            case .plain: return
            case .party:
                path = UIBezierPath(roundedRect: CGRect(x: -size, y: -size * 0.4, width: size * 2, height: size * 0.8), cornerRadius: 0.4)
            case .heart:
                path.move(to: CGPoint(x: 0, y: size))
                path.addCurve(to: CGPoint(x: -size, y: -size * 0.4), controlPoint1: CGPoint(x: -size * 0.3, y: size * 0.4), controlPoint2: CGPoint(x: -size * 1.6, y: 0))
                path.addCurve(to: CGPoint(x: 0, y: -size * 0.45), controlPoint1: CGPoint(x: -size, y: -size * 1.4), controlPoint2: CGPoint(x: -size * 0.2, y: -size * 1.4))
                path.addCurve(to: CGPoint(x: size, y: -size * 0.4), controlPoint1: CGPoint(x: size * 0.2, y: -size * 1.4), controlPoint2: CGPoint(x: size, y: -size * 1.4))
                path.addCurve(to: CGPoint(x: 0, y: size), controlPoint1: CGPoint(x: size * 1.6, y: 0), controlPoint2: CGPoint(x: size * 0.3, y: size * 0.4))
                path.close()
            case .like:
                path.move(to: CGPoint(x: 0, y: -size));path.addLine(to: CGPoint(x: size * 0.3, y: -size * 0.3));path.addLine(to: CGPoint(x: size, y: 0));path.addLine(to: CGPoint(x: size * 0.3, y: size * 0.3));path.addLine(to: CGPoint(x: 0, y: size));path.addLine(to: CGPoint(x: -size * 0.3, y: size * 0.3));path.addLine(to: CGPoint(x: -size, y: 0));path.addLine(to: CGPoint(x: -size * 0.3, y: -size * 0.3));path.close()
            case .dislike:
                path.move(to: CGPoint(x: -size, y: -size * 0.3));path.addLine(to: CGPoint(x: size, y: -size));path.addLine(to: CGPoint(x: size * 0.5, y: size * 0.5));path.close()
            case .fire:
                path = UIBezierPath(ovalIn: CGRect(x: -size * 0.35, y: -size, width: size * 0.7, height: size * 2))
            case .poop:
                path = UIBezierPath(ovalIn: CGRect(x: -size * 0.5, y: -size * 0.5, width: size, height: size))
            }
            let colors: [UIColor]
            switch cover {
            case .plain: return
            case .like: colors = [.white, UIColor(rgb: 0xa5e8de), UIColor(rgb: 0x9fcaff)]
            case .dislike: colors = [UIColor(rgb: 0xc3cbdc), UIColor(rgb: 0xd6a3b2)]
            case .heart: colors = [UIColor(rgb: 0xffb0d1), UIColor(rgb: 0xf4c1ed)]
            case .fire: colors = [UIColor(rgb: 0xffcc77), UIColor(rgb: 0xff9674)]
            case .party: colors = [UIColor(rgb: 0xa8b9ff), UIColor(rgb: 0xefacdc), UIColor(rgb: 0xf2d692), UIColor(rgb: 0xa6ddd1)]
            case .poop: colors = [UIColor(rgb: 0xd5bd9c), UIColor(rgb: 0xbecba8)]
            }
            particle.path = path.cgPath
            particle.fillColor = colors[index % colors.count].withAlphaComponent(0.8).cgColor
            particle.position = point
            particle.opacity = 0
            container.addSublayer(particle)
            let rise: CGFloat = cover == .fire || cover == .heart ? -65 : 25
            let drift = CGFloat.random(in: -32 ... 32)
            let flight = CAKeyframeAnimation(keyPath: "position")
            flight.values = [NSValue(cgPoint: point), NSValue(cgPoint: CGPoint(x: point.x + drift * 0.5, y: point.y - 18)), NSValue(cgPoint: CGPoint(x: point.x + drift, y: point.y + rise))]
            let fade = CABasicAnimation(keyPath: "opacity");fade.fromValue = 0.85;fade.toValue = 0
            let rotation = CABasicAnimation(keyPath: "transform.rotation.z");rotation.fromValue = CGFloat.random(in: -1 ... 1);rotation.toValue = CGFloat.random(in: -3 ... 3)
            let group = CAAnimationGroup();group.animations = [flight, fade, rotation];group.duration = cover == .heart ? 0.8 : 0.6;group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            particle.add(group, forKey: "fragment")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { particle.removeFromSuperlayer() }
        }
    }
}
