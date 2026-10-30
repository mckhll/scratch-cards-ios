import UIKit
import Display
import TelegramPresentationData
import AccountContext
import WallpaperBackgroundNode
import InvisibleInkDustNode

/// Uses the same cached pattern loader and gradient renderer as chat wallpapers.
final class ScratchCoverWallpaperView: UIView {
    private let node: WallpaperBackgroundNode

    init(context: AccountContext, cover: ScratchCardCover) {
        self.node = createWallpaperBackgroundNode(context: context, forChatDisplay: false)
        super.init(frame: .zero)
        let pattern: BuiltinWallpaperData
        switch cover {
        case .plain:
            // The film normally omits this view for Plain. Keep the factory safe too.
            backgroundColor = UIColor(rgb: cover.wallpaperColors[0])
            isUserInteractionEnabled = false
            return
        case .like: pattern = .variant1 // Cheerful faces and stars.
        case .dislike: pattern = .variant10 // Skulls and dark fantasy.
        case .heart: pattern = .variant11 // Paris, flowers and romance.
        case .fire: pattern = .variant2 // Dragons, lightning and energy.
        case .party: pattern = .variant7 // Balloons, gifts and celebration.
        case .poop: pattern = .legacy // Playful creatures and silly faces.
        }
        addSubview(node.view)
        node.view.isUserInteractionEnabled = false
        // Positive intensity blends just the pattern. Negative intensity instead
        // fades the entire gradient against black, obscuring these dark palettes.
        node.update(wallpaper: defaultBuiltinWallpaper(data: pattern, colors: cover.wallpaperColors, intensity: 12), animated: false)
        node.updateIsLooping(false)
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        node.frame = bounds
        node.updateLayout(size: bounds.size, displayMode: .aspectFill, transition: .immediate)
    }
}
