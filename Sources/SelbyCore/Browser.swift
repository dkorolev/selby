import AppKit

/// How to ask a browser for a private window from the command line. macOS has
/// no API to route a URL into a specific window or mode of a running app, so
/// private variants bypass LaunchServices and invoke the browser binary with
/// its private-window flag; every major engine forwards that to the running
/// instance.
public enum PrivateLaunch: Hashable, Sendable {
    /// One flag ahead of all URLs (Chromium style: `--incognito url1 url2`).
    case flagBeforeURLs(String)
    /// The flag repeats before each URL (Firefox style: `-private-window url`
    /// binds one URL per flag; trailing bare URLs would open normal windows).
    case flagPerURL(String)
    /// Safari only: no private-window command line exists at all, so the app
    /// layer scripts the UI — clicking File → New Private Window through
    /// accessibility, then handing the URLs over by Apple Events. Needs the
    /// user to grant Selby Accessibility and Automation permissions.
    case safariScripting

    /// The launch argv for `urls`: the flag(s) plus URLs for command-line
    /// styles, the bare URLs (the script's argv) for `safariScripting`.
    public func arguments(for urls: [URL]) -> [String] {
        switch self {
        case .flagBeforeURLs(let flag):
            return [flag] + urls.map(\.absoluteString)
        case .flagPerURL(let flag):
            return urls.flatMap { [flag, $0.absoluteString] }
        case .safariScripting:
            return urls.map(\.absoluteString)
        }
    }
}

/// One picker entry: an installed browser as discovered via LaunchServices,
/// or a synthesized private-window variant of one.
public struct Browser: Identifiable, Hashable, Sendable {
    /// Appended to the bundle ID to form a private variant's `id`. `#` cannot
    /// appear in real bundle IDs, so variant IDs never collide with app IDs.
    public static let privateIDSuffix = "#private"

    /// Stable identity used for persistence (ordering and visibility), so
    /// settings survive the app moving on disk or being updated. The bundle
    /// ID itself, or bundle ID + `privateIDSuffix` for a private variant.
    public let id: String
    /// Bundle identifier of the underlying app (shared by both variants).
    public let bundleID: String
    /// Human-readable name shown in the picker and Settings.
    public let name: String
    /// Filesystem location of the .app bundle; where URLs get dispatched.
    public let url: URL
    /// Present on private variants: how to launch a private window.
    public let privateLaunch: PrivateLaunch?

    public init(bundleID: String, name: String, url: URL, privateLaunch: PrivateLaunch? = nil) {
        self.id = privateLaunch == nil ? bundleID : bundleID + Self.privateIDSuffix
        self.bundleID = bundleID
        self.name = name
        self.url = url
        self.privateLaunch = privateLaunch
    }

    /// The app's icon, resolved lazily (NSWorkspace caches internally).
    /// Computed rather than stored so `Browser` stays `Hashable` by value.
    public var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}

/// Finds every app on the system that claims it can open web URLs.
public enum BrowserDiscovery {
    /// Browsers that can open a private window on demand, keyed by bundle ID.
    /// `label` is each vendor's own name for the mode, so the picker says
    /// "Google Chrome (Incognito)", not a made-up term.
    private static let privateVariants: [String: (label: String, launch: PrivateLaunch)] = [
        "com.apple.Safari": ("Private", .safariScripting),
        "org.mozilla.firefox": ("Private", .flagPerURL("-private-window")),
        "org.mozilla.firefoxdeveloperedition": ("Private", .flagPerURL("-private-window")),
        "org.mozilla.nightly": ("Private", .flagPerURL("-private-window")),
        "com.google.Chrome": ("Incognito", .flagBeforeURLs("--incognito")),
        "com.google.Chrome.beta": ("Incognito", .flagBeforeURLs("--incognito")),
        "com.google.Chrome.dev": ("Incognito", .flagBeforeURLs("--incognito")),
        "com.google.Chrome.canary": ("Incognito", .flagBeforeURLs("--incognito")),
        "org.chromium.Chromium": ("Incognito", .flagBeforeURLs("--incognito")),
        "com.brave.Browser": ("Private", .flagBeforeURLs("--incognito")),
        "com.brave.Browser.beta": ("Private", .flagBeforeURLs("--incognito")),
        "com.brave.Browser.nightly": ("Private", .flagBeforeURLs("--incognito")),
        "com.microsoft.edgemac": ("InPrivate", .flagBeforeURLs("--inprivate")),
        "com.microsoft.edgemac.Beta": ("InPrivate", .flagBeforeURLs("--inprivate")),
        "com.microsoft.edgemac.Dev": ("InPrivate", .flagBeforeURLs("--inprivate")),
        "com.microsoft.edgemac.Canary": ("InPrivate", .flagBeforeURLs("--inprivate")),
        "com.vivaldi.Vivaldi": ("Private", .flagBeforeURLs("--incognito")),
        "com.operasoftware.Opera": ("Private", .flagBeforeURLs("--private")),
        "com.operasoftware.OperaGX": ("Private", .flagBeforeURLs("--private")),
    ]

    /// Returns installed HTTP(S) handlers, deduplicated by bundle ID,
    /// excluding Selby itself, sorted by name, each followed by its private
    /// variant when the browser supports one.
    public static func installedBrowsers() -> [Browser] {
        // Force-unwrap is safe: the literal is a well-formed URL.
        let probe = URL(string: "https://example.com")!
        var seen = Set<String>()
        var result: [Browser] = []
        for appURL in NSWorkspace.shared.urlsForApplications(toOpen: probe) {
            guard let bundle = Bundle(url: appURL),
                  let bundleID = bundle.bundleIdentifier,
                  bundleID != Bundle.main.bundleIdentifier,
                  seen.insert(bundleID).inserted
            else { continue }
            let name = (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
                ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                ?? FileManager.default.displayName(atPath: appURL.path)
            result.append(Browser(bundleID: bundleID, name: name, url: appURL))
        }
        let sorted = result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return addingPrivateVariants(to: sorted)
    }

    /// Inserts each supported browser's private variant directly after it —
    /// after sorting, so "Firefox (Private)" stays adjacent to "Firefox" no
    /// matter what other names sort between them alphabetically.
    public static func addingPrivateVariants(to browsers: [Browser]) -> [Browser] {
        let existingIDs = Set(browsers.map(\.id))
        return browsers.flatMap { browser -> [Browser] in
            guard browser.privateLaunch == nil,
                  let variant = privateVariants[browser.bundleID],
                  !existingIDs.contains(browser.id + Browser.privateIDSuffix)
            else { return [browser] }
            let privateBrowser = Browser(
                bundleID: browser.bundleID,
                name: "\(browser.name) (\(variant.label))",
                url: browser.url,
                privateLaunch: variant.launch
            )
            return [browser, privateBrowser]
        }
    }
}
