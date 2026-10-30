import Foundation
import SwiftSignalKit
import TelegramCore
import LegacyMediaPickerUI
import InvisibleInkDustNode

extension ChatControllerImpl {
    /// Use the real effect id from Telegram's catalogue; no private-client-only animation.
    func prepareScratchCardEffects(_ items: [LegacyAssetPickerEnqueueMessage], selectedEffectId: Int64?) -> Signal<[LegacyAssetPickerEnqueueMessage], Void> {
        // Match the native effect picker's destinations and keep explicit choices authoritative.
        guard selectedEffectId == nil,
              let peerId = self.chatLocation.peerId,
              peerId.namespace == Namespaces.Peer.CloudUser,
              peerId != self.context.account.peerId,
              items.contains(where: { item in
                  if case let .message(text, attributes, _, mediaReference, _, _, _, _, _, _) = item.message {
                      return mediaReference?.media is TelegramMediaImage
                          && attributes.contains(where: { $0 is MediaSpoilerMessageAttribute })
                          && ScratchCardMessage.cover(in: text)?.hasThemedEffects == true
                  }
                  return false
              }) else { return .single(items) }

        return self.context.engine.stickers.availableMessageEffects()
        |> take(1)
        |> map { available in
            return items.map { item in
                guard case let .message(text, attributes, _, mediaReference, _, _, _, _, _, _) = item.message,
                      mediaReference?.media is TelegramMediaImage,
                      attributes.contains(where: { $0 is MediaSpoilerMessageAttribute }),
                      !attributes.contains(where: { $0 is EffectMessageAttribute }),
                      let cover = ScratchCardMessage.cover(in: text), cover.hasThemedEffects else { return item }
                let emoji = cover.emoji.replacingOccurrences(of: "\u{fe0f}", with: "")
                guard let effect = available?.messageEffects.first(where: {
                    !$0.isPremium && $0.emoticon.replacingOccurrences(of: "\u{fe0f}", with: "") == emoji
                }) else { return item }
                var result = item
                result.message = item.message.withUpdatedAttributes { attributes in
                    return attributes + [EffectMessageAttribute(id: effect.id)]
                }
                return result
            }
        }
        |> castError(Void.self)
    }
}
