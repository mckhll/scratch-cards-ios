# Contributing

This fork explores scratch-to-reveal photos in an unofficial Telegram iOS client. The feature author is [@meeckhaill](https://t.me/meeckhaill). Open feature issues and pull requests in this fork; its changes are not official Telegram features.

## Start here

Read the [build guide](../docs/BUILDING.md), [feature notes](../docs/SCRATCH_CARDS.md) and [AGENTS.md](../AGENTS.md). Keep changes focused and preserve stock-client spoiler compatibility and existing caption-marker values.

Use your own local API/signing configuration. Include no personal messages, session files or signing material in an issue or pull request.

## Verification

For source/documentation changes:

```sh
python3 tools/check_public_repository.py
python3 build-system/Make/PostboxImportCheck.py
git diff --check
```

For native code, build the complete Telegram application. For visual changes, state what the animation should do, record it in the simulator and inspect timestamp-labelled frames using `tools/animation_sheet.py`; a green build alone does not verify appearance. Check tactile feedback on a supported iPhone.

Describe the visible result, tests performed and anything still unverified. Include iOS/Xcode versions for build failures. Source additions follow GPL-2.0-or-later; preserve dependency and artwork notices.
