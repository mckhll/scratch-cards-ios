import Foundation

public enum ScratchCardCover: Int, CaseIterable {
    // Wire values 0...5 already exist in sent captions. Append new styles.
    case like, dislike, heart, fire, party, poop, plain

    public static var menuOrder: [ScratchCardCover] {
        return [.plain, .like, .dislike, .heart, .fire, .party, .poop]
    }

    public var hasThemedEffects: Bool { self != .plain }

    public var emoji: String {
        switch self {
        case .plain: return ""
        case .like: return "👍"
        case .dislike: return "👎"
        case .heart: return "❤️"
        case .fire: return "🔥"
        case .party: return "🎉"
        case .poop: return "💩"
        }
    }

    public var objects: [String] {
        switch self {
        case .plain: return []
        case .like: return ["👍", "👌", "🤝"]
        case .dislike: return ["👎", "🚫", "⛔️", "❌"]
        case .heart: return ["💕", "💖", "💗", "💘"]
        case .fire: return ["🔥", "💥", "⚡"]
        case .party: return ["🎉", "🎊", "🎁", "🎈"]
        case .poop: return ["💩", "🤡", "🤮"]
        }
    }

    /// The selected sticker study, extended to the existing wire-compatible themes.
    public var stickerObjects: [String] {
        switch self {
        case .heart: return ["💗", "💖", "💕", "💘", "❤️", "🥰", "😍", "😘"]
        default: return objects
        }
    }

    public var stickerColors: [UInt32] {
        switch self {
        case .plain: return [0x343b45, 0x303640, 0x353c46]
        case .like: return [0x76b8b2, 0x6399b7, 0x5d809f]
        case .dislike: return [0x9b8da9, 0x827e9c, 0x6d7891]
        case .heart: return [0xe5a0b5, 0xcf89a8, 0xb37fa8]
        case .fire: return [0xd99c7c, 0xc98782, 0xa97895]
        case .party: return [0xa494d0, 0xa387c4, 0x7e96bf]
        case .poop: return [0xb7aa86, 0xa39e83, 0x858f87]
        }
    }

    public var wallpaperColors: [UInt32] {
        switch self {
        case .plain: return [0x343b45, 0x303640, 0x353c46, 0x303640]
        case .like: return [0x203f58, 0x1d4249, 0x244c60, 0x172e48]
        case .dislike: return [0x302f45, 0x24384a, 0x3a3044, 0x202c3c]
        case .heart: return [0x59334e, 0x482c50, 0x65374b, 0x352a46]
        case .fire: return [0x613c30, 0x493047, 0x6d472a, 0x39283b]
        case .party: return [0x292954, 0x37315f, 0x332c57, 0x171d38]
        case .poop: return [0x413b30, 0x343d36, 0x4c3b31, 0x2e3333]
        }
    }

    /// Replace the placeholder by adding an image with this name to the app assets.
    public var assetName: String {
        switch self {
        case .plain: return "ScratchCards/Plain"
        case .like: return "ScratchCards/Like"
        case .dislike: return "ScratchCards/Dislike"
        case .heart: return "ScratchCards/Heart"
        case .fire: return "ScratchCards/Fire"
        case .party: return "ScratchCards/Party"
        case .poop: return "ScratchCards/Poop"
        }
    }
}
