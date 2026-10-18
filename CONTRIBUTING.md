# Contributing

## Gates

- `make lint test ui-test` is what CI runs on every push and pull request,
  plus an app-bundle build. `make hooks` installs it as a pre-push hook.
- Tags `v*` on `main` publish a release with the zipped app.

## Where things go

- A rule about what the picker does belongs in `Sources/Selby2Core/` as a
  value type with no AppKit, and gets a check in `Sources/Selby2Tests/`.
- Anything that touches a window, an event, or `NSWorkspace` goes in
  `Sources/Selby2Kit/` (if the panel tests need it) or `Sources/Selby2/`.
- Behavior that only a human can verify goes in `SMOKE-TEST.md`.
- No timers for correctness. If a race needs a window of time, the window
  lives in Core with an injected clock and a test.

## Toolchain

The Command Line Tools alone build and test everything. They ship neither
XCTest nor a working Swift Testing, which is why the test runners are plain
executables.

## Git

- Linear history, rebased onto `main`.
- Commit messages: a short sentence with a capital first letter, a trailing
  period, and backticks around identifiers.
