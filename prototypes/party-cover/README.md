# Party cover lab

Open `index.html` directly in a browser. It is self-contained, works offline, and sends no data anywhere. A local photo can be selected for the scratch test; it remains inside the browser.

- **Обложка**: inertial touch response without erasing.
- **Стирание**: continuous brush, reveal at 60%.
- Tap for a small local burst; drag to displace the floating objects.
- Tune drift, touch response, density, and reduced motion.
- **Проверка движения**: reproducible eight-second gesture and optional local canvas recording.

## Assets

The public lab renders 🎉 🎊 🎁 at runtime using the browser's system emoji font. It works without sprite files, network requests or a bundled font; appearance can vary by operating system.

Earlier local `assets/party.png`, `confetti.png`, and `gift.png` were rasterizations from Apple Color Emoji. These files and the old `preview.png` are now ignored by Git and are not embedded by the default builder. The export utility remains available for local experiments. See the repository's [asset notice](../../NOTICE.md).

This HTML remains an independent lab. Its motion is now also implemented natively in `ScratchCoverMotion.swift` and `ScratchCoverSceneView.swift`; the app does not embed a web view.

Edit `template.html`, then run `python3 build.py` to regenerate the self-contained `index.html`. No image exports are needed for the public version.

## Verification

The final HTML was rendered in a separate WebKit process with a deterministic test clock. The check executes the real Canvas code and synthetic pointer events, captures 33 frames over an eight-second gesture, verifies finite object positions, scratch completion at 60%, pixel-identical paused frames, both themes, and a 390 px layout. It does not measure device performance or claim a real 60 fps result.

Run from this folder on macOS:

```sh
xcrun swiftc tools/verify-webkit.swift -o /tmp/party-cover-check
/tmp/party-cover-check "$PWD/index.html" /tmp/party-cover-qa
```

Frames and `motion.json` are saved in the output directory. In the test sequence, #04–#08 (test t=1.00–2.00 s) show foreground objects separating from the drag. #26 (6.50 s) shows the local tap burst; by #32 (8.00 s), its short-lived paper particles have disappeared. These timestamps are the explicit test clock, not a simulator recording.

The earlier `preview.png` is a local reference and is not included in the public repository. Browser recording, if supported, is available under **Проверка движения**; it records only the card canvas, never the screen or user applications.

## Native integration

The six covers use the supplied emoji sets, separate palettes and Telegram's built-in wallpapers. Patterns were reviewed from the SVGs served by Telegram's wallpaper pages: like → variant1 (cheerful faces), dislike → variant10 (dark fantasy), heart → variant11 (Paris and romance), fire → variant2 (dragons and lightning), party → variant7 (balloons and gifts), poop → legacy (silly creatures). Wallpaper patterns use the normal native cache/download path; an opaque gradient is present while loading. Idle object motion runs at 20 updates per second, the expanded interaction at 60. Offscreen covers stop updating; Reduce Motion and Telegram's full-translucency energy setting disable object motion.

Scratch bursts use the corresponding native Animation Effect resource and DirectAnimatedStickerNode renderer, reduced from 380 pt to 140 pt and limited to three simultaneous bursts, no more than one every 0.24 s. The resource is prefetched when the cover appears. Until cached, local sparkles, angular flakes, hearts, embers, confetti or dust provide immediate feedback; a download never queues a late burst. Existing planar card tilt, the native SpaceWarp ripple, the 60% reveal threshold and the return animation remain in place.

All client-only labels, menu entries and VoiceOver actions use `ScratchCardStrings`, selected from Telegram's interface language. Russian and English are provided, with English as the fallback. Cover names contain no emoji; emoji remain in their preview icons. The menu entry uses the native `IconAnimation` renderer with `anim_scratch_card.json`, a monochrome vector finger gesture. Its artwork fits approximately 19–20 pt inside the standard 24 pt icon slot. The gesture makes two small side-to-side movements, returns to rest at frame 75 (1.25 s), then pauses until the 2.4 s loop repeats. It follows the menu text colour. Reduce Motion uses a static 19 pt `hand.draw` symbol.

The icon asset was also inspected in isolated WebKit/Lottie SVG renders at frames 0, 18, 30, 45, 60, 75, 96 and 143, in white on dark and black on light, at actual and enlarged sizes. Frames 30–60 show the short rubbing gesture; 75–143 stay at rest and match the initial pose. No edges are clipped. This checks the asset, not the native context menu renderer; the simulator recording described below is still required for native visual verification.

The first choice is **Обычная / Plain**: a static neutral film, without a wallpaper pattern, emoji, tilt, particles, ripple or automatic message effect. Scratching and its tactile feedback remain, followed by a simple fade and return. Its wire value is appended as 6, preserving the existing six styles (0–5) and legacy messages. It uses seven zero-width spaces in the versioned caption suffix.

Tapping the dimmed area outside the expanded card closes it through the existing cancellation/return path. The tap recognizer belongs to the background, not the card's touch surface. A scratch that begins on the card and ends outside must not close it, and the tap is never passed through to the frozen chat.

For supported private-cloud-chat destinations, sending a scratch photo attaches the corresponding free `EffectMessageAttribute` from Telegram's cached effect catalogue. An explicitly selected native effect takes priority. Stock clients receive the standard spoiler and effect; they control when the effect plays. This client gates playback until reveal. If the catalogue has not been cached, the sender cannot attach an unknown server effect id; the private-client local fallback still works once the catalogue is available. Albums follow Telegram's existing single-effect-per-album protocol.

Native verification still needed: this session has no exposed XcodeBuildMCP tools and no booted simulator. A successful full app build and host motion/marker checks do not verify rendered animation or delivery to another client.

Before recording, the expected frames are:

- All six covers remain opaque before scratching, including photos with captions and joined corners. No black diagonal plane appears.
- In the chat, emoji drift slowly without moving the bubble. On opening, the card expands together with its photo and cover in about 0.42 s.
- During a drag, nearby objects move away and acquire some finger inertia; release produces a damped return. The continuous scratch path stays under the finger. Small native effects originate at sampled finger positions, fade within 1.25 s and never cover the entire screen. With no cached effect or no connection, immediate local fragments expire within 0.9 s.
- At 60%, the film dissolves in about 0.32 s. The existing native ripple runs once, then the photo returns to its cell. The standard message effect starts only after this hand-off in this client.
- Closing before reveal restores the covered cell. Offscreen cards and Reduce Motion do not keep the emoji display link running.
- Open both levels of the picker menu in Russian and English, in light and dark themes. The scratch icon follows the other monochrome menu icons; the dark theme uses white. All cover names appear without repeated emoji, and both accessibility actions have the chosen interface language.
- Tap outside an untouched and a partially scratched card, including the hint area, then reopen it. It returns to its cell on the existing 0.3 s cancellation animation; the cover remains closed. No message is opened and no chat scroll or button action occurs beneath the tap. Drag from the card across its edge and release: this must keep the card open.
- Send and reopen Plain on both clients. The custom client shows neutral film with no emoji or moving decoration. At 60%, the remaining film fades for 0.22 s, followed by a subdued return; there must be no particles, ripple or full-screen native message effect. Existing themed messages must retain their original covers.

Record these paths on the dedicated simulator with `simctl io recordVideo`, then inspect timestamp-labelled frames using the repository's `tools/animation_sheet.py`. Also send to a stock client in a private chat to check the received effect independently of the local fallback.
