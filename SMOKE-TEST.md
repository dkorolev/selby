# Smoke test

What the test runners cannot cover. Run `make app` first; every step must
pass.

## 1. Bundle

- `codesign --verify build/Selby2.app` exits 0.
- `open build/Selby2.app` shows a globe in the menu bar, no Dock icon, and
  the Settings window (a plain launch is a request for Settings).

## 2. Picker

`open -a build/Selby2.app https://example.com/smoke`, with Selby2 not
running, then again while it is:

- The panel appears at the mouse, with the URL middle-truncated above one
  row per visible browser, each with icon, name, and digit; the first row
  is highlighted and shows ↩. The footer reads `Selby2 <version> (<sha>)`.
- The system log shows `Picker visible: true, key: true` for both the cold
  and the warm case:
  `log stream --predicate 'subsystem == "dev.selby.Selby2"' --style compact`
- Return opens the first browser. ↓ wraps from the last row to the first.
  A digit opens that row. Esc closes and focus returns to the previous app.
- Hovering highlights; clicking opens. Clicking anywhere else dismisses.
- The gear closes the picker and opens Settings in front.

## 3. Bursts

- `open -a build/Selby2.app https://example.com/a https://example.com/b`
  shows one picker reading `(+1 more)`; choosing opens both.
- With the picker up, click a different link in another app: the new
  picker reads `(+1 more)` and choosing opens both.
- Cmd-Tab away and back while the picker is up: it is still there and still
  works.

## 4. Edges

- With exactly one browser visible, a link opens it directly, no picker.
- With more browsers than fit the screen, the list scrolls and arrow keys
  keep the selection in view.
- With the pointer at the bottom of the screen, the picker opens above it
  and the first row stays selected until the mouse moves.
- On a secondary display, the picker opens on that display.

## 5. Settings

- Every browser is listed with its picker number; hidden rows are dimmed.
  Toggling renumbers at once; dragging reorders, and the next picker
  matches. The order survives quit and relaunch.
- "Make Selby2 the default browser…" produces the macOS dialog and the
  section then says Selby2 is the default.

## 6. Private windows

- Enable "Google Chrome (Incognito)" (or Brave). With a normal Chrome window
  frontmost, choose it: a new incognito window opens with the URL;
  `osascript -e 'tell application "Google Chrome" to get mode of front window'`
  prints `incognito`. With Chrome quit, choose it: Chrome launches straight
  into an incognito window.
- Enable "Safari (Private)". The first use prompts for Accessibility and
  Automation; after granting, a Private Browsing window opens with the URL.

## 7. Failure

- Hide every browser, click a link: a beep and the Settings window.
- Remove a test browser after it appears in the picker, then choose it: an
  error with "Choose Browser Again", which shows the picker even if only
  one browser remains.
