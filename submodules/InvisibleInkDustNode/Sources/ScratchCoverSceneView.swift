import UIKit
import Display

/// The selected HTML study: attached paper stickers with a short, local peel.
final class ScratchCoverSceneView: UIView {
    private struct Sprite {
        let layer: CALayer
        let front: CALayer
        let fold: CAShapeLayer
    }
    private var cover: ScratchCardCover = .like
    private var model: ScratchStickerLayout?
    private var sprites: [Sprite] = []
    private var link: SharedDisplayLinkDriver.Link?
    private var active = false
    private var allowed = true
    private var interactive = false
    private var renderedSize = CGSize.zero
    private var renderedCover: ScratchCardCover?
    private var rasterGeneration = 0
    var liveStickerCount: Int { sprites.count }
    private var animated: Bool { allowed && !UIAccessibility.isReduceMotionEnabled }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        NotificationCenter.default.addObserver(self, selector: #selector(reduceMotionChanged), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        link?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func reduceMotionChanged() {
        if !animated { model?.setTouch(nil) }
        render()
        updateDriver()
    }

    func setCover(_ cover: ScratchCardCover) {
        guard self.cover != cover || renderedCover == nil else { return }
        self.cover = cover
        rebuild()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if renderedSize != bounds.size { rebuild() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateDriver()
    }

    private func rebuild() {
        rasterGeneration += 1
        let preserveContents = !interactive && renderedCover == cover
        renderedCover = cover
        renderedSize = bounds.size
        link?.invalidate()
        link = nil
        sprites.forEach { $0.layer.removeFromSuperlayer() }
        sprites.removeAll()
        model = nil
        if !preserveContents { layer.contents = nil }
        guard cover.hasThemedEffects, bounds.width > 6, bounds.height > 6 else { return }
        guard interactive else {
            let generation = rasterGeneration
            ScratchCoverStillArtwork.requestImage(cover: cover, size: bounds.size) { [weak self] image in
                guard let self, !self.interactive, self.rasterGeneration == generation else { return }
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.layer.contents = image?.cgImage
                self.layer.contentsScale = image?.scale ?? 2
                CATransaction.commit()
            }
            return
        }
        let model = ScratchStickerLayout(size: bounds.size, seed: 271021 + UInt64(cover.rawValue) * 7919, objectCount: cover.stickerObjects.count)
        self.model = model
        let objects = cover.stickerObjects
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for sticker in model.stickers {
            let image = ScratchStickerArtwork.image(for: objects[sticker.index % objects.count])
            let root = CALayer()
            root.bounds = CGRect(x: 0, y: 0, width: sticker.size, height: sticker.size)
            root.shadowColor = UIColor(red: 0.25, green: 0.08, blue: 0.22, alpha: 1).cgColor
            root.shadowOpacity = 0.16
            root.shadowRadius = 3
            root.shadowOffset = CGSize(width: 0, height: 2)
            let front = CALayer()
            front.contents = image.cgImage
            front.contentsScale = image.scale
            front.bounds = root.bounds
            front.anchorPoint = CGPoint(x: 0, y: 0.5)
            front.position = CGPoint(x: 0, y: sticker.size / 2)
            root.addSublayer(front)
            let fold = CAShapeLayer()
            fold.frame = root.bounds
            fold.fillColor = UIColor(red: 1, green: 0.96, blue: 0.98, alpha: 1).cgColor
            root.addSublayer(fold)
            layer.addSublayer(root)
            sprites.append(Sprite(layer: root, front: front, fold: fold))
        }
        CATransaction.commit()
        render()
        updateDriver()
    }

    func setMotionActive(_ active: Bool, allowed: Bool, interactive: Bool = false) {
        self.active = active
        self.allowed = allowed
        let changed = interactive && !self.interactive
        if interactive { self.interactive = true }
        if changed { rebuild() }
        updateDriver()
    }

    private func updateDriver() {
        let running = active && animated && model?.needsAnimation == true && window != nil && !isHidden
        if running && link == nil {
            link = SharedDisplayLinkDriver.shared.add(framesPerSecond: .fps(interactive ? 60 : 30), { [weak self] delta in
                guard let self else { return }
                self.model?.advance(delta)
                self.render()
                self.updateDriver()
            })
        } else if !running {
            link?.invalidate()
            link = nil
        }
    }

    func interact(at point: CGPoint, began: Bool) {
        guard animated else { return }
        model?.setTouch(point)
        updateDriver()
    }

    func scratch(from start: CGPoint, to end: CGPoint) {
        model?.peel(from: start, to: end, animated: animated)
        render()
        updateDriver()
    }

    func endInteraction() {
        model?.setTouch(nil)
        updateDriver()
    }

    func finish(at point: CGPoint) {
        model?.finish(at: point, animated: animated)
        render()
        updateDriver()
    }

    private func render() {
        guard let model else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (sticker, sprite) in zip(model.stickers, sprites) {
            let progress = sticker.peelStart.map { min(1, max(0, (model.time - $0) / ScratchStickerLayout.peelDuration)) } ?? 0
            let ease = 1 - pow(1 - progress, 3)
            let unit = model.size.width / 360
            let curl = max(sticker.curl, ease)
            sprite.layer.isHidden = sticker.removed
            sprite.layer.opacity = Float(1 - progress * progress)
            sprite.layer.zPosition = sticker.peelStart == nil ? 0 : 1
            sprite.layer.position = CGPoint(x: sticker.home.x + (sticker.direction.x * 24 + 20) * unit * ease, y: sticker.home.y - 110 * unit * ease * ease)
            sprite.layer.setAffineTransform(CGAffineTransform(rotationAngle: sticker.angle + progress * 0.75).scaledBy(x: 1 - progress * 0.6, y: 1 - progress * 0.6))
            sprite.layer.shadowRadius = (3 + curl * 5) * unit
            sprite.layer.shadowOffset = CGSize(width: 0, height: (2 + curl * 4) * unit)
            let front = 1 - curl * 0.7
            sprite.front.setAffineTransform(CGAffineTransform(scaleX: front, y: 1))
            let side = sticker.size
            if curl > 0.18 {
                let width = side * curl * 0.23, height = side * curl * 0.35
                let x = side * front * 0.79, y = side * 0.74
                let path = UIBezierPath()
                path.move(to: CGPoint(x: x - width, y: y))
                path.addQuadCurve(to: CGPoint(x: x, y: y - height), controlPoint: CGPoint(x: x - width * 0.13, y: y - height * 0.23))
                path.addQuadCurve(to: CGPoint(x: x - width, y: y), controlPoint: CGPoint(x: x - width * 0.63, y: y - height * 0.42))
                path.close()
                sprite.fold.path = path.cgPath
            } else { sprite.fold.path = nil }
        }
        CATransaction.commit()
    }
}
