# `selby`

Selby is the "select browser" tool.

I needed to choose browsers dynamically on MacOS. The app I found quickly is apparently not free after two weeks. And Fable is still here in my subscription.

So I vibe-coded one. Never coded for MacOS before. But this appears to be functional and useful, so I'm keeping it and releasing it.

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

## Install

Requires macOS 14+ and the Xcode Command Line Tools (no Xcode needed).

```sh
scripts/build.sh --install   # builds, signs (ad-hoc), installs to ~/Applications
open ~/Applications/Selby.app
```

Then click "Make Selby the default browser…" in Selby's Settings, or pick
Selby under System Settings → Desktop & Dock → Default web browser.

## How it works

- `Resources/Info.plist` claims the `http`/`https` URL schemes, which is what
  makes macOS offer Selby as a default-browser choice.
- macOS hands clicked links to Selby via `application(_:open:)`; Selby shows
  a non-activating floating panel (Spotlight-style, so it takes keyboard
  focus without stealing app activation) at the mouse location.
- The chosen browser gets the URL via
  `NSWorkspace.open(_:withApplicationAt:configuration:)`.
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
