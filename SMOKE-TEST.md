# SMOKE-TEST — Selby end-to-end harness

Executable checklist for the GUI behavior that unit tests cannot cover.
Mechanical steps run as shell commands; prose assertions are judged by the
human or agent running the harness. Every step must pass.

## 1. Build, sign, register

```sh
scripts/build.sh
```

- Expect: exits `0`; `build/Selby.app` exists.
- Expect: `codesign --verify build/Selby.app` exits `0`.
- Expect: `plutil -lint build/Selby.app/Contents/Info.plist` prints `OK`.

## 2. Unit tests

```sh
swift run selby-tests
```

- Expect: exits `0`, prints `0 failed`.

## 3. Launch

```sh
open build/Selby.app
```

- Expect: a globe icon appears in the menu bar; no Dock icon, no window.
- Expect: in Finder, `build/Selby.app` shows the Selby icon (blue squircle,
  white branching arrow) — not the generic app icon.

## 4. Picker appears at the mouse

```sh
open -a build/Selby.app https://example.com/smoke-test
```

- Expect: a floating panel appears at the current mouse position showing
  `https://example.com/smoke-test` (middle-truncated) above one row per
  enabled browser, each with its icon, name, and a digit hint; the first
  row shows `↩` and is highlighted.
- Expect: the panel's bottom edge reads `Selby, <short-git-sha>` (matching
  `git rev-parse --short=7 HEAD`, with `-dirty` if the tree was dirty) and
  has a gear button on the right; clicking the gear closes the picker and
  opens the Settings window on the current Space, in front.

## 5. Keyboard

Repeat step 4 before each sub-check:

- Press **Return** with no other keys: the FIRST browser in the list opens
  the URL and the panel closes.
- Press **↓** until the highlight wraps from the last row back to the first.
- Press a **digit** (e.g. `2`): that row's browser opens the URL.
- Press **Esc**: the panel closes; nothing opens; keyboard focus returns to
  the app you were in.

## 6. Mouse

Repeat step 4 before each sub-check:

- Hovering a row highlights it; clicking it opens that browser.
- Clicking anywhere outside the panel dismisses it; nothing opens.

## 7. Settings

Open menu bar globe → **Settings…**:

- Every installed browser is listed with its icon and a toggle. Enabled rows
  show their picker position number on the left (matching the picker's 1–9
  shortcuts) and the top enabled row shows `↩`; hidden rows are dimmed with
  no number.
- Toggling a browser off removes it from the next picker invocation, and the
  remaining rows renumber immediately.
- Dragging a row to a new position reorders the list; the next picker shows
  the same order, with `↩` on the new top row and the 1–9 shortcuts
  renumbered to match. The order survives quitting and relaunching Selby.
- With Selby not the system default: a "Make Selby the default browser…"
  button shows; clicking it produces the macOS confirmation dialog, and after
  accepting, the section shows "Selby is your default browser".

## 8. Degenerate cases

- With exactly **one** browser enabled: `open -a build/Selby.app
  https://example.com` opens it directly — no picker.
- **Link burst**: `open -a build/Selby.app https://example.com/a
  https://example.com/b` shows ONE picker whose header reads
  `https://example.com/a  (+1 more)`; choosing a browser opens both URLs.
- **Rapid successive clicks**: click a link in one app, and while the picker
  is up, immediately click a different link (in the same or another app).
  The new picker's header shows `(+1 more)` — the first URL was reclaimed,
  not dropped — and choosing a browser opens both.
- **Many browsers**: with more browsers enabled than fit the screen height,
  the list scrolls (never extends off-screen), and arrow-key navigation
  scrolls the selection into view.
- **Bottom of screen**: move the mouse near the bottom edge and trigger the
  picker: the panel appears *above* the cursor (never sliding a row under
  it), and with the mouse held still, the default row stays selected —
  Enter opens the default browser.
- **Top edge of a secondary display** (multi-monitor): with the cursor pinned
  at the very top of a non-primary screen, the picker appears on *that*
  screen, not the primary one.

## 9. The real flow

With Selby set as the system default browser, click a link in any app
(Mail, Slack, a PDF…):

- Expect: the picker appears at the mouse; choosing a browser opens the link
  there; the browser comes to the front.
