// Unit tests for Selby2Core: `swift run selby2-tests`. Exit 0 on success.
import Foundation
import Selby2Core
import Selby2TestSupport

func url(_ string: String) -> URL {
    guard let url = URL(string: string) else { fatalError("bad test URL \(string)") }
    return url
}

func browser(_ id: String, name: String? = nil) -> Browser {
    Browser(bundleID: id, name: name ?? id, url: URL(fileURLWithPath: "/Applications/\(id).app"))
}

// MARK: - PickerLogic

Harness.check(PickerLogic.action(for: .accept, selection: 2, count: 4), equals: .choose(index: 2),
              "accept chooses the selection")
Harness.check(PickerLogic.action(for: .cancel, selection: 0, count: 4), equals: .dismiss, "cancel dismisses")
Harness.check(PickerLogic.action(for: .down, selection: 0, count: 3), equals: .moveSelection(to: 1), "down moves down")
Harness.check(PickerLogic.action(for: .down, selection: 2, count: 3), equals: .moveSelection(to: 0),
              "down wraps to top")
Harness.check(PickerLogic.action(for: .up, selection: 2, count: 3), equals: .moveSelection(to: 1), "up moves up")
Harness.check(PickerLogic.action(for: .up, selection: 0, count: 3), equals: .moveSelection(to: 2), "up wraps to bottom")
Harness.check(PickerLogic.action(for: .digit(1), selection: 2, count: 3), equals: .choose(index: 0),
              "digit 1 chooses row 1")
Harness.check(PickerLogic.action(for: .digit(3), selection: 0, count: 3), equals: .choose(index: 2),
              "digit 3 chooses row 3")
Harness.check(PickerLogic.action(for: .digit(4), selection: 0, count: 3), equals: nil,
              "digit past the last row is ignored")
Harness.check(PickerLogic.action(for: .accept, selection: 0, count: 0), equals: .dismiss,
              "empty picker dismisses on accept")
Harness.check(PickerLogic.action(for: .down, selection: 0, count: 0), equals: .dismiss,
              "empty picker dismisses on navigation")

// MARK: - PickerKey decoding

Harness.check(PickerKey(keyCode: 36, characters: "\r"), equals: .accept, "Return is accept")
Harness.check(PickerKey(keyCode: 76, characters: "\u{3}"), equals: .accept, "keypad Enter is accept")
Harness.check(PickerKey(keyCode: 53, characters: "\u{1b}"), equals: .cancel, "Escape is cancel")
Harness.check(PickerKey(keyCode: 125, characters: nil), equals: .down, "arrow down")
Harness.check(PickerKey(keyCode: 126, characters: nil), equals: .up, "arrow up")
Harness.check(PickerKey(keyCode: 18, characters: "&"), equals: .digit(1),
              "physical digit key wins over typed punctuation (AZERTY)")
Harness.check(PickerKey(keyCode: 25, characters: "9"), equals: .digit(9), "kVK_ANSI_9 is digit 9")
Harness.check(PickerKey(keyCode: 92, characters: "9"), equals: .digit(9), "keypad 9 is digit 9")
Harness.check(PickerKey(keyCode: 29, characters: "0"), equals: nil, "digit 0 is ignored (rows are 1-based)")
Harness.check(PickerKey(keyCode: 999, characters: "5"), equals: .digit(5),
              "typed digit on an unknown key code still counts")
Harness.check(PickerKey(keyCode: 0, characters: "a"), equals: nil, "letters are ignored")
Harness.check(PickerKey.digit(forKeyCode: 83), equals: 1, "keypad 1 maps to digit 1")

// MARK: - PrivateLaunch

do {
    let urls = [url("https://a.com"), url("https://b.com")]
    Harness.check(PrivateLaunch.flagBeforeURLs("--incognito").arguments(for: urls),
            equals: ["--incognito", "https://a.com", "https://b.com"], "Chromium flag goes once, first")
    Harness.check(PrivateLaunch.flagPerURL("-private-window").arguments(for: urls),
            equals: ["-private-window", "https://a.com", "-private-window", "https://b.com"],
            "Firefox flag repeats per URL")
    Harness.check(PrivateLaunch.safariScripting.arguments(for: urls),
            equals: ["https://a.com", "https://b.com"], "Safari scripting passes bare URLs")
}

// MARK: - Browser identity and private variants

do {
    let firefox = browser("org.mozilla.firefox", name: "Firefox")
    let priv = firefox.privateVariant(label: "Private", launch: .flagPerURL("-private-window"))
    Harness.check(firefox.id, equals: "org.mozilla.firefox", "normal id is the bundle ID")
    Harness.check(priv.id, equals: "org.mozilla.firefox#private", "private id is bundle ID + suffix")
    Harness.check(priv.name, equals: "Firefox (Private)", "private variant is named after its label")
    Harness.check(priv.isPrivate && !firefox.isPrivate, "isPrivate distinguishes variants")

    let discovered = [
        firefox, browser("com.apple.Safari", name: "Safari"), browser("com.example.obscure", name: "Obscure"),
    ]
    let expanded = PrivateVariants.inserting(into: discovered)
    Harness.check(expanded.map(\.name),
            equals: ["Firefox", "Firefox (Private)", "Safari", "Safari (Private)", "Obscure"],
            "known browsers gain an adjacent private variant; unknown ones do not")
    Harness.check(expanded[1].privateLaunch, equals: .flagPerURL("-private-window"), "Firefox variant carries its flag")
    Harness.check(expanded[3].privateLaunch, equals: .safariScripting, "Safari variant is scripted")
    Harness.check(PrivateVariants.inserting(into: expanded), equals: expanded, "insertion is idempotent")
}

// MARK: - Yab rows

do {
    let yab = browser(YabRows.bundleID, name: "Yab")
    let chrome = browser("com.google.Chrome", name: "Google Chrome")
    let rows = YabRows.inserting(into: [yab, chrome])
    Harness.check(rows.map(\.name), equals: ["Yab (Small Window)", "Yab (Personal)", "Google Chrome"],
            "Yab becomes a Small Window row and a Personal row; other browsers are unchanged")
    Harness.check(rows[0].id, equals: YabRows.bundleID, "the Small Window row keeps Yab's bundle ID")
    Harness.check(rows[1].id, equals: YabRows.bundleID + Browser.personalIDSuffix,
            "the Personal row has its own id")
    Harness.check(rows[1].mainTab, equals: MainTab.yabPersonal, "the Personal row opens a tab in Personal")
    Harness.check(rows[0].mainTab, equals: nil as MainTab?, "the Small Window row uses the ordinary handoff")
    Harness.check(rows[1].bundleID, equals: YabRows.bundleID, "both rows launch the same app")
    Harness.check(YabRows.inserting(into: rows), equals: rows, "Yab row insertion is idempotent")

    var settings = Settings()
    Harness.check(settings.visible(rows).map(\.name),
            equals: ["Yab (Small Window)", "Yab (Personal)", "Google Chrome"],
            "both Yab rows are visible by default")
    settings.setVisible(false, rows[1])
    Harness.check(settings.visible(rows).map(\.id), equals: [YabRows.bundleID, "com.google.Chrome"],
            "hiding Personal leaves the Small Window row")
}

// MARK: - Settings

do {
    let arc = browser("arc"), chrome = browser("chrome"), firefox = browser("firefox"), safari = browser("safari")
    let chromePrivate = chrome.privateVariant(label: "Incognito", launch: .flagBeforeURLs("--incognito"))
    let all = [arc, chrome, chromePrivate, firefox, safari]

    var settings = Settings()
    Harness.check(settings.visible(all).map(\.id), equals: ["arc", "chrome", "firefox", "safari"],
            "defaults: normal browsers visible, private variants hidden")

    settings.setVisible(false, chrome)
    settings.setVisible(true, chromePrivate)
    Harness.check(settings.visible(all).map(\.id), equals: ["arc", "chrome#private", "firefox", "safari"],
            "toggles hide a normal browser and show a private one")
    settings.setVisible(true, chrome)
    settings.setVisible(false, chromePrivate)
    Harness.check(settings, equals: Settings(), "toggling back restores the empty settings")

    settings.order = ["safari", "gone", "chrome"]
    Harness.check(settings.arranged(all).map(\.id), equals: ["safari", "chrome", "arc", "chrome#private", "firefox"],
            "ordered IDs first, unknown IDs skipped, the rest keep incoming order")

    let moved = settings.move(settings.arranged(all), fromOffsets: IndexSet(integer: 4), toOffset: 0)
    Harness.check(moved.map(\.id), equals: ["firefox", "safari", "chrome", "arc", "chrome#private"],
                  "move applies the drag")
    Harness.check(settings.order, equals: moved.map(\.id), "move records the full resulting order")

    settings.hidden = ["arc"]
    settings.enabledPrivate = ["chrome#private"]
    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(Settings.self, from: data)
    Harness.check(decoded, equals: settings, "settings round-trip through JSON")
    let json = String(data: data, encoding: .utf8) ?? ""
    Harness.check(json.contains("\"hidden\":[\"arc\"]"), "sets are encoded as arrays")
    Harness.check(try JSONDecoder().decode(Settings.self, from: Data("{}".utf8)), equals: Settings(),
            "missing keys decode as defaults")
}

// MARK: - PickerSession

do {
    let browsers = [browser("a"), browser("b")]
    var session = PickerSession(urls: [url("https://x.com")], browsers: browsers, defaultIndex: 1)
    Harness.check(session.selection, equals: 1, "selection starts at defaultIndex")
    Harness.check(session.handle(.up), "up is consumed")
    Harness.check(session.selection, equals: 0, "up moved the selection")
    Harness.check(!session.handle(.digit(7)), "a digit past the last row is not consumed")
    session.add([url("https://y.com")])
    Harness.check(session.urls.count, equals: 2, "add coalesces a burst")
    session.choose(5)
    Harness.check(session.outcome, equals: nil, "out-of-range choose is ignored")
    session.choose(0)
    Harness.check(session.outcome, equals: .chose(browsers[0]), "choose finishes with the browser")
    session.cancel(.outsideClick)
    session.requestSettings()
    session.add([url("https://late.com")])
    Harness.check(session.outcome, equals: .chose(browsers[0]), "the first outcome wins")
    Harness.check(session.urls.count, equals: 2, "add after finish is ignored")
    Harness.check(!session.handle(.accept), "keys after finish are not consumed")

    var escaped = PickerSession(urls: [], browsers: browsers)
    escaped.handle(.cancel)
    Harness.check(escaped.outcome, equals: .cancelled(.dismissed), "Escape reports .dismissed")
    var clicked = PickerSession(urls: [], browsers: browsers)
    clicked.cancel(.outsideClick)
    Harness.check(clicked.outcome, equals: .cancelled(.outsideClick), "outside click carries its reason")
    var gear = PickerSession(urls: [], browsers: browsers)
    gear.requestSettings()
    Harness.check(gear.outcome, equals: .openSettings, "gear reports .openSettings")
    var typed = PickerSession(urls: [], browsers: browsers)
    typed.handle(.digit(2))
    Harness.check(typed.outcome, equals: .chose(browsers[1]), "digit chooses through handle")
}

// MARK: - PickerPlacement

do {
    let main = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let right = CGRect(x: 1000, y: 100, width: 1000, height: 800)
    Harness.check(PickerPlacement.frame(containing: CGPoint(x: 1500, y: 900), among: [main, right]), equals: right,
            "a cursor pinned at a secondary screen's top edge resolves to that screen")
    Harness.check(PickerPlacement.frame(containing: CGPoint(x: 1200, y: 50), among: [main, right]), equals: right,
            "a point outside every frame resolves to the nearest one")
    Harness.check(PickerPlacement.frame(containing: .zero, among: []), equals: nil, "no screens, no frame")

    let size = CGSize(width: 260, height: 200)
    let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
    Harness.check(PickerPlacement.origin(panelSize: size, mouse: CGPoint(x: 500, y: 500), visible: visible),
            equals: CGPoint(x: 488, y: 312), "panel hangs from the cursor like a context menu")
    Harness.check(PickerPlacement.origin(panelSize: size, mouse: CGPoint(x: 500, y: 20), visible: visible),
            equals: CGPoint(x: 488, y: 32), "near the bottom edge the panel flips above the cursor")
    Harness.check(PickerPlacement.origin(panelSize: size, mouse: CGPoint(x: 990, y: 790), visible: visible),
            equals: CGPoint(x: 732, y: 592), "the panel is clamped inside the visible frame")
    let tall = CGSize(width: 260, height: 790)
    Harness.check(PickerPlacement.origin(panelSize: tall, mouse: CGPoint(x: 500, y: 20), visible: visible),
            equals: CGPoint(x: 488, y: 2), "a panel taller than the screen keeps its top edge visible")
    Harness.check(PickerPlacement.maxListHeight(visibleHeight: 100), equals: 150, "list height has a floor")
    Harness.check(PickerPlacement.maxListHeight(visibleHeight: 800), equals: 720, "list height leaves room for chrome")
}

// MARK: - HoverGate

do {
    var gate = HoverGate(origin: CGPoint(x: 100, y: 100))
    Harness.check(!gate.allowsHover(at: CGPoint(x: 100, y: 100)), "a stationary pointer does not hover")
    Harness.check(!gate.allowsHover(at: CGPoint(x: 103, y: 100)), "a jitter within the threshold does not hover")
    Harness.check(gate.allowsHover(at: CGPoint(x: 110, y: 100)), "moving past the threshold arms hover")
    Harness.check(gate.allowsHover(at: CGPoint(x: 100, y: 100)), "once armed, hover stays armed")
}

// MARK: - ReclaimableLinks

do {
    let t0 = Date(timeIntervalSince1970: 1000)
    var links = ReclaimableLinks(window: 0.5)
    Harness.check(links.reclaim(at: t0), equals: [], "nothing parked, nothing reclaimed")
    links.park([url("https://a.com")], at: t0)
    Harness.check(links.reclaim(at: t0.addingTimeInterval(0.2)), equals: [url("https://a.com")],
                  "reclaimed within the window")
    Harness.check(links.reclaim(at: t0.addingTimeInterval(0.3)), equals: [], "reclaim clears the buffer")
    links.park([url("https://b.com")], at: t0)
    Harness.check(links.reclaim(at: t0.addingTimeInterval(0.5)), equals: [], "the window is exclusive at its end")
    links.park([url("https://c.com")], at: t0)
    Harness.check(links.reclaim(at: t0.addingTimeInterval(-1)), equals: [],
                  "a clock that went backwards reclaims nothing")
}

Harness.finish()
