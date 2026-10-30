import UIKit

/// A passive demonstration; it never erases the actual cover or intercepts touches.
final class ScratchGestureHintView: UIView {
    private let backing = UIView()
    private let hand = UIImageView(image: UIImage(systemName: "hand.draw.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 52, weight: .regular)))
    private let trail = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        alpha = 0
        backing.backgroundColor = UIColor(white: 0, alpha: 0.32)
        backing.layer.cornerRadius = 48
        backing.layer.cornerCurve = .continuous
        backing.layer.borderWidth = 0.5
        backing.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
        addSubview(backing)
        trail.fillColor = UIColor.clear.cgColor
        trail.strokeColor = UIColor.white.withAlphaComponent(0.7).cgColor
        trail.lineWidth = 3
        trail.lineCap = .round
        trail.lineDashPattern = [2, 7]
        layer.addSublayer(trail)
        hand.tintColor = .white
        hand.contentMode = .center
        hand.layer.shadowColor = UIColor.black.cgColor
        hand.layer.shadowOpacity = 0.4
        hand.layer.shadowRadius = 8
        hand.layer.shadowOffset = CGSize(width: 0, height: 2)
        addSubview(hand)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        backing.frame = CGRect(x: bounds.midX - 58, y: bounds.midY - 48, width: 116, height: 96)
        hand.bounds = CGRect(x: 0, y: 0, width: 72, height: 72)
        hand.center = CGPoint(x: bounds.midX, y: bounds.midY)
        trail.frame = bounds
        let path = UIBezierPath()
        path.move(to: CGPoint(x: bounds.midX - 33, y: bounds.midY - 17))
        path.addQuadCurve(to: CGPoint(x: bounds.midX + 33, y: bounds.midY - 17), controlPoint: CGPoint(x: bounds.midX, y: bounds.midY - 30))
        trail.path = path.cgPath
    }

    func show() {
        guard alpha == 0 else { return }
        UIView.animate(withDuration: 0.18) { self.alpha = 1 }
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let motion = CAKeyframeAnimation(keyPath: "transform")
        motion.values = [-1.0, 1.0, -1.0].map { direction in
            NSValue(caTransform3D: CATransform3DMakeAffineTransform(CGAffineTransform(translationX: direction * 26, y: direction * -5).rotated(by: direction * 0.14)))
        }
        motion.keyTimes = [0, 0.5, 1]
        motion.timingFunctions = [CAMediaTimingFunction(name: .easeInEaseOut), CAMediaTimingFunction(name: .easeInEaseOut)]
        motion.duration = 1.4
        motion.repeatCount = .infinity
        hand.layer.add(motion, forKey: "scratchDemonstration")
    }

    func hide() {
        layer.removeAllAnimations()
        hand.layer.removeAllAnimations()
        alpha = 0
    }
}
