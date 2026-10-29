#!/bin/bash
# Build GoodThing Pet: environment checks → compile → bundle resources → ad-hoc sign → self-test → (optional) distributables
#
#   ./build.sh                 compile and self-test; output in build/GoodThingPet.app
#   ./build.sh --package       also produce zip, dmg and sha256 checksums in dist/
#   ./build.sh --no-self-test  skip the self-test (for environments without a GUI session)
#
# Environment: PET_VERSION (default 1.1), PET_BUILD (default 2)
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="GoodThingPet"
DISPLAY_NAME="GoodThing Pet"
EXECUTABLE="GoodThingPet"
BUNDLE_ID="local.goodthing.desktop-pet"
VERSION="${PET_VERSION:-1.1}"
BUILD_NUMBER="${PET_BUILD:-2}"
DEPLOY_TARGET="arm64-apple-macosx14.0"
BUNDLE="build/$APP_NAME.app"
DIST="dist"
PACKAGE=0
SELF_TEST=1

for arg in "$@"; do
    case "$arg" in
        --package) PACKAGE=1 ;;
        --no-self-test) SELF_TEST=0 ;;
        -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
        *) printf 'Unknown argument: %s (available: --package / --no-self-test / --help)\n' "$arg" >&2; exit 2 ;;
    esac
done

die() { printf '\nBuild aborted: %s\n' "$1" >&2; exit 1; }

check_environment() {
    [ "$(uname -s)" = "Darwin" ] || die "This project builds on macOS only; current system is $(uname -s)."
    local arch
    arch="$(uname -m)"
    if [ "$arch" != "arm64" ]; then
        die "This project supports Apple Silicon (arm64) only; current architecture is $arch. On an Intel Mac, change DEPLOY_TARGET to x86_64-apple-macosx14.0 and verify the build yourself."
    fi
    local os_major
    os_major="$(sw_vers -productVersion | cut -d. -f1)"
    if [ "$os_major" -lt 14 ]; then
        die "macOS 14 or newer is required; current version is $(sw_vers -productVersion)."
    fi
    if ! command -v swiftc >/dev/null 2>&1; then
        die "swiftc not found. Install the Xcode Command Line Tools first:
    xcode-select --install
Then rerun this script (a full Xcode install is not required)."
    fi
}

compile() {
    printf 'Compiling…\n'
    rm -rf "$BUNDLE"
    mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
    if ! swiftc -O -target "$DEPLOY_TARGET" -framework AppKit -framework AVFoundation \
        Sources/main.swift Sources/Bridge.swift -o "$BUNDLE/Contents/MacOS/$EXECUTABLE"; then
        die "swiftc failed. Please paste the full error above into an issue:
    https://github.com/XenoChrome370/Desktop-Pet/issues"
    fi
    if [ ! -f Assets/face.png ]; then
        die "Assets/face.png is missing; the asset bundle is incomplete. Extract the archive with Finder, not terminal unzip (which mishandles non-ASCII filenames and drops files)."
    fi
    cp -R Assets/. "$BUNDLE/Contents/Resources/"
    cp LICENSE "$BUNDLE/Contents/Resources/LICENSE"
    cp licenses/SunPet-MIT.txt "$BUNDLE/Contents/Resources/LICENSE-SunPet"
    cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$EXECUTABLE</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>$APP_NAME</string>
<key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>AppIcon</string>
</dict></plist>
PLIST
    codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || die "Ad-hoc signing failed."
}

self_test() {
    printf 'Running self-test…\n'
    local out
    if ! out="$("$BUNDLE/Contents/MacOS/$EXECUTABLE" --self-test 2>&1)"; then
        printf '%s\n' "$out" >&2
        die "Self-test failed (each FAIL line above points to a specific check). If it reports missing assets, download the assets again in full."
    fi
    printf '%s\n' "$out" | tail -1
}

package() {
    # Use ASCII filenames for distributables: GitHub Releases strips non-ASCII
    # characters from asset names, leaving truncated names such as "-1.1.dmg".
    local base="GoodThingPet-$VERSION"
    mkdir -p "$DIST"
    rm -f "$DIST/$base.zip" "$DIST/$base.dmg" "$DIST/$base.sha256"
    # Build the zip with ditto: both Finder and unzip then extract non-ASCII filenames correctly.
    ditto -c -k --keepParent "$BUNDLE" "$DIST/$base.zip"
    local stage
    stage="$(mktemp -d)"
    cp -R "$BUNDLE" "$stage/"
    ln -s /Applications "$stage/Applications"
    hdiutil create -quiet -volname "$DISPLAY_NAME" -srcfolder "$stage" -ov -format UDZO \
        "$DIST/$base.dmg" || die "Failed to create the dmg."
    rm -rf "$stage"
    ( cd "$DIST" && shasum -a 256 "$base.zip" "$base.dmg" > "$base.sha256" )
    printf 'Distributables:\n'
    ls -lh "$DIST" | sed 1d | sed 's/^/  /'
}

check_environment
compile
if [ "$SELF_TEST" = "1" ]; then self_test; fi
if [ "$PACKAGE" = "1" ]; then package; fi
printf 'Done: %s\n' "$BUNDLE"
printf 'Install: ./install.sh (or drag the app into Applications)\n'
