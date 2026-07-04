// Dependency-free test runner for SelbyCore (`swift run selby-tests`).
// The Command Line Tools toolchain ships neither XCTest nor Swift Testing,
// so tests are a plain executable. Exit codes: 0 all passed, 1 any failure.
import AppKit
import SelbyCore

var passes = 0
var failures = 0

func check(_ condition: Bool, _ name: String, line: UInt = #line) {
    if condition {
        passes += 1
        print("ok    \(name)")
    } else {
        failures += 1
        print("FAIL  \(name) (main.swift:\(line))")
    }
}

// MARK: - PickerLogic (pure)

check(PickerLogic.action(for: .accept, selection: 2, count: 4) == .choose(index: 2),
      "accept chooses current selection")
check(PickerLogic.action(for: .cancel, selection: 0, count: 4) == .dismiss,
      "cancel dismisses")
check(PickerLogic.action(for: .down, selection: 0, count: 3) == .moveSelection(to: 1),
      "down moves selection down")
check(PickerLogic.action(for: .down, selection: 2, count: 3) == .moveSelection(to: 0),
      "down wraps to top")
check(PickerLogic.action(for: .up, selection: 2, count: 3) == .moveSelection(to: 1),
      "up moves selection up")
check(PickerLogic.action(for: .up, selection: 0, count: 3) == .moveSelection(to: 2),
      "up wraps to bottom")
check(PickerLogic.action(for: .digit(1), selection: 2, count: 3) == .choose(index: 0),
      "digit 1 chooses first row")
check(PickerLogic.action(for: .digit(3), selection: 0, count: 3) == .choose(index: 2),
      "digit 3 chooses third row")
check(PickerLogic.action(for: .digit(4), selection: 0, count: 3) == nil,
      "digit beyond last row is ignored")
check(PickerLogic.action(for: .digit(9), selection: 0, count: 3) == nil,
      "digit 9 with 3 rows is ignored")
check(PickerLogic.action(for: .accept, selection: 0, count: 0) == .dismiss,
      "empty picker dismisses on accept")
check(PickerLogic.action(for: .down, selection: 0, count: 0) == .dismiss,
      "empty picker dismisses on navigation")

// MARK: - Layout-independent digit key codes (pure)

check(PickerKey.digit(forKeyCode: 18) == 1, "kVK_ANSI_1 maps to digit 1")
check(PickerKey.digit(forKeyCode: 25) == 9, "kVK_ANSI_9 maps to digit 9")
check(PickerKey.digit(forKeyCode: 83) == 1, "keypad 1 maps to digit 1")
check(PickerKey.digit(forKeyCode: 92) == 9, "keypad 9 maps to digit 9")
check(PickerKey.digit(forKeyCode: 0) == nil, "letter key maps to no digit")
check(PickerKey.digit(forKeyCode: 29) == nil, "kVK_ANSI_0 maps to no digit (rows are 1-based)")

// MARK: - PrivateLaunch (pure)

do {
    // Force-unwraps are safe: the literals are well-formed URLs.
    let urls = [URL(string: "https://a.com")!, URL(string: "https://b.com")!]
    check(PrivateLaunch.flagBeforeURLs("--incognito").arguments(for: urls)
          == ["--incognito", "https://a.com", "https://b.com"],
          "Chromium-style flag goes once, ahead of all URLs")
    check(PrivateLaunch.flagPerURL("-private-window").arguments(for: urls)
          == ["-private-window", "https://a.com", "-private-window", "https://b.com"],
          "Firefox-style flag repeats before each URL")
    check(PrivateLaunch.safariScripting.arguments(for: urls)
          == ["https://a.com", "https://b.com"],
          "Safari scripting passes bare URLs as the script's argv")
}

// MARK: - Browser identity (pure)

do {
    let appURL = URL(fileURLWithPath: "/Applications/Firefox.app")
    let normal = Browser(bundleID: "org.mozilla.firefox", name: "Firefox", url: appURL)
    let priv = Browser(bundleID: "org.mozilla.firefox", name: "Firefox (Private)", url: appURL,
                       privateLaunch: .flagPerURL("-private-window"))
    check(normal.id == "org.mozilla.firefox", "normal entry's id is the bundle ID")
    check(priv.id == "org.mozilla.firefox" + Browser.privateIDSuffix,
          "private variant's id is bundle ID + suffix")
    check(normal.id != priv.id, "variants persist independently")
}

// MARK: - Private-variant synthesis (pure)

do {
    let discovered = [
        Browser(bundleID: "org.mozilla.firefox", name: "Firefox",
                url: URL(fileURLWithPath: "/Applications/Firefox.app")),
        Browser(bundleID: "com.apple.Safari", name: "Safari",
                url: URL(fileURLWithPath: "/Applications/Safari.app")),
        Browser(bundleID: "com.example.obscure", name: "Obscure",
                url: URL(fileURLWithPath: "/Applications/Obscure.app")),
    ]
    let expanded = BrowserDiscovery.addingPrivateVariants(to: discovered)
    check(expanded.map(\.name)
          == ["Firefox", "Firefox (Private)", "Safari", "Safari (Private)", "Obscure"],
          "known browsers gain an adjacent private variant; unknown ones don't")
    check(expanded[1].privateLaunch == .flagPerURL("-private-window"),
          "Firefox variant carries the -private-window launch")
    check(expanded[3].privateLaunch == .safariScripting,
          "Safari variant carries the scripted launch")
    check(BrowserDiscovery.addingPrivateVariants(to: expanded) == expanded,
          "synthesis is idempotent — variants don't beget variants")
}

// MARK: - BrowserOrdering (pure)

func browser(_ id: String) -> Browser {
    Browser(bundleID: id, name: id, url: URL(fileURLWithPath: "/Applications/\(id).app"))
}

do {
    let discovered = [browser("arc"), browser("chrome"), browser("firefox"), browser("safari")]
    let arranged = BrowserOrdering.apply(order: ["safari", "chrome"], to: discovered)
    check(arranged.map(\.id) == ["safari", "chrome", "arc", "firefox"],
          "ordered IDs come first; the rest keep alphabetical order")
}
do {
    let discovered = [browser("arc"), browser("chrome")]
    let arranged = BrowserOrdering.apply(order: [], to: discovered)
    check(arranged.map(\.id) == ["arc", "chrome"], "empty order is a no-op")
}
do {
    let discovered = [browser("arc"), browser("chrome")]
    let arranged = BrowserOrdering.apply(order: ["gone", "chrome", "arc"], to: discovered)
    check(arranged.map(\.id) == ["chrome", "arc"], "uninstalled IDs in the order are skipped")
}

// MARK: - PickerModel (@MainActor; the entry point runs on the main thread)

MainActor.assumeIsolated {
    @MainActor
    func makeModel(onFinish: @escaping (PickerOutcome) -> Void) -> PickerModel {
        let browsers = [
            Browser(bundleID: "com.example.a", name: "A", url: URL(fileURLWithPath: "/Applications/A.app")),
            Browser(bundleID: "com.example.b", name: "B", url: URL(fileURLWithPath: "/Applications/B.app")),
        ]
        // Force-unwrap is safe: the literal is a well-formed URL.
        let model = PickerModel(
            urls: [URL(string: "https://example.com")!],
            browsers: browsers,
            defaultIndex: 1
        )
        model.onFinish = onFinish
        return model
    }

    do {
        let model = makeModel { _ in }
        check(model.selection == 1, "selection starts at defaultIndex")
    }

    do {
        var outcomes: [PickerOutcome] = []
        let model = makeModel { outcomes.append($0) }
        model.choose(0)
        model.cancel(.outsideClick) // e.g. resignKey after the choice — must be a no-op
        model.choose(1)
        check(outcomes.count == 1, "onFinish fires exactly once")
        if case .chose(let browser) = outcomes.first {
            check(browser.id == "com.example.a", "the first choice wins")
        } else {
            check(false, "the first choice wins")
        }
    }

    do {
        var outcomes: [PickerOutcome] = []
        let model = makeModel { outcomes.append($0) }
        model.cancel(.dismissed)
        check(outcomes == [.cancelled(.dismissed)], "Esc cancel reports .dismissed")
    }

    do {
        var outcomes: [PickerOutcome] = []
        let model = makeModel { outcomes.append($0) }
        model.cancel(.outsideClick)
        check(outcomes == [.cancelled(.outsideClick)],
              "outside-click cancel carries its reason (drives URL reclaim)")
    }

    do {
        var outcomes: [PickerOutcome] = []
        let model = makeModel { outcomes.append($0) }
        model.choose(5)
        check(outcomes.isEmpty, "out-of-range choose is ignored")
    }

    do {
        let model = makeModel { _ in }
        // Force-unwrap is safe: the literal is a well-formed URL.
        model.add([URL(string: "https://example.org/second")!])
        check(model.urls.count == 2, "add(_:) coalesces burst URLs into the invocation")
    }

    do {
        let model = makeModel { _ in }
        model.cancel(.dismissed)
        model.add([URL(string: "https://example.org/late")!])
        check(model.urls.count == 1, "add(_:) after finish is ignored")
    }

    do {
        var outcomes: [PickerOutcome] = []
        let model = makeModel { outcomes.append($0) }
        model.requestSettings()
        model.choose(0) // late events after the gear press must be no-ops
        check(outcomes == [.openSettings], "gear press reports .openSettings exactly once")
    }
}

print("\n\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
