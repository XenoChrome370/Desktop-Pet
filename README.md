<h1 align="center">GoodThing Pet</h1>

<p align="center"><b>William Yao's personal macOS desktop pet</b> — a transparent, always-on-top character that speaks one of 11 original voice clips when you click it.</p>

<p align="center">macOS 14+ · Apple Silicon only ｜ <a href="https://github.com/XenoChrome370/Desktop-Pet/releases/latest"><b>Download the latest release</b></a></p>

<p align="center">Unofficial fan project · No network access · No permissions · No Dock icon</p>

<p align="center">Maintained by <a href="https://github.com/XenoChrome370">@XenoChrome370</a> · Forked from <a href="https://github.com/Ganzhe2028/FengGe-Desktop-Pet">Ganzhe2028/FengGe-Desktop-Pet</a> · MIT licensed code</p>

---

## The four pets

<table align="center" width="100%">
<tr>
<td align="center" width="25%"><a href="https://github.com/Ganzhe2028/ShaolanPet"><img src="https://github.com/Ganzhe2028/ShaolanPet/raw/main/Assets/face.png" width="110"></a></td>
<td align="center" width="25%"><a href="https://github.com/Ganzhe2028/SunPet"><img src="https://github.com/Ganzhe2028/SunPet/raw/main/Assets/face.png" width="110"></a></td>
<td align="center" width="25%"><a href="https://github.com/XenoChrome370/Desktop-Pet"><img src="https://github.com/XenoChrome370/Desktop-Pet/raw/main/Assets/face.png" width="110"></a></td>
<td align="center" width="25%"><a href="https://github.com/aurelius358/JellyPet"><img src="https://github.com/aurelius358/JellyPet/raw/main/Assets/claude-mark.png" width="110"></a></td>
</tr>
<tr>
<td align="center">Shaolan</td>
<td align="center">SunPet</td>
<td align="center"><b>GoodThing</b><br><sub>you are here</sub></td>
<td align="center">JellyPet</td>
</tr>
</table>

These are four independent apps, not four skins of the same app. Click a face to open its repository.

Shaolan, SunPet and GoodThing reply to each other when they run at the same time, forming a short comedy chain. JellyPet is a separate project by another author and is not part of this protocol.

## About this build

I'm William Yao ([@XenoChrome370](https://github.com/XenoChrome370)). This is my personal fork of [FengGe-Desktop-Pet](https://github.com/Ganzhe2028/FengGe-Desktop-Pet), kept as a working macOS app that I can build and modify locally.

Compared with upstream, this copy has English documentation and in-app text, a checked-in native Xcode project alongside the shell build, a Liquid Glass caption on macOS 26 and newer, a changeable menu bar picture, and a fix for the missing `LICENSE-SunPet` resource that previously stopped `build.sh` on a clean checkout. The pet's behavior is otherwise unchanged: the same 11 clips, the same interaction model, and the same companion protocol.

## What you get

- **A transparent floating character.** It sits in front of normal windows and never takes keyboard focus. There is no Dock icon; an item showing the pet's face appears in the menu bar instead.
- **11 original voice clips.** Click the character to play one at random. A full cycle never repeats a clip, and the first clip of the next cycle will not immediately repeat the previous one.
- **Click again to interrupt.** The current clip stops and the next one starts; two clips never play over each other.
- **Captions and a talking animation.** The character compresses vertically and springs back while a caption shows the line being spoken. On macOS 26 and newer the caption is Liquid Glass. The animation is disabled automatically when macOS Reduce Motion is on.
- **Drag to reposition.** Right-click the character, or click the menu bar item, to choose a specific clip, stop playback, adjust volume, change the character size, move the pet back to the bottom-right corner, or quit. Position, volume, size, playback mode and excluded clips are remembered.
- **A menu bar picture you can change.** The menu bar item shows the pet's face by default; **Menu bar picture** in the settings menu switches to a text label or to any image file you choose.
- **A rotation playlist.** Uncheck any of the 11 clips in the menu to keep it out of random playback; at least one clip always remains.
- **Companion mode.** When SunPet or Shaolan is also running, GoodThing answers within a chain. See [companion chain](#companion-chain).

## Install

You only need one pet to start. Install all three if you want them to talk to each other.

1. Download the latest `.dmg` from [Releases](https://github.com/XenoChrome370/Desktop-Pet/releases/latest).
2. Open it and drag `GoodThingPet.app` into **Applications**.
3. The first launch shows "unidentified developer" because the app is ad-hoc signed, not notarized. Right-click the app and choose **Open**. This is expected and does not mean the app is malicious.

Not sure whether your Mac is Apple Silicon: open  → **About This Mac**; a chip name starting with `Apple M` qualifies.

If you still cannot install, want to build it yourself, or want to swap the face or the voice, read [TECHNICAL.md](TECHNICAL.md).

## Build from source

Requires macOS 14+, an Apple Silicon Mac, and the Xcode Command Line Tools. Compiling the Liquid Glass caption requires the macOS 26 SDK (Xcode 26 or newer); the built app itself still runs on macOS 14 and newer.

```sh
./build.sh          # compile, then run the built-in self-test; the last line must be PASS
./install.sh        # install into /Applications, clear the quarantine flag, and launch
./build.sh --package  # produce GoodThingPet-<version>.zip, .dmg and .sha256 in dist/
```

There is also a native Xcode project at `GoodThingPet.xcodeproj`. Open it, select the `GoodThingPet` scheme, and press <kbd>⌘R</kbd>. The project uses the same bundle identifier, resources and `Info.plist` settings as `build.sh`, so either route produces the same app.

## The 11 clips

The audio is the original Chinese voice. Captions and menu entries show the original transcript; the English meaning is below for reference.

| # | Transcript | Meaning |
| ---: | --- | --- |
| 01 | 这个是个好事 | This is a good thing |
| 02 | 这是个好事 | This is a good thing |
| 03 | 是个好事 | It's a good thing |
| 04 | 这是个好事啊 | This is a good thing |
| 05 | 这是一个好事啊 | This is a good thing |
| 06 | 这是个好事啊 | This is a good thing |
| 07 | 那这是个好事吗 | So is this a good thing? |
| 08 | 挺好的啊 | Pretty good |
| 09 | 这是个好事啊 | This is a good thing |
| 10 | 对你挺好的 | It's good for you |
| 11 | 人有欲望是好事 | Desire is a good thing |

## Companion chain

```text
Shaolan ──> SunPet ──> GoodThing ──> SunPet
```

Clicking Shaolan starts a four-step chain that ends after SunPet's second reply. Clicking GoodThing directly gets only one reply from SunPet. Clicking SunPet alone gets no reply. The chain is capped by a hop counter carried in each notification, so it cannot loop forever.

The pets communicate over `DistributedNotificationCenter` on the local machine. They do not open ports, pair devices or use the network. Liveness is checked through `NSRunningApplication` by bundle identifier. The shared protocol lives in `Sources/Bridge.swift`, which must remain byte-identical across the three sibling repositories.

## Project layout

| Path | Purpose |
| --- | --- |
| `Sources/main.swift` | Window, mouse handling, playback, animation, menus, settings and self-test |
| `Sources/Bridge.swift` | Cross-pet notification protocol and peer liveness checks |
| `Assets/face.png` | Transparent character image |
| `Assets/Clips/` | 11 cropped WAV voice clips |
| `Assets/clips.json` | Clip IDs, transcripts, filenames and durations |
| `GoodThingPet.xcodeproj` | Native Xcode project |
| `build.sh` | Environment checks, compile, resource bundling, ad-hoc signing, self-test and packaging |
| `install.sh` | Install to Applications, clear quarantine, launch; `--uninstall` removes it |
| `.github/workflows/release.yml` | Builds and publishes zip, dmg and checksums when a `v*` tag is pushed |

## Make it yours

The code is MIT licensed. Replace the face, the audio and `clips.json`, change the bundle identifier, and you have your own desktop pet. A Windows version does not exist yet; contributions are welcome.

The character image and voice clips are **not** covered by the MIT license and remain the property of their respective rights holders. This project is for personal, non-commercial use. See [NOTICE.md](NOTICE.md) for details.

Bugs and feature requests: open an [issue](https://github.com/XenoChrome370/Desktop-Pet/issues).
