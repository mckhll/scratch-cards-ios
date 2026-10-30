# Scratch Cards for iOS

**Scratch a photo to reveal it, right inside the chat.**

An experimental feature for an unofficial Telegram iOS client, built on [Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS).

**Scratch-card feature by [@meeckhaill](https://t.me/meeckhaill).**

[Русский](README.ru.md) · [Build](docs/BUILDING.md) · [Implementation](docs/SCRATCH_CARDS.md) · [Contribute](.github/CONTRIBUTING.md)

<!-- Add a demo GIF or screenshots here when ready. See docs/media/README.md. -->

## The interaction

Send a covered photo. Tap the cover to bring it forward while keeping the chat visible, then rub with your finger to reveal the picture. The card returns to its message when you finish. Tap outside it or use the close button to cancel.

- Continuous scratch strokes with tactile feedback on supported iPhones.
- Six themed covers: 👍 👎 ❤️ 🔥 🎉 💩, with paper-style emoji stickers that react to touch and peel away.
- A **Plain** cover with a neutral film and no emoji or themed effects.
- Small native message-effect bursts while scratching themed cards.
- Reveal on release after **50%** coverage, or automatically at **81%**, followed by the native ripple and return for themed cards.
- Russian and English labels, VoiceOver actions and a reduced-motion alternative for the menu icon.

This repository contains the **full iOS application source**, plus an independent [HTML cover lab](prototypes/party-cover/README.md) for experimenting with the interaction.

## Try it

1. Build and run the application using the [build guide](docs/BUILDING.md).
2. Select a photo and open the media picker's options menu.
3. Choose **Scratch Card**, then **Plain** or one of the six themes, and send it.
4. Tap the received cover and rub the film away.

## Compatibility

The prototype sends an ordinary Telegram photo spoiler with an invisible, versioned marker at the end of its caption. This client interprets the marker as a scratch card. Standard Telegram clients display a normal spoiler.

Themed cards can also carry a **standard Telegram Animation Effect** in supported private cloud chats. This client delays that effect until the scratch interaction finishes; other clients use their own playback rules. Plain does not automatically attach an effect.

The marker is prototype metadata, not a new Telegram protocol type. Editing the caption in another client may remove it. It uses part of the caption limit, and albums follow Telegram's existing single-effect-per-album behaviour. See the [implementation notes](docs/SCRATCH_CARDS.md).

## Development status

This is a working prototype for design exploration, not a production release. The complete app has been compiled for an Apple Silicon simulator. Host checks cover caption-marker compatibility; the HTML and menu-icon assets have been reviewed separately. Native UIKit component recordings and source checks have also been reviewed. Full-chat/device checks and delivery against a stock client remain separate verification steps.

There is no prebuilt public IPA or TestFlight release configured by this repository. GitHub Actions runs source checks only and does not publish binaries.

## Build and explore

- [Build the iOS application](docs/BUILDING.md)
- [Feature architecture and verification](docs/SCRATCH_CARDS.md)
- [Interactive HTML lab](prototypes/party-cover/README.md)
- [Prepare a GitHub publication](docs/PUBLISHING.md)
- [Changelog](CHANGELOG.md)

## Credits and license

Scratch-card feature author: **[@meeckhaill](https://t.me/meeckhaill)**. The underlying messaging client is by Telegram and its contributors. This project is independent and is not an official Telegram release.

Telegram identifies its iOS source as [GNU GPL version 2 or later](https://telegram.org/apps#source-code). The fork's scratch-card source additions use the same terms; GPL v2's text is included in [LICENSE](LICENSE). Dependencies, artwork, emoji and trademarks retain their respective terms. See [NOTICE.md](NOTICE.md) for attribution and asset provenance.
