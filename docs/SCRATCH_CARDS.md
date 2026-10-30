# Scratch-card implementation

## Interaction

The source message keeps an opaque cover with the exact media mask, including caption joins and rounded corners. Tapping presents a separate interaction surface through Telegram's presentation host. A frozen chat snapshot stays behind it; the original message layout is not resized or reparented.

The native cover now follows the original sticker study in `prototypes/cover-collection/heart-directions.html`: attached system emoji with a white silhouette border over a coordinated gradient. Stickers curl locally and peel away when a scratch segment crosses them. They do not drift at rest. Artwork is rendered on the device; exported system emoji bitmaps are not bundled. Sender grid and selected-photo previews use the same film as the recipient.

The composition uses approximately 13% lower area density through evenly increased spacing, retaining sticker sizes. Bounded position jitter fills every cell; palette selection compares physical neighbours across rows to avoid identical-emoji stripes. The source action reads “Scratch” / «Стереть». The chat dim is a restrained black alpha 0.28, up from 0.24. The underlying message-bubble background behaviour is unchanged.

The backing also hints at the photo's broad composition. A background queue downsamples the source to at most 64×64 pixels and applies Telegram's CPU blur three times. Only the blurred luminance modulates the theme palette, with bounded contrast; original photo colours are not blended through. A shared fine-grain tile adds spoiler-like texture. Grain is stationary in closed cards and drifts subtly only in an active expanded session (static with Reduce Motion). The backing remains opaque until scratched; tint and grain share its reveal mask. The same photo pipeline is used in sender previews and chat covers. Opening reuses the prepared texture when available, and generation tokens discard obsolete asynchronous results on photo/theme changes. Before a thumbnail loads, the theme gradient remains the fallback.

Coalesced touch samples create continuous scratch strokes. A coverage grid triggers completion on finger release at 50% or more, or automatically at 81% while rubbing. Holding at 50–80% preserves the interaction; a system-cancelled touch does not count as release. The backing erases along the stroke while stickers peel above it; completion peels the remaining stickers and fades the backing. Themed cards have bounded planar tilt, a white radial highlight that follows touch, small native animation bursts and the existing SpaceWarp ripple. Photo and film share one rounded clip, without perspective or negative-z sibling planes. Plain has static neutral film, a simple fade and a subdued return. Tactile scratch feedback remains on supported hardware.

Opening uses a 0.36-second spring, followed by the rub hint. Return uses one 0.34-second spring. On cancellation, a snapshot of the exact original cover, native mask and material action pill fades in over the returning card; the source hierarchy replaces it only after the landing animation completes. Reduce Motion removes sticker flight, tilt and the wave. Only the source media is hidden during the presentation, so the frozen chat does not contain a duplicate cover. The source is restored on both completion and cancellation; native message effects start after the presentation is dismissed. Revealed IDs are retained by the current chat interaction, including media-node reuse, but are not persisted across app launches.

After one second of inactivity following opening, a passive hand icon demonstrates rubbing over the card. It disappears immediately on touch and can return after an incomplete release. It does not erase pixels or intercept gestures. Reduce Motion uses a static icon. Closing and completion cancel the timer and remove the animation.

All emoji palettes use mixed sticker indices with deterministic position/angle jitter, including themes with three emoji. Closed covers share a baked, transparent sticker texture through a 24 MiB cost-limited cache; individual shadowed layers exist only inside the opened session. Particle resources/renderers are created only for that session. The chat overlay skips the hidden ordinary-spoiler blur and dust updates for cards. These changes reduce idle rendering/setup work; physical-device scrolling performance still needs measurement.

Cold sticker textures are now rasterized on a serial background queue; concurrent identical requests share one result and publish on the main thread. A generation token prevents stale results from replacing a changed cover or an interactive scene. A same-cover resize retains its last texture while preparing the replacement. A completely cold cover briefly shows its opaque tinted backing until stickers are ready. This removes synchronous cover rasterization from message insertion/upload updates; it does not certify the cause or resolution of a specific device upload hitch.

The completion accent is quieter around the native message effect: local bursts are 120 pt, opacity 0.68, at most two concurrently, with 0.32 s spacing and a shorter trail. They stop at full reveal. The SpaceWarp request starts at 0.10 s; return still preserves its native lifetime. The final native effect is 330 pt at opacity 0.9 for scratch-card messages; ordinary message effects retain their standard 380 pt presentation. Native effect resources/playback and stock-client transport are unchanged.

The close button and a tap on the background use the same cancellation path. The background tap recognizer is a sibling of the card, so a scratch that leaves the card does not turn into a dismissal and taps do not reach the underlying chat.

## Transport and compatibility

A card is a standard photo with `MediaSpoilerMessageAttribute` and a versioned invisible suffix in its caption. The receiver decodes that suffix; it is stripped from visible caption text in this client. Cover values 0–5 retain the original themes; value 6 is Plain. Existing unversioned prototype markers remain supported as the first theme.

Stock clients see an ordinary photo spoiler. Caption editing can remove the marker. The marker consumes caption capacity, so a caption near Telegram's limit may not receive a card marker. This is prototype transport, not an official media type or an access-control feature.

For supported private cloud chats, the sender resolves a corresponding free effect from Telegram's cached catalogue and attaches the standard `EffectMessageAttribute`. Explicit sender selections take priority. If the catalogue is not available, no unknown effect id is invented. Plain does not automatically attach an effect. Telegram albums support one native effect per album.

The custom client gates full effect playback until scratch completion. Stock clients follow their own playback rules. Reveal state belongs to the current client interaction; it is not a synced server-side scratch-progress record.

## Code map

| Area | Location |
| --- | --- |
| Styles, labels, scratch surface, haptics and motion | `submodules/InvisibleInkDustNode/Sources/Scratch*.swift` |
| Sender's cover menu | `submodules/MediaPickerUI/Sources/MediaPickerScreen.swift` |
| Selection state and caption markers | `submodules/LegacyComponents/Sources/TGMediaEditingContext.m`, `TGMediaAssetsController.m` |
| Photo overlay, legacy wallpaper assets and small native effects | `submodules/TelegramUI/Components/Chat/ChatMessageInteractiveMediaNode/Sources/` |
| Standard effect attachment | `submodules/TelegramUI/Sources/Chat/ChatControllerScratchCardEffects.swift` |
| Reveal completion and playback gating | ChatMessageMediaBubbleContentNode, ChatMessageItemView and ChatMessageBubbleItemNode |
| Animated menu icon | `submodules/TelegramUI/Resources/Animations/anim_scratch_card.json` |
| Independent browser experiment | `prototypes/party-cover/` |

## Verification status

Completed during development: full simulator app builds, marker compatibility checks including the Objective-C writer/Swift reader, isolated HTML rendering and menu-icon asset frame inspection. No signed physical-device build or stock-client delivery roundtrip is certified by these checks.

The native sticker model has a standalone regression check in `tools/check_scratch_sticker_model.swift`: proportional layouts, segment hit-testing, peel retirement, palette diversity, reveal thresholds, Reduce Motion and non-inverting transforms. `//submodules/InvisibleInkDustNode:ScratchCardRenderingTests` hosts the real UIKit session on a disposable test window: all seven covers, dark/light and RU/EN, modal hit testing, exactly-once reveal/cancel completion, outside-close, bounds-change cancellation, transparent artwork corners, idle coaching and release semantics. It also scrolls a 12-cover gallery, checks closed-card layer bounds/cache reuse and verifies that closed cards do not request particle renderers. It does not exercise account/chat routing, the real SpaceWarp renderer or physical haptics. The runner is pinned to the locally available iPhone Duo / iOS 27.1; adjust that pin when using another runtime.

The native component has been recorded and its heart sequence inspected frame by frame; see [the review and its remaining limitations](SCRATCH_CARDS_NATIVE_REVIEW.md). Full-chat verification still includes captions above/below the photo, cancellation via both exits, dragging beyond the card, Reduce Motion, both interface languages, actual SpaceWarp/message-effect playback and sending to a stock client. See also the [lab's native verification notes](../prototypes/party-cover/README.md#native-integration) and [`AGENTS.md`](../AGENTS.md).
