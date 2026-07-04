# Contributing

## Gates

Tests gate code twice — once leaving the machine, once entering `main`:

- **pre-push hook** — install once with `scripts/install-hooks.sh`; runs
  `swift build` + `swift run selby-tests` before every push.
- **GitHub CI** (`.github/workflows/ci.yml`) — SwiftLint (strict, rules in
  `.swiftlint.yml`), build, unit tests, and app bundle assembly on every
  push and PR. Run the same workflow locally with `scripts/ci-local.sh`
  (requires [`act`](https://nektosact.com); jobs run on this machine, no
  Docker needed).

Local commits are not gated; commit freely.

## Testing

- Pure logic lives in `Sources/SelbyCore/` and is covered by
  `swift run selby-tests` (a plain executable — the Command Line Tools ship
  no test framework).
- GUI behavior is covered by the executable harness in `SMOKE-TEST.md`; run
  it when touching the panel, picker, or settings.

## Git

- Linear history: rebase onto `main`, no merge commits.
- Commit messages are short, complete sentences: capital first letter,
  trailing period, `` `backticks` `` around identifiers.
- No `Co-Authored-By` trailers.
