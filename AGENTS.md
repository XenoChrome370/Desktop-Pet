# AGENTS.md

For AI agents working in this repository. Humans should read [README.md](README.md); technical details are in [TECHNICAL.md](TECHNICAL.md); asset rights are in [NOTICE.md](NOTICE.md).

## Build and verification

- `./build.sh` compiles and runs `--self-test`. The last line must be `PASS`; if it is not, the work is not finished.
- `./install.sh --build` installs into /Applications and launches. `./build.sh --package` produces zip, dmg and sha256 files under `dist/`.
- Only Apple Silicon + macOS 14 is supported. The build script hard-codes arm64; do not change it for Intel.
- `GoodThingPet.xcodeproj` is the native Xcode project. It must build with the shared `GoodThingPet` scheme and use the same bundle identifier, resources and Info.plist settings as `build.sh`.
- Diagnostic entry points: `--self-test`, `--dump-state`, `--trace`, `--bridge-test`.

## Constraints that must not be broken

- `Sources/Bridge.swift` must be **byte-identical** across the SunPet / ShaolanPet / FengGe-Desktop-Pet repositories. Change one, change all three. Verify with `md5 -q Sources/Bridge.swift` on all three copies.
- Because of the rule above, do not translate or reformat `Sources/Bridge.swift` in this repository alone. Its Chinese display names and comments are part of the shared file.
- `LICENSE` contains only the standard MIT text. Asset rights live in `NOTICE.md`; third-party code licenses live in `licenses/`. Appending exceptions to the end of `LICENSE` makes GitHub report `NOASSERTION`, so the repository no longer appears in MIT-filtered searches. Verify with `gh api repos/XenoChrome370/Desktop-Pet --jq .license.spdx_id`, which must return `MIT`.
- README is a landing page for ordinary viewers. Keep it focused on the four interlinked faces, the install steps, a short personal note, and the project's stance. Long technical write-ups belong in TECHNICAL.md.
- The four faces at the top of README are links to four **independent apps**, not four skins of one app. Do not remove that clarification.
- Binaries do not go into the repository; installers go through Releases.

## Release

Pushing a `v*` tag triggers `.github/workflows/release.yml`, which builds and uploads `GoodThingPet-<version>.dmg/.zip/.sha256`. Keep asset naming consistent across the three repositories; README must tell users to download the latest `.dmg`.

## Companion protocol

The three pets talk to each other through `DistributedNotificationCenter`, using the `hop` and `root` fields to prevent loops. Before adding a character, read "Adding a fourth character" in TECHNICAL.md, and check all three places: `peers`, the hop cap, and the `root` condition. `--self-test` does not cover the companion protocol; do not use a `PASS` result to claim the link works. The fourth project, [JellyPet](https://github.com/aurelius358/JellyPet), is a shape accessory by another author with no voice, and is not part of this protocol.

## This repository

- App: `GoodThingPet.app`, bundle id `local.goodthing.desktop-pet`
- Position in the four-step chain: FengGe, which replies only inside a chain started by Shaolan
- peers: `[.sunpet]`
