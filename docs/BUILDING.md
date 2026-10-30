# Building the application

This is the full Telegram iOS source tree with the scratch-card feature. Building the HTML lab does not build the application.

## Requirements

- A Mac, Git, Python 3 and Xcode with its command-line tools.
- Use the toolchain pinned in [`versions.json`](../versions.json). The verified target for this prototype is an Apple Silicon iOS simulator.
- Your own Telegram `api_id` and `api_hash` from [my.telegram.org/apps](https://my.telegram.org/apps).
- Your own bundle identifier and Apple development team for a physical-device build.

## Clone your published repository

Use the URL of this fork, rather than the upstream URL, to include the feature:

```sh
git clone --recurse-submodules https://github.com/YOUR_GITHUB_LOGIN/scratch-cards-ios.git
cd scratch-cards-ios
git submodule update --init --recursive
```

The GitHub login is independent of the author's Telegram username. Replace the example URL with the actual destination.

## Personal configuration

```sh
cp build-system/public-development.example.json build-system/local_configuration.json
```

Edit `local_configuration.json`: replace the `YOUR_*` placeholders, choose a unique `bundle_id`, and use your own Apple team. This file is ignored by Git. Do not edit the upstream app-store configuration to hold your personal credentials.

## Generate the Xcode project

For a device build with Xcode-managed signing:

```sh
python3 build-system/Make/Make.py \
  --cacheDir="$HOME/telegram-bazel-cache" \
  generateProject \
  --configurationPath=build-system/local_configuration.json \
  --xcodeManagedCodesigning
```

For simulator-only development, use the same command with `--disableProvisioningProfiles` after `--xcodeManagedCodesigning`. That generated project is not suitable for installing on an iPhone until regenerated with signing enabled.

The generator may close Xcode; save open work first. Open the generated `Telegram/Telegram.xcodeproj`, choose the **Telegram** app scheme and your simulator or device, then build the whole app. The wrapper uses Bazel for the application build; selective module builds are not the supported verification path.

Xcode-managed generation omits extensions. Push notifications, iCloud and other capabilities require your own compatible signing and configuration; this guide does not provision production services.

See the preserved [upstream compilation guide](UPSTREAM_BUILD.md) for explicit profiles and release IPA builds. Those steps need your own signing assets and do not create a public release automatically. The full app has been built during feature development; the new example configuration is a template to fill in, not a separately verified signed build.

## HTML lab

Open [`prototypes/party-cover/index.html`](../prototypes/party-cover/index.html) in a browser. It is independent of Telegram login and iOS signing. Read its [README](../prototypes/party-cover/README.md) for the build command and asset notes.

## Validation

```sh
python3 tools/check_public_repository.py
python3 build-system/Make/PostboxImportCheck.py
git diff --check
```

These are source checks, not an iOS build. For visual changes, record the app in a simulator and inspect timestamp-labelled frames as described in [`AGENTS.md`](../AGENTS.md). Check haptics on a supported physical iPhone.
