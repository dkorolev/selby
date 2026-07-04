# `selby`

Selby is the "select browser" tool.

I needed to choose browsers dynamically on MacOS. The app I found quickly is apparently not free after two weeks. And Fable is still here in my subscription.

So I vibe-coded one. Never coded for MacOS before. But this appears to be functional and useful, so I'm keeping it and releasing it.

https://github.com/user-attachments/assets/57042c87-fb87-4788-a67e-f6c192a65943

Selby registers as your default browser; when you click a link in any app, a
small menu appears at the mouse pointer and you pick which real browser opens
it. No Dock icon, no background daemon, no configuration files — a single
menu-bar agent that macOS launches on demand.

## Usage

Click a link anywhere. The picker appears at your cursor:

- **Return** opens the first browser in your list — the picker pre-selects
  it, so click → Enter is the whole flow. Drag your favorite to the top in
  Settings.
- **↑ / ↓** move the selection (wrapping); **1–9** open that row directly;
  **Esc** (or clicking anywhere else) dismisses.
- Hover and click work too.

**Settings** (the picker's gear button, the menu-bar globe, or `open -a
Selby`) lets you toggle which browsers appear and drag them into your
preferred order. Browsers are discovered automatically — a newly installed
one shows up on its own.

**Private windows**: supported browsers also get a "Firefox (Private)" /
"Google Chrome (Incognito)" / "Safari (Private)" entry. These start hidden —
flip them on in Settings — and open the link in a private window even when a
normal window of the same browser is frontmost. Firefox, Chrome, Brave, Edge,
Vivaldi, Opera, and their beta/dev channels take a private-window command
line; Safari has none, so Selby scripts it (see the permissions note under
Install).

## Install

Requires macOS 14+ and the Xcode Command Line Tools (no Xcode needed).

```sh
scripts/build.sh --install
```

That one command does everything the system needs:

1. Builds and ad-hoc-signs the app.
2. Quits any running Selby (a live process would keep serving old code).
3. Copies it to `~/Applications/Selby.app`.
4. **Unregisters every other copy of Selby** that LaunchServices knows about
   — old clones and build directories share the bundle ID, and macOS binds
   the default browser by bundle ID, so a stale registered copy can win the
   launch and "the old version keeps opening".
5. Registers the installed copy and relaunches it (the menu-bar globe).

Then make it the default browser: click "Make Selby the default browser…" in
Selby's Settings, or pick Selby under System Settings → Desktop & Dock →
Default web browser. Selby only catches link clicks while it is the system
default.

To upgrade, run the same command again — it replaces, re-registers, and
restarts in one shot. To uninstall, set a different default browser and
delete `~/Applications/Selby.app`.

### Permissions for "Safari (Private)"

Safari is the one browser without a private-window command line, so Selby
opens it by scripting the UI (clicking File → New Private Window through
accessibility, then handing the URL over via Apple Events). The first use
asks for:

- **Accessibility** (System Settings → Privacy & Security → Accessibility →
  enable Selby) — required to click the menu item.
- **Automation** prompts for "Safari" and "System Events" — click Allow.

No other browser needs any of this. Because Selby is ad-hoc signed, macOS
ties these grants to the exact binary — after reinstalling you may have to
re-grant Accessibility (toggle Selby off and on in that settings pane).

## How it works

- `Resources/Info.plist` claims the `http`/`https` URL schemes, which is what
  makes macOS offer Selby as a default-browser choice.
- macOS hands clicked links to Selby via `application(_:open:)`; Selby shows
  a non-activating floating panel (Spotlight-style, so it takes keyboard
  focus without stealing app activation) at the mouse location.
- The chosen browser gets the URL via
  `NSWorkspace.open(_:withApplicationAt:configuration:)`. Private-window
  entries instead exec the browser's binary with its private flag
  (`-private-window`, `--incognito`, …) — macOS has no API to target a
  window mode, but every major browser forwards its command line to the
  running instance. Safari alone has no such flag; its private entry runs an
  `osascript` that clicks File → New Private Window (matched by its ⌘⇧N
  shortcut metadata, so it survives localization) and then sets the new
  window's URL.
- Browsers are discovered with `NSWorkspace.urlsForApplications(toOpen:)` —
  no hardcoded browser list.
- Selby is a menu-bar-only agent (`LSUIElement`); it does not need to run at
  login, because macOS launches the default browser on demand.

## Development

```sh
swift run selby-tests   # unit tests for the pure picker logic (exit 0/1)
```

The GUI layer is covered by the executable harness in
[SMOKE-TEST.md](SMOKE-TEST.md). See [CONTRIBUTING.md](CONTRIBUTING.md) for
the testing gates and conventions.

| Path | What |
|---|---|
| `Sources/SelbyCore/` | Pure types + picker decision logic (library, tested) |
| `Sources/Selby/` | The menu-bar app: panel, views, settings, URL dispatch |
| `Sources/SelbyTests/` | Dependency-free test runner (`swift run selby-tests`) |
| `Resources/` | Bundle manifest (URL schemes, agent-app flags) and app icon |
| `scripts/build.sh` | Builds and signs `build/Selby.app`; `--install` copies to `~/Applications` |
| `scripts/make-icon.swift` | Regenerates `Resources/AppIcon.icns` |

## License

[MIT](LICENSE) © Dmitry "Dima" Korolev
