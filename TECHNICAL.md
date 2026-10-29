# GoodThing Pet — Technical Documentation

If you only want to install and play, read the [README](README.md). This document is for anyone building from source, changing the code, or deploying the app for someone else.

---

GoodThing Pet is a character accessory that lives on the macOS desktop. It uses the likeness of the Chinese creator FengGe (峰哥亡命天涯) and 11 voice clips cut from two MP3 recordings of his remarks. Clicking the character plays a random line.

## What problem this solves

If you want a favorite character and its voice on your desktop for quick interaction, opening a recording and hunting for a particular sentence is tedious. This app cuts a continuous recording into short clips, plays one when you click the desktop character, and provides simple playback and appearance settings.

## Main features

- **Transparent floating character.** The character is drawn in front of normal windows, without a Dock icon. A menu bar item shows the character's face.
- **Random playback.** Clicking the character plays one of 11 clips. No clip repeats within a cycle, and the first clip of the next cycle does not immediately repeat the previous clip.
- **Click to switch.** Clicking again stops the current clip and starts the next one; audio never overlaps.
- **Talking animation and captions.** While a clip plays, the character compresses vertically and springs back without changing width, and a caption shows the current line. On macOS 26 and newer the caption is drawn in Liquid Glass; older systems use a translucent rounded bubble. When macOS Reduce Motion is enabled, the character stays still.
- **Dragging and settings.** Drag the character to move it. Right-click it, or click the menu bar item, to choose a specific clip, stop playback, adjust volume and character size, move the pet back to the bottom-right corner, or quit. Position, volume and size are persisted.
- **Changeable menu bar picture.** The menu bar item shows the pet's face by default. **Menu bar picture** in the settings menu switches it back to text, or lets you choose any image file; the picture is copied into the app's support folder and scaled to menu bar size.
- **Companion mode.** If [SunPet](https://github.com/Ganzhe2028/SunPet) or [ShaolanPet](https://github.com/Ganzhe2028/ShaolanPet) is running on the same desktop, GoodThing replies after a qualifying line from another pet, forming a short comedy exchange. See [The three pets](#the-three-pets).

## Installation

Requires an **Apple Silicon Mac** and **macOS 14 or newer**. Running the app needs no Python, speech-recognition model or network connection.

### Option 1: Download a release (recommended)

The repository does not store binaries. Releases are on the [Releases](https://github.com/XenoChrome370/Desktop-Pet/releases) page.

1. Download the latest `GoodThingPet-x.y.dmg` and open it.
2. Drag `GoodThingPet.app` into the **Applications** folder.
3. Open it from Applications. The app uses an ad-hoc signature and is not notarized by Apple, so Gatekeeper blocks the first launch: right-click the app and choose **Open**, or go to **System Settings › Privacy & Security** and click **Open Anyway**.

You can also download the zip, but **extract it by double-clicking in Finder**. Terminal `unzip` mishandles non-ASCII Chinese filenames, reports `write error (disk full?)` and silently drops files. This is a long-standing Info-ZIP problem, not a corrupt archive.

### Option 2: Build from source

Requires `swiftc` from the Xcode Command Line Tools; install with `xcode-select --install`. The Liquid Glass caption uses `NSGlassEffectView`, so compiling needs the macOS 26 SDK (Xcode 26 or newer Command Line Tools). The resulting app still runs on macOS 14 and newer; older systems use the fallback caption. From the project root:

```sh
./build.sh          # compile and run the self-test; prints PASS on success
./install.sh        # install into Applications, clear quarantine, and launch
```

The build output is `build/GoodThingPet.app`; you can also drag it into Applications manually. To distribute it to others, run `./build.sh --package`, which produces a zip, a dmg and a sha256 checksum file under `dist/`. To uninstall, run `./install.sh --uninstall` (position, volume and other settings are kept).

### Option 3: Build with Xcode

Open `GoodThingPet.xcodeproj`, choose the `GoodThingPet` scheme, and run. The shared scheme is checked in, so a fresh clone needs no scheme setup. The project uses:

- product name `GoodThingPet`, bundle identifier `local.goodthing.desktop-pet`
- deployment target macOS 14.0, architecture `arm64`
- Swift language mode 5.0
- ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`)
- `LSUIElement` enabled through `Xcode/Info.plist`
- the same resources as `build.sh`: `Assets/clips.json`, `Assets/face.png`, `Assets/AppIcon.icns`, and `Assets/Clips` copied as a folder

Build from the command line:

```sh
xcodebuild -project GoodThingPet.xcodeproj -scheme GoodThingPet -configuration Release build
```

The Xcode build is an alternative to `build.sh`, not a replacement. `build.sh` is still the canonical path for release packaging and for the `--self-test` check.

## Usage

| Action | Result |
| --- | --- |
| Single-click the character | Play a random clip, show its caption and start the vertical compression animation |
| Click again during playback | Stop the current clip and play the next one |
| Drag the character | Move the floating window; the position is remembered after quitting |
| Right-click the character or click the menu bar item | Open the settings menu |
| Menu → **Menu bar picture** | Show the pet picture, switch to a text label, or choose a custom image |
| Menu → **Choose a clip** | Play the selected clip immediately |
| Menu → **Stop playback** | Stop the audio, hide the caption and end the animation |
| Menu → **Quit pet** | Quit the app |

### The three pets

The fourth pet, [JellyPet](https://github.com/aurelius358/JellyPet), is a shape accessory with no voice. It is not part of the `Bridge.swift` protocol and does not reply.

The three pets share one companion protocol and talk to each other when running together:

```text
Shaolan ──> SunPet ──> FengGe ──> SunPet
```

| Pet | Says | Role in the chain |
| --- | --- | --- |
| [GoodThing Pet](https://github.com/XenoChrome370/Desktop-Pet) | FengGe · 11 "this is a good thing" clips | Answers SunPet, but only in a chain started by Shaolan |
| [SunPet](https://github.com/Ganzhe2028/SunPet) | Sun Yuchen · 28 "too right" clips | Answers anyone |
| [ShaolanPet](https://github.com/Ganzhe2028/ShaolanPet) | Shao Ailun · 37 clips | Starts the chain; never answers |

Clicking Shaolan starts a chain that runs to the end: SunPet → FengGe → SunPet, four lines total, stopping at the fourth. Clicking FengGe gets one reply from SunPet and then stops. Clicking SunPet gets no reply.

There is no direct channel between FengGe and Shaolan. Once SunPet finishes the FengGe chain, the chain is over; it cannot continue indefinitely. The cap is a hop count carried in each notification, not a rule each pet has to remember.

When [SunPet](https://github.com/Ganzhe2028/SunPet) (the `SunPet` menu bar item) or [ShaolanPet](https://github.com/Ganzhe2028/ShaolanPet) is also running, GoodThing joins in automatically: after you click FengGe and the line finishes, the other pet answers with a short reply under one second, forming a comedy exchange.

- **Both apps must be running.** No pairing, ports or network are involved. If SunPet quits, companion mode stops automatically; the menu item changes from `Link: listening to SunPet` to `Link: SunPet not running`.
- **Overlapping handoff.** The other pet starts roughly 0.3 seconds before the current line ends. This is not meant to interrupt; waiting until the line fully ends leaves an audible gap that sounds like a glitch. The second hop (SunPet replying after FengGe) is tightened to 0.2 seconds so the four steps do not drag.
- **FengGe replies only in a chain started by Shaolan.** If you click FengGe yourself, only SunPet answers once and stops; FengGe is not brought back for another line. If SunPet quits without notice, only this exchange is lost; normal FengGe playback is unaffected.

Implementation: the three apps send a local notification through `DistributedNotificationCenter`. Whether a peer is running is checked with `NSRunningApplication` by bundle identifier, not by "send a message and see if anyone answers". The protocol and liveness checks live in `Sources/Bridge.swift`; each of the three repositories holds an identical copy, so changes must be synchronized.

## FAQ

| Symptom | Cause and fix |
| --- | --- |
| Double-clicking the app does nothing and no Dock icon appears | An instance is already running. Only one copy of the app may run; a second launch exits silently. Look for the pet-face item (or the `GoodThing` text item) at the right end of the menu bar. |
| "App is damaged and should be moved to the Trash" or "unidentified developer" | The app is ad-hoc signed and not notarized, so Gatekeeper blocks it. Right-click the app and choose **Open**, or go to **System Settings › Privacy & Security** and click **Open Anyway**. If that fails, run `xattr -dr com.apple.quarantine /Applications/GoodThingPet.app` in Terminal. |
| Extraction reports `write error (disk full?)` and files are missing | A known problem with terminal `unzip` and non-ASCII filenames; the disk is not actually full. Extract by double-clicking in Finder, or use `ditto -x -k archive.zip destination`. |
| No sound when clicking the character | Check **Volume** in the settings menu and confirm the system output device and volume. |
| The character was dragged off-screen, or is lost after changing displays | Menu → **Move back to bottom-right**. |
| The old version still opens after reinstalling | The old process is still running. `./install.sh` quits it before installing. |

## Input and output examples

This is a desktop app with no command-line text input. Its input is mouse interaction; its output is animation, captions and audio. For example:

```text
Input:  right-click the character → Choose a clip → 11 人有欲望是好事
Output: play the 11th original clip; show the caption “人有欲望是好事”;
        compress the character vertically and spring it back.

Input:  click the character again during playback
Output: stop the current audio; take the next clip from the random queue and play it;
        two clips never sound at the same time.
```

Volume, character size and the window position after dragging are stored in macOS user defaults.

## Project files

| Path | Purpose |
| --- | --- |
| `Sources/main.swift` | Transparent window, mouse handling, random playback, animation, menus, Liquid Glass caption, menu bar picture and self-test |
| `Sources/Bridge.swift` | Companion channel with SunPet: notification protocol and peer liveness checks. Identical in both repositories |
| `Assets/face.png` | Character image with a transparent background |
| `Assets/Clips/` | 11 cropped WAV audio files |
| `Assets/clips.json` | Clip ID, text label, filename and duration for each audio file |
| `Work/cuts.json`, `Work/audio-cut-notes.md` | Mapping between the source recordings and each clip's cut points |
| `GoodThingPet.xcodeproj` | Native Xcode project and shared `GoodThingPet` scheme |
| `Xcode/Info.plist` | Bundle identifier, version, `LSUIElement` and other bundle settings used by Xcode |
| `build.sh` | Environment checks, compile, resource bundling, ad-hoc signing, self-test; `--package` produces distributables |
| `install.sh` | Install into Applications, clear the download quarantine flag, launch; `--uninstall` removes the app |
| `.github/workflows/release.yml` | Builds and publishes zip, dmg and checksums when a `v*` tag is pushed |

The code and documentation in this project are MIT licensed under the root `LICENSE`. The original version came from [yuhanfu513-ops/FengGe-Desktop-Pet](https://github.com/yuhanfu513-ops/FengGe-Desktop-Pet); this repository continues from it. The interaction and playback design was inspired by SunPet, whose original author's MIT license is preserved in [`licenses/SunPet-MIT.txt`](licenses/SunPet-MIT.txt). The character image and voice clips are outside these code licenses.

## Adding a fourth character

The three repositories are copies of the same code. Adding a character means repeating the pattern:

1. Add a case to the `PetRole` enum in `Sources/Bridge.swift`, with the new bundle identifier as its value, and add a display name.
2. The `peers` list decides "who I listen to". Each of the three copies hard-codes its own list: add the characters it should answer; leave `peers` empty for a character that only speaks and never answers.
3. `Sources/Bridge.swift` must be byte-identical across all three repositories (`md5` must match). Changing one copy requires syncing all three, otherwise the companion chain works only halfway.
4. For a new repository, copy any existing one, replace the audio in `Assets/`, `clips.json`, `face.png` and the bundle identifier, then run `./build.sh --package` to produce an installer.

Do not edit `Sources/Bridge.swift` in only one repository. The shared file is the protocol; the per-pet configuration is `me` and `peers` at the call site in `main.swift`.
