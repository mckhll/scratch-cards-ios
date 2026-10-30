import UIKit
import Display

final class ScratchFilmView: UIView {
    private let background = UIView()
    private let gradient = CAGradientLayer()
    private let photo = UIImageView()
    private let grain = UIView()
    private weak var sourcePhoto: UIImage?
    private var photoCover: ScratchCardCover?
    private var photoGeneration = 0
    private var photoTask: DispatchWorkItem?
    var preparedPhotoImage: UIImage? { photo.image }
    private let scene = ScratchCoverSceneView()
    private let sheen = CAGradientLayer()
    private var cover: ScratchCardCover?
    private var animationsAllowed = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        background.layer.addSublayer(gradient)
        photo.contentMode = .scaleAspectFill
        background.clipsToBounds = true
        background.addSubview(photo)
        grain.isUserInteractionEnabled = false
        grain.backgroundColor = UIColor(patternImage: ScratchCoverPhotoArtwork.grain)
        background.addSubview(grain)
        addSubview(background)
        addSubview(scene)
        // Every stop is white with varying alpha. A radial highlight cannot
        // become an opaque dark diagonal plane when the card changes its pose.
        sheen.type = .radial
        sheen.colors = [UIColor(white: 1, alpha: 0.2).cgColor, UIColor(white: 1, alpha: 0.055).cgColor, UIColor(white: 1, alpha: 0).cgColor]
        sheen.locations = [0, 0.4, 1]
        sheen.startPoint = CGPoint(x: 0.5, y: 0.5)
        sheen.endPoint = CGPoint(x: 1, y: 1)
        sheen.opacity = 0
        layer.addSublayer(sheen)
        setCover(.like)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { photoTask?.cancel() }

    func setPhoto(_ image: UIImage?) {
        if image == nil {
            // The weak source can already have gone away while its processed
            // texture is still displayed. An explicit clear must remove both.
            guard sourcePhoto != nil || photo.image != nil || photoTask != nil || photoCover != cover else { return }
        } else {
            guard sourcePhoto !== image || photoCover != cover else { return }
        }
        sourcePhoto = image
        photoCover = cover
        photoGeneration += 1
        photoTask?.cancel()
        photo.image = nil // Never leave another message's silhouette on a reused node.
        guard let image, let cover else { return }
        let generation = photoGeneration
        let task = DispatchWorkItem { [weak self] in
            let result = ScratchCoverPhotoArtwork.image(photo: image, cover: cover)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.photoGeneration == generation else { return }
                self.photo.image = result
                self.photoTask = nil
            }
        }
        photoTask = task
        ScratchCoverPhotoArtwork.queue.async(execute: task)
    }

    func copyPhoto(from other: ScratchFilmView) {
        setPhoto(other.sourcePhoto)
        if other.cover == cover, let image = other.photo.image {
            photoGeneration += 1
            photoTask?.cancel()
            photoTask = nil
            photo.image = image
        }
    }

    func setCover(_ cover: ScratchCardCover) {
        guard self.cover != cover else { return }
        self.cover = cover
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.colors = cover.stickerColors.map { UIColor(rgb: $0).cgColor }
        gradient.locations = [0, 0.55, 1]
        CATransaction.commit()
        scene.setCover(cover)
        setPhoto(sourcePhoto)
    }

    func setRevealMask(_ mask: CALayer) { background.layer.mask = mask }

    override func layoutSubviews() {
        super.layoutSubviews()
        background.frame = bounds
        photo.frame = background.bounds
        grain.frame = background.bounds.insetBy(dx: -4, dy: -4)
        scene.frame = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        let side = max(bounds.width, bounds.height) * 1.45
        sheen.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        CATransaction.commit()
    }

    func setMotionActive(_ active: Bool, allowed: Bool, interactive: Bool = false) {
        animationsAllowed = allowed
        scene.setMotionActive(active, allowed: allowed, interactive: interactive)
        grain.layer.removeAnimation(forKey: "grainDrift")
        if active, interactive, allowed, !UIAccessibility.isReduceMotionEnabled {
            let drift = CABasicAnimation(keyPath: "transform")
            drift.fromValue = NSValue(caTransform3D: CATransform3DMakeTranslation(-2, -1, 0))
            drift.toValue = NSValue(caTransform3D: CATransform3DMakeTranslation(2, 1, 0))
            drift.duration = 2.8
            drift.autoreverses = true
            drift.repeatCount = .infinity
            drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            grain.layer.add(drift, forKey: "grainDrift")
        }
    }

    func interact(at point: CGPoint, began: Bool) {
        scene.interact(at: point, began: began)
        guard cover?.hasThemedEffects == true, animationsAllowed, !UIAccessibility.isReduceMotionEnabled else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sheen.position = CGPoint(x: min(bounds.maxX, max(0, point.x)), y: min(bounds.maxY, max(0, point.y)))
        sheen.opacity = 1
        CATransaction.commit()
        sheen.removeAnimation(forKey: "release")
    }

    func scratch(from start: CGPoint, to end: CGPoint) { scene.scratch(from: start, to: end) }

    func endInteraction() {
        scene.endInteraction()
        let from = sheen.presentation()?.opacity ?? sheen.opacity
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sheen.opacity = 0
        CATransaction.commit()
        guard animationsAllowed, !UIAccessibility.isReduceMotionEnabled else { return }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = from
        fade.toValue = 0
        fade.duration = 0.2
        sheen.add(fade, forKey: "release")
    }

    func finish(at point: CGPoint) {
        endInteraction()
        scene.finish(at: point)
        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0.18 : 0.28) { self.background.alpha = 0 }
    }
}

/// The sender uses exactly the same artwork as the receiver, without reveal gestures.
public final class ScratchCardPreviewView: UIView {
    private let film = ScratchFilmView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        addSubview(film)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    public func setCover(_ cover: ScratchCardCover) { film.setCover(cover) }
    public func setPhoto(_ image: UIImage?) { film.setPhoto(image) }
    public override func layoutSubviews() {
        super.layoutSubviews()
        film.frame = bounds
    }
}
