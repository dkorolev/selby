#!/usr/bin/env bash
# Runs the GitHub Actions CI workflow locally via `act`.
# macOS jobs cannot run in act's Linux containers, so they are mapped onto
# this machine itself (-P macos-15=-self-hosted); Docker is not needed.
# Requires: act (brew install act), the Xcode Command Line Tools, Homebrew.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v act >/dev/null || {
  echo "error: act is not installed — brew install act" >&2
  exit 1
}
exec act push -P macos-15=-self-hosted "$@"
