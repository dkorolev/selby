# Day-to-day entry points. Every target works with the Command Line Tools
# alone; no Xcode.
.PHONY: all build test ui-test lint app install uninstall icon hooks clean

all: build test

build:
	swift build

test:
	swift run selby2-tests

ui-test:
	swift run selby2-ui-tests

lint:
	@command -v swiftlint >/dev/null || { echo "brew install swiftlint" >&2; exit 1; }
	@if [ "$$(xcode-select -p)" = "/Library/Developer/CommandLineTools" ]; then \
	  DYLD_FRAMEWORK_PATH="$$(xcode-select -p)/usr/lib" swiftlint lint --strict --quiet; \
	else swiftlint lint --strict --quiet; fi

# build/Selby2.app, stamped and signed.
app:
	scripts/build.sh

# Replace ~/Applications/Selby2.app and relaunch it.
install:
	scripts/build.sh --install

uninstall:
	pkill -x Selby2 || true
	rm -rf ~/Applications/Selby2.app

icon:
	swift scripts/make-icon.swift

# Pre-push gate: build and both test runners.
hooks:
	printf '#!/bin/sh\nset -e\nmake build test ui-test\n' > .git/hooks/pre-push
	chmod +x .git/hooks/pre-push

clean:
	rm -rf .build build
