# Scratch cover collection

## Three sticker developments

Open **`sticker-directions.html`**. The three new studies are a dense overlapping collage, connected perforated paper strips with a neighbouring peel response, and softly raised stickers with a short press/drag/release motion. The chosen original appears below as a reference. Shared controls support individual/all demos, reset, touch without erasing and one local photo. The earlier comparison is preserved.

Expected animation before frame inspection: the collage retains overlapping layers while peeling stickers rise above them; the strip's touched tile leads neighbouring tiles by about 90 ms; raised stickers compress and follow the gesture for about 200 ms before releasing. New variants open the die-cut sticker/paper footprint as it leaves. There must be no detached vertical white strips, rectangular dark reflections, clipped card corners or leftover coating after completion. Final removal settles within 820 ms of crossing 60%; reset must clear every scheduled peel. This remains an offline Canvas study using system emoji, not Telegram's final animated assets or native iOS timing.

```sh
xcrun swiftc tools/verify-sticker-directions.swift -o /tmp/verify-sticker-directions
/tmp/verify-sticker-directions "$PWD/sticker-directions.html" /tmp/sticker-directions-qa
```

## Three heart directions on one page

Open **`heart-directions.html`** for the side-by-side comparison requested on 2026-10-29:

1. A heart emoji pattern which bunches up ahead of a scratch.
2. Emoji stickers with light borders and a folding/peeling response.
3. Particle hearts which break up into small vortices under touch.

Each cover has its own demo and reset. The header can run or reset all three, switch to touch without erasing, and select one local photo underneath all three. First and second directions use the browser's system emoji font as provisional artwork, not Telegram's animated emoji assets. The third is entirely procedural. No Apple emoji bitmap files are exported or embedded.

Expected frames before visual inspection: three visibly different surfaces; opaque coating at rest; a continuous scratch path; emoji displaced around contact; sticker fronts narrow while their pale backs fold over; particle hearts disperse near contact, with no already-erased particles reappearing at completion. All covers finish cleanly at 60%, reset without stale fragments, and fit a 390 px viewport.

```sh
xcrun swiftc tools/verify-heart-directions.swift -o /tmp/verify-heart-directions
/tmp/verify-heart-directions "$PWD/heart-directions.html" /tmp/heart-directions-qa
```

The isolated WebKit checker captures desktop/mobile layouts, touch, partial scratches, and 17 controlled-time frames per direction. It checks touch-without-erasing, actual pointer events, all completions, reset, ambient pause, reduced motion and local-photo input. Motion frame indices `00…16` are at test times `0.0…6.4 s`, every `0.4 s`. This is HTML verification, not native iOS frame pacing.

Observed in the controlled frame sheets: `emoji-motion-01…09` (0.4–3.6 s) show a continuous opened stroke with local pattern displacement; `stickers-motion-02…09` (0.8–3.6 s) show narrowing/folding stickers leaving the brushed area; `dust-motion-01…09` show disturbed particle hearts without reopening erased regions. All three sheets show the finishing transition at frame 10 (4.0 s) and a clean image by frame 11 (4.4 s), retained through frame 16. This samples the choreography; it does not measure smoothness or device FPS. The initial detached pale strips in sticker folds were corrected after frame inspection.

## Telegram visual-language revision

Open **`telegram.html`** for the current direction. `index.html` preserves the first, more illustrative study for comparison.

The revision puts one selectable cover inside an HTML chat mockup. It uses quiet mesh gradients, fine monochrome motifs and locally displaced dust, with smaller themed fragments while scratching. Controls select seven covers, light/dark appearance, a photo caption, ambient motion and a local image. This is an art-direction study, not a pixel-exact reproduction of the native chat or an approved final design.

The chat background embeds the existing Telegram resource `submodules/TelegramUI/Resources/fqv01SQemVIBAAAApND8LDRUhRU.tgv` as decompressed SVG. Cover motifs are new Canvas drawings. No network resources or exported Apple emoji bitmaps are used.

Verify the revision with the same harness:

```sh
xcrun swiftc tools/verify-webkit.swift -o /tmp/cover-collection-check
/tmp/cover-collection-check "$PWD/telegram.html" /tmp/cover-telegram-qa
```

In addition to the cover captures, it saves `chat-dark.png` and `chat-light-caption.png`. CSS transitions are disabled in the isolated harness so offscreen WebKit snapshots show the final DOM appearance; Canvas motion uses the deterministic clock described below. These captures do not verify native iOS motion or frame pacing.

## Original illustrative study

Independent local HTML design study. The Telegram application source and the earlier party-cover lab are unchanged by this prototype.

Open `index.html` directly in a modern browser. Everything is drawn with Canvas; it requires no installation, image downloads, external fonts, sign-in or server. Your selected photo stays in the browser.

## Explore

- Rub any cover with a mouse or finger. The film completes at approximately 60% coverage.
- Use the triangle button under a cover for an automatic scratch demonstration.
- Use the circular arrow to reset that cover.
- **Своя фотография** replaces the default landscape illustration beneath all covers with a local image.
- **Убрать фоновое движение** pauses ambient motion. Direct scratch interaction continues to work.
- Keyboard: focus a cover, Enter/Space starts its demonstration; Escape resets it.

## The seven studies

| Cover | Visual composition | Touch and scratch response |
| --- | --- | --- |
| Party | Cobalt paper, broad coloured ribbons, gifts and small confetti | Ribbons bend locally; short paper fragments fall away |
| Heart | Warm paper and a continuous wine-coloured line drawing | Lines shift gently; a small heart and fine heart fragments follow the contact |
| Fire | Charcoal engraving and warm layered flame shapes | Fresh edges glow; small embers rise |
| Like | Mint stamps and rounded approval symbols | Nearby stamps compress and rotate slightly; small sparkles |
| Dislike | Coral/cream printed strips and angular signs | Strips shift with a dry response; angular flakes |
| Poop | Ink doodles and small expressive faces | Eyes follow the pointer; nearby faces squash and react |
| Plain | Neutral matte surface | Clean scratch and fade, no decorative particles |

These are direction studies to judge composition and the feel of scratching. They do not reproduce iOS haptics, Telegram's native Animation Effects or the chat presentation/return transition. All drawings here are code-native vector/Canvas artwork; there are no exported Apple emoji bitmaps in the covers.

## Visual verification

Expected behaviour before inspection: seven clearly distinct compositions; opaque unbroken film at rest; continuous round-ended strokes without dot gaps; restrained fragments which fade; a clean landscape/photo at completion; Plain stays quiet. Paper, drawing, engraving, stamps and doodles should retain their own character while the same gesture reveals the image. No browser overflow on a 390 px viewport, no permanent animation on completed or offscreen cards, and no delayed particle burst after reset.

The isolated WebKit harness drives actual pointer events, checks partial masks and all seven completions, reset, ambient pause, Reduce Motion, finite particle state and mobile layout. It captures 17 timestamp-controlled motion frames per cover (119 total). These use a deterministic test clock; they are not a device FPS measurement or an iOS simulator recording.

```sh
xcrun swiftc tools/verify-webkit.swift -o /tmp/cover-collection-check
/tmp/cover-collection-check "$PWD/index.html" /tmp/cover-collection-qa
```

The harness writes each cover at rest, partly scratched and revealed, plus the motion frames and desktop/mobile page captures. The filenames `*-motion-00.png` through `*-motion-16.png` represent test times 0.0 through 6.4 seconds in 0.4-second steps.

Feature/design direction: [@meeckhaill](https://t.me/meeckhaill). Source additions follow the repository's GPL-2.0-or-later terms.
