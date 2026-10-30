import Foundation

/// Client-only strings follow Telegram's interface language, not the device locale.
/// Other languages use English until a translation is provided for this prototype.
public struct ScratchCardStrings {
    private let russian: Bool

    public init(languageCode: String) {
        self.russian = languageCode.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first == "ru"
    }

    public var addCard: String { russian ? "Стираемая карточка" : "Scratch Card" }
    public var changeCover: String { russian ? "Обложка карточки" : "Card Cover" }
    public var removeCover: String { russian ? "Убрать обложку" : "Remove Cover" }
    public var openCard: String { scratch }
    public var scratch: String { russian ? "Стереть" : "Scratch" }
    public var rubToReveal: String { russian ? "Проведите пальцем" : "Rub to reveal" }
    public var cardAccessibility: String { russian ? "Стираемая карточка. Нажмите, затем проведите пальцем" : "Scratch card. Tap, then rub to reveal" }
    public var photoAccessibility: String { russian ? "Стираемая фотография" : "Scratch photo" }
    public var revealPhoto: String { russian ? "Раскрыть фотографию" : "Reveal photo" }
    public var closeCard: String { russian ? "Закрыть карточку" : "Close card" }
    public var close: String { russian ? "Закрыть" : "Close" }

    public func title(for cover: ScratchCardCover) -> String {
        switch cover {
        case .plain: return russian ? "Обычная" : "Plain"
        case .like: return russian ? "Нравится" : "Like"
        case .dislike: return russian ? "Не нравится" : "Dislike"
        case .heart: return russian ? "Сердце" : "Love"
        case .fire: return russian ? "Огонь" : "Fire"
        case .party: return russian ? "Праздник" : "Party"
        case .poop: return russian ? "Какашка" : "Poop"
        }
    }
}
