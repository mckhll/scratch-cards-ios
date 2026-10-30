import UIKit
import Display
import AsyncDisplayKit
import SpaceWarpView

/// Presentation-only scratch card. Never reparents or transforms the chat's media nodes.
public final class ScratchRevealView: UIView {
    public var photoView: (() -> UIView?)?
    public var completed: (() -> Void)?
    public var dismissedAfterReveal: (() -> Void)?
    /// Hide only the source media while its separate presentation is active.
    public var presentationChanged: ((Bool) -> Void)?
    public var particleEffectFactory: ((ScratchCardCover) -> ScratchCardParticleEffect?)?
    public var strings = ScratchCardStrings(languageCode: "en") {
        didSet {
            accessibilityLabel = strings.cardAccessibility
            prompt.setText(strings.openCard)
        }
    }
    public var animationsEnabled = true {
        didSet {
            setMotionActive(motionActive)
        }
    }
    private var motionActive = false
    private var session: ScratchCardSession?
    fileprivate let film = ScratchFilmView()
    private let prompt = ScratchCoverPrompt()
    fileprivate var mediaArguments: TransformImageArguments?
    fileprivate private(set) var accentColor: UIColor = .systemBlue
    fileprivate private(set) var cover: ScratchCardCover = .like

    public override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        // The actual media mask is supplied by the chat, including caption edges/tails.
        addSubview(film)
        addSubview(prompt)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(open)))
        isAccessibilityElement = true
        accessibilityLabel = strings.cardAccessibility
        prompt.setText(strings.openCard)
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func layoutSubviews() {
        super.layoutSubviews()
        film.frame = bounds
        layer.mask?.frame = bounds
        prompt.frame = bounds.insetBy(dx: 12, dy: 12)
    }

    public func updateAppearance(arguments: TransformImageArguments?, accentColor: UIColor, cover: ScratchCardCover) {
        self.accentColor = accentColor
        self.cover = cover
        film.setCover(cover)
        guard let arguments, mediaArguments != arguments else { return }
        mediaArguments = arguments
        guard let context = DrawingContext(size: arguments.drawingSize, scale: arguments.scale ?? 0, clear: true) else { return }
        context.withContext { context in
            context.setFillColor(UIColor.white.cgColor)
            context.fill(arguments.drawingRect)
        }
        // Identical rasterization to PhotoResources: a caption can make one or
        // more media corners square, and bubble tails extend beyond drawingRect.
        addCorners(context, arguments: arguments)
        let mask = CALayer()
        mask.frame = bounds
        mask.contents = context.generateImage()?.cgImage
        layer.mask = mask
    }

    public func setMotionActive(_ active: Bool) {
        motionActive = active
        film.setMotionActive(active && session == nil && !isHidden, allowed: animationsEnabled)
    }

    public func setPhoto(_ image: UIImage?) { film.setPhoto(image) }

    // Capture before hiding the source hierarchy: this preserves the exact chat
    // mask, texture and material pill, rather than reconstructing them at landing.
    func makeLandingCover() -> UIView? {
        layoutIfNeeded()
        return snapshotView(afterScreenUpdates: false)
    }

    @objc private func open() {
        guard session == nil, let window, let host = self.windowHost,
              let photo = photoView?(), bounds.width > 0, bounds.height > 0 else { return }
        // SpaceWarp expects an opaque scene beneath its backdrop layer. Freeze
        // the chat while the card is modal, so its black fallback never shows.
        let landingCover = makeLandingCover()
        presentationChanged?(true)
        alpha = 0
        let backdrop = window.snapshotView(afterScreenUpdates: true)
        let session = ScratchCardSession(source: self, photo: photo, backdrop: backdrop, window: window, landingCover: landingCover)
        let controller = ScratchCardController(session: session)
        self.session = session
        film.setMotionActive(false, allowed: animationsEnabled)
        session.finished = { [weak self, weak controller] revealed in
            if let self {
                self.session = nil
                // Prepare the photo hand-off before the frozen backdrop disappears.
                if revealed {
                    self.setMotionActive(false)
                    self.completed?()
                } else { self.setMotionActive(self.motionActive) }
                self.alpha = 1
                self.presentationChanged?(false)
            }
            let didDismiss: () -> Void = { [weak self] in
                if revealed { self?.dismissedAfterReveal?() }
            }
            // Telegram's presenting proxy removes the PresentationContext entry,
            // then invokes completion. Start the full message effect only then.
            if let presenter = controller?.presentingViewController {
                presenter.dismiss(animated: false, completion: didDismiss)
            } else { didDismiss() }
        }
        host.cancelInteractiveKeyboardGestures()
        host.present(controller, on: .root, blockInteraction: true, completion: {})
    }

    public override func accessibilityActivate() -> Bool { open(); return true }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { session?.cancel() }
    }
}

private final class ScratchCoverPrompt: UIView {
    private let background = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let icon = UIImageView(image: UIImage(systemName: "hand.draw", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)))
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        background.layer.cornerRadius = 20
        background.layer.cornerCurve = .continuous
        background.clipsToBounds = true
        addSubview(background)
        icon.tintColor = .white
        icon.contentMode = .center
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        background.contentView.addSubview(icon)
        background.contentView.addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func setText(_ text: String) { label.text = text; setNeedsLayout() }
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = min(bounds.width, max(96, ceil(label.sizeThatFits(CGSize(width: max(0, bounds.width - 56), height: 40)).width) + 56))
        background.frame = CGRect(x: bounds.midX - width / 2, y: bounds.midY - 20, width: width, height: 40)
        icon.frame = CGRect(x: 11, y: 8, width: 24, height: 24)
        label.frame = CGRect(x: 42, y: 0, width: max(0, width - 54), height: 40)
    }
}

/// Registers the full-screen surface with WindowContent's hit testing. A plain
/// UIWindow subview renders above the chat but is skipped by Telegram's router.
private final class ScratchCardController: ViewController {
    private let session: ScratchCardSession
    private let warpNode = SpaceWarpNodeImpl()
    private var sessionNode: ASDisplayNode?
    private var didPresent = false

    init(session: ScratchCardSession) {
        self.session = session
        super.init(navigationBarPresentationData: nil)
        self.statusBar.statusBarStyle = .Ignore
        session.rippleRequested = { [weak self] point in
            guard let self else { return }
            self.warpNode.triggerRipple(at: self.session.convert(point, to: self.warpNode.view))
        }
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadDisplayNode() {
        let session = self.session
        let sessionNode = ASDisplayNode(viewBlock: { session }, didLoad: nil)
        self.sessionNode = sessionNode
        self.displayNode = self.warpNode
        self.warpNode.contentNode.addSubnode(sessionNode)
        self.displayNodeDidLoad()
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.sessionNode?.frame = CGRect(origin: .zero, size: layout.size)
        self.warpNode.update(size: layout.size, cornerRadius: layout.deviceMetrics.screenCornerRadius, transition: .immediate)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didPresent else { return }
        didPresent = true
        session.present()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session.cancel()
    }
}

private final class ScratchTouchSurface: UIView {
    var samples: (([CGPoint], Bool) -> Void)?
    var ended: ((Bool) -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        layer.contents = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { context in
            context.cgContext.clear(CGRect(x: 0, y: 0, width: 1, height: 1))
        }.cgImage
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        samples?([touch.location(in: self)], true)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        samples?((event?.coalescedTouches(for: touch) ?? [touch]).map { $0.location(in: self) }, false)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { ended?(false) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { ended?(true) }
}

final class ScratchCardSession: UIView {
    var finished: ((Bool) -> Void)?
    var rippleRequested: ((CGPoint) -> Void)?
    private weak var source: ScratchRevealView?
    private let card = UIView()
    private let cardContent = UIView()
    private let returnClip = CAShapeLayer()
    private let landingCover: UIView?
    private let photo: UIView
    private let film = ScratchFilmView()
    private let particleEffect: ScratchCardParticleEffect?
    private let cover: ScratchCardCover
    private let maskLayer = CALayer()
    private let dim = UIView()
    private let hint = UILabel()
    private let gestureHint = ScratchGestureHintView()
    private var gestureHintWork: DispatchWorkItem?
    private var isTouching = false
    var isGestureHintVisible: Bool { gestureHint.alpha > 0 }
    var presentedCardFrame: CGRect { card.layer.presentation()?.frame ?? card.frame }
    var coverageFraction: CGFloat { CGFloat(erased) / CGFloat(coverage.count) }
    private let closeButton = UIButton(type: .system)
    private var coverage = [Bool](repeating: false, count: 160 * 160)
    private var erased = 0
    private var previous: CGPoint?
    private let touchSurface = ScratchTouchSurface()
    private var strokes: [UIBezierPath] = []
    private let feedback = ScratchCardHaptics()
    private var lastRubPoint: CGPoint?
    private let accent: UIColor
    private var isFinishing = false
    private var isClosed = false
    private var sourceRect: CGRect
    private(set) var expandedRect = CGRect.zero
    private var windowSize: CGSize

    init(source: ScratchRevealView, photo: UIView, backdrop: UIView?, window: UIWindow, landingCover: UIView? = nil) {
        self.source = source
        self.landingCover = landingCover ?? source.makeLandingCover()
        self.photo = photo
        // A closed message neither fetches effect resources nor owns a renderer.
        self.particleEffect = source.cover.hasThemedEffects && source.animationsEnabled && !UIAccessibility.isReduceMotionEnabled ? source.particleEffectFactory?(source.cover) : nil
        self.cover = source.cover
        self.accent = source.accentColor
        self.sourceRect = source.convert(source.bounds, to: window)
        self.windowSize = window.bounds.size
        super.init(frame: window.bounds)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        if let backdrop {
            backdrop.frame = bounds
            backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            backdrop.isUserInteractionEnabled = false
            addSubview(backdrop)
        }
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        dim.alpha = 0
        dim.frame = bounds
        dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // This recognizer is a sibling of the card's touch surface, so a scratch
        // that starts on the card and ends outside never becomes a dismiss tap.
        dim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backgroundTapped)))
        addSubview(dim)
        card.layer.cornerRadius = 20
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.22
        card.layer.shadowRadius = 24
        card.layer.shadowOffset = CGSize(width: 0, height: 14)
        addSubview(card)
        // A shared clip keeps the photo and film aligned throughout parallax.
        cardContent.layer.cornerRadius = 22
        cardContent.layer.cornerCurve = .continuous
        cardContent.clipsToBounds = true
        card.addSubview(cardContent)
        photo.isUserInteractionEnabled = false
        cardContent.addSubview(photo)
        film.setCover(source.cover)
        film.copyPhoto(from: source.film)
        cardContent.addSubview(film)
        if let particleEffect {
            particleEffect.view.isUserInteractionEnabled = false
            card.addSubview(particleEffect.view)
        }
        maskLayer.contentsScale = 1
        // The backing scratches continuously; the stickers peel above it.
        film.setRevealMask(maskLayer)
        hint.text = source.strings.rubToReveal
        hint.font = .systemFont(ofSize: 15, weight: .semibold)
        hint.textColor = .white
        hint.textAlignment = .center
        hint.layer.shadowOpacity = 0.4
        hint.layer.shadowRadius = 6
        hint.alpha = 0
        addSubview(hint)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.accessibilityLabel = source.strings.closeCard
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        addSubview(closeButton)
        cardContent.addSubview(touchSurface)
        cardContent.addSubview(gestureHint)
        if let landingCover = self.landingCover {
            landingCover.alpha = 0
            landingCover.isUserInteractionEnabled = false
            cardContent.addSubview(landingCover)
        }
        touchSurface.samples = { [weak self] points, began in self?.rub(points, began: began) }
        touchSurface.ended = { [weak self] cancelled in self?.endRub(cancelled: cancelled) }
        let accessibleReveal = UIAccessibilityCustomAction(name: source.strings.revealPhoto, target: self, selector: #selector(revealAccessible))
        accessibilityCustomActions = [accessibleReveal, UIAccessibilityCustomAction(name: source.strings.close, target: self, selector: #selector(closeAccessible))]
        isAccessibilityElement = true
        accessibilityLabel = source.strings.photoAccessibility
        // The controller attaches this surface through Telegram's presentation host.
        self.disablesInteractiveKeyboardGestureRecognizer = true
        self.accessibilityViewIsModal = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { gestureHintWork?.cancel() }

    private func scheduleGestureHint() {
        gestureHintWork?.cancel()
        guard !isTouching, !isClosed, !isFinishing else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isTouching, !self.isClosed, !self.isFinishing else { return }
            self.gestureHint.show()
        }
        gestureHintWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    private func hideGestureHint() {
        gestureHintWork?.cancel()
        gestureHintWork = nil
        gestureHint.hide()
    }

    func endRub(cancelled: Bool = false) {
        guard !isClosed, !isFinishing else { return }
        isTouching = false
        previous = nil
        film.endInteraction()
        if !cancelled, ScratchRevealPolicy.shouldReveal(coverage: coverageFraction, released: true) {
            dissolve()
            return
        }
        UIView.animate(withDuration: 0.22, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) { self.card.transform = .identity }
        scheduleGestureHint()
    }

    func present() {
        if let source, source.window != nil { sourceRect = source.convert(source.bounds, to: self) }
        let insets = window?.safeAreaInsets ?? .zero
        let available = bounds.inset(by: UIEdgeInsets(top: insets.top + 58, left: 18, bottom: insets.bottom + 66, right: 18))
        guard available.width > 0, available.height > 0 else { cancel(); return }
        let ratio = sourceRect.height / max(1, sourceRect.width)
        let width = min(available.width, available.height / max(0.1, ratio))
        expandedRect = CGRect(x: bounds.midX - width / 2, y: available.midY - width * ratio / 2, width: width, height: width * ratio)
        card.bounds = CGRect(origin: .zero, size: expandedRect.size)
        cardContent.frame = card.bounds
        particleEffect?.view.frame = card.bounds
        card.layer.shadowPath = UIBezierPath(roundedRect: card.bounds, cornerRadius: 22).cgPath
        photo.frame = cardContent.bounds
        film.frame = cardContent.bounds
        maskLayer.frame = film.bounds
        touchSurface.frame = card.bounds
        gestureHint.frame = cardContent.bounds
        landingCover?.frame = cardContent.bounds
        maskLayer.contents = makeMask().cgImage
        hint.frame = CGRect(x: 12, y: expandedRect.maxY + 12, width: bounds.width - 24, height: 30)
        closeButton.frame = CGRect(x: expandedRect.maxX - 40, y: max(insets.top + 4, expandedRect.minY - 48), width: 40, height: 40)
        card.center = CGPoint(x: sourceRect.midX, y: sourceRect.midY)
        card.transform = CGAffineTransform(scaleX: sourceRect.width / width, y: sourceRect.height / expandedRect.height)
        card.isUserInteractionEnabled = false
        let duration = UIAccessibility.isReduceMotionEnabled ? 0.2 : 0.36
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: [.beginFromCurrentState], animations: {
            self.dim.alpha = 1
            self.card.center = CGPoint(x: self.expandedRect.midX, y: self.expandedRect.midY)
            self.card.transform = .identity
        }, completion: { [weak self] _ in
            guard let self, !self.isClosed else { return }
            self.card.isUserInteractionEnabled = true
            UIView.animate(withDuration: 0.14) { self.hint.alpha = 1 }
            self.scheduleGestureHint()
        })
        feedback.prepare()
        film.setMotionActive(true, allowed: source?.animationsEnabled ?? true, interactive: true)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != windowSize { cancel() }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, isUserInteractionEnabled, bounds.contains(point) else { return nil }
        return super.hitTest(point, with: event) ?? self
    }

    @objc private func close() { returnToChat(revealed: false) }
    override func accessibilityPerformEscape() -> Bool { close(); return true }
    @objc private func backgroundTapped() {
        guard !isFinishing, !isClosed, card.isUserInteractionEnabled else { return }
        close()
    }
    func cancel() {
        guard !isClosed else { return }
        isClosed = true
        hideGestureHint()
        feedback.stop()
        film.setMotionActive(false, allowed: false)
        particleEffect?.stop()
        source?.alpha = 1
        removeFromSuperview()
        finished?(false)
        finished = nil
    }

    @objc private func revealAccessible() -> Bool { dissolve(); return true }
    @objc private func closeAccessible() -> Bool { close(); return true }

    func rub(_ points: [CGPoint], began: Bool) {
        guard !isFinishing, !isClosed, let point = points.last,
              card.bounds.width > 0, card.bounds.height > 0 else { return }
        lastRubPoint = point
        isTouching = true
        hideGestureHint()
        film.interact(at: point, began: began)
        if began {
            previous = nil
            let path = UIBezierPath()
            path.move(to: point)
            strokes.append(path)
            UIView.animate(withDuration: 0.18) { self.hint.alpha = 0 }
        }
        guard let path = strokes.last else { return }
        let before = erased
        for sample in points {
            let start = previous ?? sample
            film.scratch(from: start, to: sample)
            let distance = hypot(sample.x - start.x, sample.y - start.y)
            let count = min(300, max(1, Int(distance / 4)))
            for index in 1 ... count {
                let f = CGFloat(index) / CGFloat(count)
                stamp(CGPoint(x: start.x + (sample.x - start.x) * f, y: start.y + (sample.y - start.y) * f))
            }
            path.addLine(to: sample)
            previous = sample
        }
        if before != erased {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            maskLayer.contents = makeMask().cgImage
            CATransaction.commit()
            debris(at: point)
            feedback.scratch()
        }
        if cover.hasThemedEffects {
            let tilt = ScratchCardParallax.transform(at: point, size: card.bounds.size, reduceMotion: UIAccessibility.isReduceMotionEnabled)
            UIView.animate(withDuration: 0.1, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) { self.card.transform = tilt }
        }
        if ScratchRevealPolicy.shouldReveal(coverage: coverageFraction, released: false) { dissolve() }
    }

    private func stamp(_ point: CGPoint) {
        let radius: CGFloat = 25
        let minY = min(160, max(0, Int((point.y - radius) / card.bounds.height * 160)))
        let maxY = min(160, max(0, Int((point.y + radius) / card.bounds.height * 160) + 1))
        let minX = min(160, max(0, Int((point.x - radius) / card.bounds.width * 160)))
        let maxX = min(160, max(0, Int((point.x + radius) / card.bounds.width * 160) + 1))
        for y in minY ..< maxY {
            for x in minX ..< maxX {
                let dx = (CGFloat(x) + 0.5) / 160 * card.bounds.width - point.x
                let dy = (CGFloat(y) + 0.5) / 160 * card.bounds.height - point.y
                if dx * dx + dy * dy < radius * radius, !coverage[y * 160 + x] {
                    coverage[y * 160 + x] = true
                    erased += 1
                }
            }
        }
    }

    private func makeMask() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.5
        return UIGraphicsImageRenderer(size: card.bounds.size, format: format).image { renderer in
            UIColor.white.setFill()
            renderer.fill(card.bounds)
            renderer.cgContext.setBlendMode(.destinationOut)
            for path in strokes {
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                UIColor(white: 1, alpha: 0.25).setStroke()
                path.lineWidth = 54
                path.stroke()
                UIColor.white.setStroke()
                path.lineWidth = 48
                path.stroke()
            }
        }
    }

    private func dissolve() {
        guard !isFinishing, !isClosed else { return }
        isFinishing = true
        hideGestureHint()
        particleEffect?.stop()
        film.finish(at: lastRubPoint ?? CGPoint(x: card.bounds.midX, y: card.bounds.midY))
        if cover.hasThemedEffects { feedback.finish() }
        feedback.stop()
        card.isUserInteractionEnabled = false
        closeButton.isEnabled = false
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
            self.hint.alpha = 0
            self.card.transform = .identity
        })
        if cover.hasThemedEffects {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in self?.shockWave() }
        }
        // SpaceWarp uses a 1400 pt/s wave and retires it at sqrt(2) * maxEdge.
        // Keep its host alive through that tail, including the 0.34s card return.
        let waveLifetime = Double(max(bounds.width, bounds.height) * sqrt(2) / 1400)
        let returnDelay = !cover.hasThemedEffects || UIAccessibility.isReduceMotionEnabled ? 0.44 : max(0.44, 0.1 + waveLifetime - 0.34 + 0.02)
        DispatchQueue.main.asyncAfter(deadline: .now() + returnDelay) { [weak self] in self?.returnToChat(revealed: true) }
    }

    private func shockWave() {
        guard cover.hasThemedEffects, !isClosed, !UIAccessibility.isReduceMotionEnabled else { return }
        let point = lastRubPoint ?? CGPoint(x: card.bounds.midX, y: card.bounds.midY)
        rippleRequested?(cardContent.convert(point, to: self))
    }

    private func animateReturnClip(duration: Double) {
        let rect = cardContent.bounds
        let arguments = source?.mediaArguments
        let drawingSize = arguments?.drawingSize ?? sourceRect.size
        let sx = rect.width / max(1, drawingSize.width)
        let sy = rect.height / max(1, drawingSize.height)
        let targetRect = arguments?.drawingRect ?? CGRect(origin: .zero, size: drawingSize)
        let r = CGRect(x: targetRect.minX * sx, y: targetRect.minY * sy, width: targetRect.width * sx, height: targetRect.height * sy)
        let corners = arguments?.corners ?? ImageCorners(radius: source?.layer.cornerRadius ?? 22)
        // Keep identical path commands for all four corners, including square
        // caption joins. The shared mask clips photo, film and landing snapshot.
        let radii = [corners.topLeft.radius, corners.topRight.radius, corners.bottomRight.radius, corners.bottomLeft.radius].map { min(max(0, $0), min(drawingSize.width, drawingSize.height) / 2) }
        func path(_ rect: CGRect, _ radii: [CGFloat], _ sx: CGFloat, _ sy: CGFloat) -> CGPath {
            let p = UIBezierPath()
            let a = radii.map { CGSize(width: $0 * sx, height: $0 * sy) }
            let k: CGFloat = 0.55228475
            p.move(to: CGPoint(x: rect.minX + a[0].width, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - a[1].width, y: rect.minY))
            p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + a[1].height), controlPoint1: CGPoint(x: rect.maxX - a[1].width * (1 - k), y: rect.minY), controlPoint2: CGPoint(x: rect.maxX, y: rect.minY + a[1].height * (1 - k)))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - a[2].height))
            p.addCurve(to: CGPoint(x: rect.maxX - a[2].width, y: rect.maxY), controlPoint1: CGPoint(x: rect.maxX, y: rect.maxY - a[2].height * (1 - k)), controlPoint2: CGPoint(x: rect.maxX - a[2].width * (1 - k), y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX + a[3].width, y: rect.maxY))
            p.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY - a[3].height), controlPoint1: CGPoint(x: rect.minX + a[3].width * (1 - k), y: rect.maxY), controlPoint2: CGPoint(x: rect.minX, y: rect.maxY - a[3].height * (1 - k)))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + a[0].height))
            p.addCurve(to: CGPoint(x: rect.minX + a[0].width, y: rect.minY), controlPoint1: CGPoint(x: rect.minX, y: rect.minY + a[0].height * (1 - k)), controlPoint2: CGPoint(x: rect.minX + a[0].width * (1 - k), y: rect.minY))
            p.close()
            return p.cgPath
        }
        returnClip.frame = rect
        returnClip.fillColor = UIColor.white.cgColor
        let from = path(rect, [22, 22, 22, 22], 1, 1)
        returnClip.path = path(r, radii, sx, sy)
        cardContent.layer.mask = returnClip
        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = from
        animation.toValue = returnClip.path
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        returnClip.add(animation, forKey: "returnCorners")
    }

    private func returnToChat(revealed: Bool) {
        guard !isClosed else { return }
        isClosed = true
        hideGestureHint()
        card.isUserInteractionEnabled = false
        film.setMotionActive(false, allowed: false)
        particleEffect?.stop()
        if let source, source.window != nil { sourceRect = source.convert(source.bounds, to: self) }
        // Animate center and scale only; never assign frame while the card is tilted.
        feedback.stop()
        let returnDuration = UIAccessibility.isReduceMotionEnabled ? 0.2 : 0.34
        animateReturnClip(duration: returnDuration)
        if !revealed, let landingCover {
            // The cancelled scratch heals while the card shrinks. The source
            // pill joins this same motion instead of popping in on dismissal.
            UIView.animate(withDuration: returnDuration * 0.7, delay: returnDuration * 0.3, options: [.curveEaseInOut, .beginFromCurrentState], animations: {
                landingCover.alpha = 1
            })
        }
        let flyBack: () -> Void = { [weak self] in
            guard let self else { return }
            let energeticReturn = revealed && self.cover.hasThemedEffects
            UIView.animate(withDuration: returnDuration, delay: 0, usingSpringWithDamping: energeticReturn ? 0.86 : 0.94, initialSpringVelocity: energeticReturn ? 1.2 : 0.3, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
                // The animated shared mask now owns the contour. Never expose
                // a square film beneath the rounded landing snapshot.
                self.cardContent.layer.cornerRadius = 0
                self.card.layer.shadowOpacity = 0
                self.card.center = CGPoint(x: self.sourceRect.midX, y: self.sourceRect.midY)
                self.card.transform = CGAffineTransform(scaleX: self.sourceRect.width / self.card.bounds.width, y: self.sourceRect.height / self.card.bounds.height)
                self.dim.alpha = 0
                self.hint.alpha = 0
                self.closeButton.alpha = 0
            }, completion: { [weak self] _ in
                guard let self else { return }
                // Reconcile the exact source geometry before the hand-off.
                // The returning copy already contains the native mask and pill.
                UIView.performWithoutAnimation {
                    self.card.center = CGPoint(x: self.sourceRect.midX, y: self.sourceRect.midY)
                    self.card.transform = CGAffineTransform(scaleX: self.sourceRect.width / self.card.bounds.width, y: self.sourceRect.height / self.card.bounds.height)
                    self.landingCover?.alpha = revealed ? 0 : 1
                    if !revealed, self.landingCover != nil { self.film.alpha = 0 }
                    if let mask = self.source?.layer.mask {
                        let exactMask = CALayer()
                        exactMask.frame = self.cardContent.bounds
                        exactMask.contents = mask.contents
                        self.cardContent.layer.mask = exactMask
                    }
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.source?.alpha = 1
                    if revealed && self.cover.hasThemedEffects { self.feedback.land() }
                    self.finished?(revealed)
                    self.finished = nil
                    self.removeFromSuperview()
                }
            })
        }
        flyBack()
    }

    private var lastDebrisTime: CFTimeInterval = 0
    private func debris(at point: CGPoint) {
        let now = CACurrentMediaTime()
        guard cover.hasThemedEffects, now - lastDebrisTime > 0.1, !UIAccessibility.isReduceMotionEnabled else { return }
        lastDebrisTime = now
        if particleEffect?.emit(at: point) == true { return }
        ScratchCoverParticles.emit(in: card.layer, at: point, cover: cover, count: 2)
    }
}
