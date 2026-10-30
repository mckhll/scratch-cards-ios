# Attribution and licensing

## Scratch-card feature

Feature author: **[@meeckhaill](https://t.me/meeckhaill)**.

The scratch-card source additions in this fork are distributed under **GPL-2.0-or-later**, consistent with Telegram's published license for its iOS application source. Attribution to this feature does not claim authorship of Telegram or pre-existing changes in the base tree.

## Telegram and dependencies

Base application: [TelegramMessenger/Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS), by Telegram and its contributors. Telegram's [applications page](https://telegram.org/apps#source-code) identifies the iOS source license as GNU GPL v2 or later. The [LICENSE](LICENSE) file contains GPL v2's text.

Libraries and other components retain the copyright notices and license terms in their own directories and submodules. This notice does not relicense those components. Keep their license files when redistributing the source or binaries.

Telegram names, logos, wallpapers and server-provided animation resources belong to their respective rights holders. This project is not endorsed by or affiliated with Telegram. See the [Telegram API terms](https://core.telegram.org/api/terms) for application branding and API requirements.

## Feature assets

- `anim_scratch_card.json` is the feature's vector menu animation and follows the source additions' GPL-2.0-or-later terms.
- Native emoji are rendered by the operating system. Telegram wallpaper patterns and message effects use the client's existing resource pipeline.
- The public HTML lab renders emoji at runtime using the browser's system fonts. Its earlier PNG exports from **Apple Color Emoji**, and the old preview containing them, are kept locally and excluded from Git. The default HTML builder does not embed them. The font is not included or relicensed. If you later add custom bitmap artwork, include its provenance and redistribution terms.
- Screenshots and recordings added for the README should show a test chat and media you are entitled to publish.
