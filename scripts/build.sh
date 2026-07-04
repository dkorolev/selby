#!/usr/bin/env bash
# Builds Selby.app from the SPM executable and registers it with LaunchServices.
# Usage: scripts/build.sh [--install]
#   --install  Also copy the app to ~/Applications and register that copy.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=release
APP_DIR="build/Selby.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

echo "Building Selby ($CONFIG)…" >&2
swift build -c "$CONFIG"

# Quit any running instance and wait for it to exit: macOS routes URL opens to
# a live process, so a stale instance would keep serving old code after every
# rebuild (and rm -rf would yank the bundle out from under it).
pkill -x Selby 2>/dev/null || true
for _ in $(seq 20); do pgrep -x Selby >/dev/null || break; sleep 0.1; done

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
# Ask Spotlight not to index the build dir: indexing auto-registers the app
# bundle with LaunchServices, re-creating the two-copies problem after every
# rebuild. (Belt; the explicit unregister below is the suspenders.)
touch build/.metadata_never_index
cp ".build/$CONFIG/Selby" "$APP_DIR/Contents/MacOS/Selby"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
# Regenerate with scripts/make-icon.swift; cp fails loudly if it is missing.
cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

# Stamp the build so the picker footer says which code is running;
# "-dirty" flags uncommitted changes.
GIT_SHA="$(git rev-parse --short=7 HEAD 2>/dev/null || echo unknown)"
git diff-index --quiet HEAD -- 2>/dev/null || GIT_SHA="${GIT_SHA}-dirty"
plutil -replace SelbyGitSHA -string "$GIT_SHA" "$APP_DIR/Contents/Info.plist"

# Ad-hoc signature: enough for local use; required for LaunchServices to take
# the bundle seriously on modern macOS.
codesign --force --sign - "$APP_DIR"
echo "Built $APP_DIR" >&2

# LaunchServices must know exactly ONE Selby: the default-browser binding is
# by bundle ID, and two registered copies make cold launches resolve an
# arbitrary one. Register the installed copy when it exists (or when
# installing now), the repo-local copy only otherwise. `open` on an explicit
# path works without registration, so the smoke-test flow is unaffected.
INSTALLED="$HOME/Applications/Selby.app"
if [[ "${1:-}" == "--install" ]]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$INSTALLED"
  ditto "$APP_DIR" "$INSTALLED"
  # Sweep every OTHER Selby.app registration (old clones, moved checkouts,
  # this repo's build dir): they all share the bundle ID, so any survivor
  # can win the cold-launch resolution and serve stale code. The dump is
  # slow (~seconds) but --install is rare. Paths may contain spaces; only
  # the trailing " (0x…)" node ID is stripped.
  "$LSREGISTER" -dump | sed -n 's/^path: *//p' | sed 's/ (0x[0-9a-f]*)$//' \
    | grep '/Selby\.app$' | sort -u | while IFS= read -r stale; do
    [[ "$stale" == "$INSTALLED" ]] && continue
    echo "Unregistering stale copy: $stale" >&2
    "$LSREGISTER" -f -u "$stale" || true
  done
  "$LSREGISTER" -f "$INSTALLED" || true
  # The freshly rebuilt build/Selby.app may get auto-registered by Spotlight
  # AFTER the sweep above ran — unregister it explicitly, last.
  "$LSREGISTER" -f -u "$PWD/$APP_DIR" >/dev/null 2>&1 || true
  echo "Installed to ~/Applications/Selby.app" >&2
  # Relaunch: the pre-build pkill quit the old instance; without this the
  # menu-bar icon silently disappears until the next link click.
  open "$INSTALLED"
elif [[ -d "$INSTALLED" ]]; then
  echo "Note: ~/Applications/Selby.app stays the registered copy; run scripts/build.sh --install to update it." >&2
else
  "$LSREGISTER" -f "$APP_DIR" || true
fi
