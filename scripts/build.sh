#!/usr/bin/env bash
# Builds build/Selby2.app from the SPM product, stamps and signs it, and
# optionally installs it.
#
# Usage: scripts/build.sh [--install] [--debug]
#   --install  Replace ~/Applications/Selby2.app, make it the one copy
#              LaunchServices knows, and relaunch it.
#   --debug    Build the debug configuration (default: release).
#
# Signing: with SELBY_SIGN_IDENTITY set, or a "Selby2 Local Signing"
# identity in the keychain (scripts/make-signing-identity.sh), the app is
# signed with it, so Accessibility and Automation grants survive rebuilds.
# Otherwise the signature is ad hoc and macOS forgets those grants on every
# install.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=release
INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    --debug) CONFIG=debug ;;
    *) echo "usage: scripts/build.sh [--install] [--debug]" >&2; exit 2 ;;
  esac
done

APP="build/Selby2.app"
INSTALLED="$HOME/Applications/Selby2.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

echo "Building Selby2 ($CONFIG)…" >&2
swift build -c "$CONFIG" --product Selby2

# Assemble the bundle. Spotlight must not index build/: indexing registers
# the bundle with LaunchServices and creates a second Selby2.
rm -rf "$APP"
mkdir -p build "$APP/Contents/MacOS" "$APP/Contents/Resources"
touch build/.metadata_never_index
cp ".build/$CONFIG/Selby2" "$APP/Contents/MacOS/Selby2"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Version from git: the latest v* tag (0.0.0 before the first), the commit
# count as the build number, and the short SHA the picker footer shows.
VERSION="$(git describe --tags --match 'v*' --abbrev=0 2>/dev/null | sed 's/^v//' || true)"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
SHA="$(git rev-parse --short=7 HEAD 2>/dev/null || echo unknown)"
git diff-index --quiet HEAD -- 2>/dev/null || SHA="${SHA}-dirty"
plutil -replace CFBundleShortVersionString -string "${VERSION:-0.0.0}" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP/Contents/Info.plist"
plutil -replace Selby2GitSHA -string "$SHA" "$APP/Contents/Info.plist"

IDENTITY="${SELBY_SIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" ]] && security find-identity -v -p codesigning 2>/dev/null | grep -q '"Selby2 Local Signing"'; then
  IDENTITY="Selby2 Local Signing"
fi
codesign --force --sign "${IDENTITY:--}" --identifier dev.selby.Selby2 "$APP"
echo "Built $APP, version ${VERSION:-0.0.0} ($BUILD_NUMBER), build $SHA, signed by ${IDENTITY:-ad-hoc signature}" >&2

[[ "$INSTALL" == 1 ]] || exit 0

# macOS routes URL opens to a live process, so the old instance must quit
# before the new copy can serve anything.
pkill -x Selby2 2>/dev/null || true
for _ in $(seq 50); do pgrep -x Selby2 >/dev/null || break; sleep 0.1; done

mkdir -p "$HOME/Applications"
rm -rf "$INSTALLED"
ditto "$APP" "$INSTALLED"

# The default browser is bound by bundle ID, and any registered Selby2.app
# (old clones, build directories) can win a cold launch and serve stale
# code. Leave exactly one registration: the installed copy.
"$LSREGISTER" -dump 2>/dev/null | sed -n 's/^path: *//p' | sed 's/ (0x[0-9a-f]*)$//' \
  | grep '/Selby2\.app$' | sort -u | while IFS= read -r other; do
  [[ "$other" == "$INSTALLED" ]] && continue
  echo "Unregistering stale copy: $other" >&2
  "$LSREGISTER" -f -u "$other" || true
done
"$LSREGISTER" -f "$INSTALLED"
"$LSREGISTER" -f -u "$PWD/$APP" >/dev/null 2>&1 || true

open "$INSTALLED"
echo "Installed and relaunched $INSTALLED" >&2
