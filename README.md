# Selby

Selby is a browser picker for macOS. It registers as the default browser;
when you click a link in any app, a small menu appears at the pointer and
you choose which real browser opens it. No Dock icon, no daemon, no config
files: a menu-bar agent that macOS launches on demand.

This is a from-scratch rewrite of the earlier picker, keeping its behavior
and replacing its timing heuristics with tested state.

## Usage

Click a link anywhere. The picker appears at the cursor:

- **Return** opens the first browser in your list; the picker pre-selects
  it, so click, Enter is the whole flow. Drag your favorite to the top in
  Settings.
- **↑ / ↓** move the selection (wrapping); **1–9** open that row;
  **Esc** or a click anywhere else dismisses.
- Hover and click work too.

**Settings** (the picker's gear, the menu-bar globe, or `open -a Selby`)
toggles which browsers appear and drags them into order. Browsers are
discovered automatically, so a newly installed one shows up on its own.

**Private windows**: Firefox, Chrome, Brave, Edge, Vivaldi, Opera, their
beta and dev channels, and Safari each get a "(Private)", "(Incognito)" or
"(InPrivate)" entry. These start hidden; switch them on in Settings. They
open a private window even when a normal window of the same browser is
frontmost. Safari has no private-window command line, so Selby scripts it
(see the permissions note below).

**Yab** appears twice. **Yab new window** is what Yab does with a link
from another app: a window over the app you clicked in. **Yab default window**
opens a tab in the window Yab already has. The first time, macOS asks to let
Selby control Yab.

## Install

Requires macOS 14+ and the Xcode Command Line Tools (no Xcode).

```sh
make install
```

That builds, signs, copies the app to `~/Applications/Selby.app`, makes it
the one copy LaunchServices knows, and launches it. Then make it the default
browser: click "Make Selby the default browser…" in its Settings, or choose
it under System Settings › Desktop & Dock › Default web browser.

Run `make install` again to upgrade. `make uninstall` removes it; set
another default browser first.

An earlier install's browser order and toggles are imported on first launch.

### Downloaded builds

Each tagged release ships `Selby-vX.Y.Z.zip`. The app is ad-hoc signed, so
after unzipping, clear the quarantine flag before the first launch:

```sh
xattr -dr com.apple.quarantine ~/Applications/Selby.app
```

### Keeping permissions across upgrades

"Safari (Private)" needs Accessibility and Automation grants, and macOS ties
them to the app's signature. An ad-hoc signature changes with every build,
so each upgrade would ask again. To avoid that, create a local signing
identity once:

```sh
scripts/make-signing-identity.sh
```

macOS asks for your login password to trust the certificate. From then on
`make install` signs with it and the grants survive upgrades.

## How it works

- `Resources/Info.plist` claims `http` and `https`, which is what makes
  macOS offer Selby as a default browser.
- macOS hands clicked links to `application(_:open:)`. URLs that arrive
  before launch completes are held and presented once it has, because a
  panel created earlier cannot take keyboard focus.
- The picker is a non-activating floating panel: it takes keyboard focus
  while the app you clicked in stays active. Losing focus never dismisses
  it; only Escape, a click outside, a choice, or the gear does.
- A second link clicked while the picker is up joins it, and the URLs of a
  picker that the click itself cancelled are reclaimed, so both open.
- The chosen browser gets the URLs through LaunchServices. Private entries
  pass the browser its own flag: through LaunchServices when it is not
  running, through a short-lived forwarder when it is. Safari's entry runs
  an AppleScript that clicks File › New Private Window via accessibility.
  Yab default window runs an AppleScript that makes a tab in that space.
- Browsers are discovered with `NSWorkspace.urlsForApplications(toOpen:)`;
  there is no hardcoded browser list.

| Path | What |
|---|---|
| `Sources/Selby2Core/` | Pure rules: keys, session, settings, placement, reclaim. Foundation only. |
| `Sources/Selby2Kit/` | AppKit and SwiftUI: panel, views, settings store, discovery. |
| `Sources/Selby2/` | The agent: URL delivery, picker lifecycle, launching, Settings window. |
| `Sources/Selby2Tests/` | `swift run selby2-tests`, unit tests for the core. |
| `Sources/Selby2UITests/` | `swift run selby2-ui-tests`, checks against the real panel. |
| `scripts/build.sh` | Assembles, stamps, signs, and optionally installs the app. |

## License

[MIT](LICENSE) © Dmitry "Dima" Korolev
