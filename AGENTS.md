# Development guidance

Read [docs/BUILDING.md](docs/BUILDING.md) before building. Build the full Telegram application through the repository's Make.py wrapper; use the toolchain pinned in versions.json.

Keep personal API configuration, signing credentials, generated Xcode projects, build outputs and recordings outside Git. Preserve dependency gitlinks and their pinned commits.

For visual or animation changes, record the simulator, extract timestamp-labelled frames with tools/animation_sheet.py and inspect the complete transition. Build success alone does not verify appearance. Check haptics and frame pacing on a physical device.

Run python3 tools/check_public_repository.py, python3 build-system/Make/PostboxImportCheck.py and git diff --check before publishing changes.
