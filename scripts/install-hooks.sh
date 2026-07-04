#!/usr/bin/env bash
# Installs the pre-push gate: build + unit tests must pass before code leaves
# the machine. Committing locally stays free and fast.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p .git/hooks
cat > .git/hooks/pre-push <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
echo "pre-push: swift build && selby-tests" >&2
swift build
swift run selby-tests
HOOK
chmod +x .git/hooks/pre-push
echo "Installed .git/hooks/pre-push" >&2
