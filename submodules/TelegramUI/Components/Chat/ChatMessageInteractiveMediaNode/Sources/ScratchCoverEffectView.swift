import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import StickerResources
import InvisibleInkDustNode

/// Small bursts use the exact resource and renderer used by message effects.
/// Fetch once when the cover appears; never replay a late download after a gesture.
final class ScratchCoverEffectView: UIView, ScratchCardParticleEffect {
    var view: UIView { self }

    private let context: AccountContext
    private let catalogueDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private let dataDisposable = MetaDisposable()
    private var source: AnimatedStickerResourceSource?
    private var cachePathPrefix: String?
    private var resourceReady = false
    private var bursts: [AnimatedStickerNode] = []
    private var lastEmission: CFTimeInterval = 0

    init(context: AccountContext, cover: ScratchCardCover) {
        self.context = context
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        guard cover.hasThemedEffects else { return }
        let emoji = cover.emoji.replacingOccurrences(of: "\u{fe0f}", with: "")
        catalogueDisposable.set((context.engine.stickers.availableMessageEffects()
        |> take(1)
        |> deliverOnMainQueue).startStrict(next: { [weak self] available in
            guard let self,
                  let effect = available?.messageEffects.first(where: {
                      !$0.isPremium && $0.emoticon.replacingOccurrences(of: "\u{fe0f}", with: "") == emoji
                  }) else { return }
            if let animation = effect.effectAnimation?._parse() {
                self.prepare(file: animation, useVideoThumbnail: false)
            } else {
                self.prepare(file: effect.effectSticker._parse(), useVideoThumbnail: true)
            }
        }))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        catalogueDisposable.dispose()
        fetchDisposable.dispose()
        dataDisposable.dispose()
    }

    private func prepare(file: TelegramMediaFile, useVideoThumbnail: Bool) {
        guard let resource = useVideoThumbnail ? file.videoThumbnails.first?.resource : file.resource else { return }
        source = AnimatedStickerResourceSource(account: context.account, resource: resource, fitzModifier: nil)
        cachePathPrefix = context.engine.resources.shortLivedResourceCachePathPrefix(id: EngineMediaResource.Id(resource.id))
        fetchDisposable.set(freeMediaFileResourceInteractiveFetched(account: context.account, userLocation: .other, fileReference: .standalone(media: file), resource: resource).startStrict())
        dataDisposable.set((context.engine.resources.data(id: EngineMediaResource.Id(resource.id))
        |> filter { $0.isComplete }
        |> take(1)
        |> deliverOnMainQueue).startStrict(next: { [weak self] _ in
            self?.resourceReady = true
        }))
    }

    func emit(at point: CGPoint) -> Bool {
        guard resourceReady, let source, let cachePathPrefix else { return false }
        guard !UIAccessibility.isReduceMotionEnabled, window != nil else { return true }
        let now = CACurrentMediaTime()
        guard bursts.count < 2, now - lastEmission >= 0.32 else { return true }
        lastEmission = now

        let side: CGFloat = 120 // A local trail stays smaller than the reveal accent.
        let size = CGSize(width: side, height: side)
        let node: AnimatedStickerNode = DirectAnimatedStickerNode(lottieSettings: context.lottieRenderingSettings)
        node.updateLayout(size: size)
        node.setup(source: source, width: Int(side * 1.4), height: Int(side * 1.4), playbackMode: .once, mode: .direct(cachePathPrefix: cachePathPrefix))
        // Message-effect artwork is anchored off-centre. Match the native
        // outgoing-message offset so the burst actually originates at the finger.
        node.frame = CGRect(x: point.x - side * 0.8, y: point.y - side * 0.5 - 4, width: side, height: side)
        node.alpha = 0.68
        node.view.isUserInteractionEnabled = false
        addSubview(node.view)
        bursts.append(node)
        node.completed = { [weak self, weak node] _ in
            guard let node else { return }
            self?.remove(node)
        }
        node.visibility = true

        // Short local trails stay quieter than the full reveal effect.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self, weak node] in
            guard let node else { return }
            self?.fade(node)
        }
        return true
    }

    func stop() {
        for node in bursts { fade(node) }
        lastEmission = 0
    }

    private func fade(_ node: AnimatedStickerNode) {
        guard bursts.contains(where: { $0 === node }) else { return }
        UIView.animate(withDuration: 0.15, animations: { node.alpha = 0 }, completion: { [weak self, weak node] _ in
            guard let node else { return }
            self?.remove(node)
        })
    }

    private func remove(_ node: AnimatedStickerNode) {
        guard let index = bursts.firstIndex(where: { $0 === node }) else { return }
        bursts.remove(at: index)
        node.visibility = false
        node.stop()
        node.view.removeFromSuperview()
    }
}
