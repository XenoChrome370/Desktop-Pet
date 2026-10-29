#!/bin/bash
# One-step GoodThing Pet installer: build (if needed) → install to Applications → clear the quarantine flag → launch
#
#   ./install.sh                    build (if needed), install and launch
#   ./install.sh --from path.app    install an existing app bundle (e.g. one dragged out of a dmg)
#   ./install.sh --build            force a rebuild before installing
#   ./install.sh --uninstall        quit and delete the app in Applications (keeps position, volume, etc.)
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="GoodThingPet"
EXECUTABLE="GoodThingPet"
BUILD_APP="build/$APP_NAME.app"
TARGET="/Applications/$APP_NAME.app"
SOURCE=""
FORCE_BUILD=0

die() { printf '\nInstall aborted: %s\n' "$1" >&2; exit 1; }
quit_running() { pkill -x "$EXECUTABLE" >/dev/null 2>&1 || true; }
# The app was previously shipped as 好事桌宠.app. Remove that bundle so a
# reinstall does not leave two copies in Applications.
LEGACY_TARGET="/Applications/好事桌宠.app"
remove_legacy() {
    if [ -e "$LEGACY_TARGET" ]; then
        rm -rf "$LEGACY_TARGET" || true
        printf 'Removed legacy bundle: %s\n' "$LEGACY_TARGET"
    fi
}

case "${1:-}" in
    --uninstall)
        quit_running
        if [ ! -e "$TARGET" ]; then
            printf '%s is not in Applications; nothing to uninstall.\n' "$APP_NAME"
        else
            rm -rf "$TARGET" || die "Failed to delete $TARGET; you may need: sudo ./install.sh --uninstall"
            printf 'Uninstalled %s.\n' "$TARGET"
        fi
        remove_legacy
        printf 'Position, volume and size settings are kept in your user defaults.\n'
        exit 0
        ;;
    --from)
        SOURCE="${2:-}"
        if [ -z "$SOURCE" ] || [ ! -d "$SOURCE" ]; then
            die "Usage: ./install.sh --from /path/GoodThingPet.app"
        fi
        ;;
    --build) FORCE_BUILD=1 ;;
    "") ;;
    *) printf 'Unknown argument: %s (available: --from path / --build / --uninstall)\n' "$1" >&2; exit 2 ;;
esac

if [ -n "$SOURCE" ]; then
    BUNDLE="$SOURCE"
else
    BUNDLE="$BUILD_APP"
    if [ "$FORCE_BUILD" = "1" ] || [ ! -d "$BUNDLE" ]; then ./build.sh; fi
fi

quit_running
remove_legacy
sleep 0.5
# Reinstall: remove the old copy first so mixed signatures cannot break launch
if [ -e "$TARGET" ]; then rm -rf "$TARGET"; fi
cp -R "$BUNDLE" "$TARGET" || die "Failed to write $TARGET. If admin rights are required, use: sudo ./install.sh"
# Bundles downloaded from a browser, dmg or cloud storage carry com.apple.quarantine,
# which makes Gatekeeper reject the ad-hoc signature
before="$(xattr -p com.apple.quarantine "$TARGET" 2>/dev/null || true)"
xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true
if [ -n "$before" ]; then printf 'Cleared the download quarantine flag.\n'; fi
open "$TARGET"
printf 'Installed and launched: %s\n' "$TARGET"
printf 'The menu bar item on the far right opens settings; click the pet on the desktop to play.\n'
