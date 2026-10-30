# Native verification

The full Telegram simulator application was built during development. An isolated UIKit host records and exercises the actual scratch-card component without a Telegram account.

## Covered paths

- All seven covers, Russian/English labels and dark/light appearances.
- Continuous scratch strokes, 50% completion on release and 81% automatic completion.
- Idle gesture coaching, partial cancellation and exactly-once completion.
- Outside-tap closing, bounds-change cancellation and source position/size on return.
- Rounded return contours, asymmetric corners and caption joins.
- Uniform sticker coverage, short-palette mixing and proportional source/expanded layouts.
- Shared asynchronous closed-cover textures and stale-result cancellation.
- Opaque tinted photo silhouettes, fine-detail suppression and prepared-texture reuse.

Recordings were inspected frame by frame during development. Raw recordings, frame sheets, local device identifiers and temporary build logs are not included in the public source snapshot.

## Remaining verification

The component host does not certify account/chat routing, actual bubble-tail artwork, native SpaceWarp/message-effect rendering, physical-device frame pacing or haptics. Full-chat checks should include caption positions, both dismissal methods, dragging outside the card, Reduce Motion, both languages and delivery to a stock client.

See [BUILDING.md](BUILDING.md) for the application build and [SCRATCH_CARDS.md](SCRATCH_CARDS.md) for the implementation. The standalone model check is tools/check_scratch_sticker_model.swift; the UIKit target is //submodules/InvisibleInkDustNode:ScratchCardRenderingTests. Its simulator/runtime pin may need updating for another development machine.
