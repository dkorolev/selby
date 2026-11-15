import AppKit
import Selby2Core

/// Finds every app that claims it can open web URLs.
public enum BrowserDiscovery {
    /// Installed HTTP(S) handlers, deduplicated by bundle ID, excluding the
    /// app itself, sorted by name, each followed by its private variant when
    /// one exists. Yab is then split into Small Window and Personal. Costs a
    /// few milliseconds; safe to call per link click.
    public static func installedBrowsers(excluding ownBundleID: String? = Bundle.main.bundleIdentifier) -> [Browser] {
        guard let probe = URL(string: "https://example.com") else { return [] }
        var seen = Set<String>()
        var found: [Browser] = []
        for appURL in NSWorkspace.shared.urlsForApplications(toOpen: probe) {
            guard let bundle = Bundle(url: appURL),
                  let bundleID = bundle.bundleIdentifier,
                  bundleID != ownBundleID,
                  seen.insert(bundleID).inserted
            else { continue }
            found.append(Browser(bundleID: bundleID, name: displayName(of: bundle), url: appURL))
        }
        let sorted = found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return YabRows.inserting(into: PrivateVariants.inserting(into: sorted))
    }

    private static func displayName(of bundle: Bundle) -> String {
        (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleName"] as? String)
            ?? FileManager.default.displayName(atPath: bundle.bundlePath)
    }
}

/// Whether Selby2 is the macOS default browser, and how to become it.
public enum DefaultBrowser {
    public static var isSelby2: Bool {
        guard let probe = URL(string: "http://example.com"),
              let handler = NSWorkspace.shared.urlForApplication(toOpen: probe)
        else { return false }
        return Bundle(url: handler)?.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    /// macOS shows its own confirmation dialog. `completion` receives `nil`
    /// on success, the error otherwise, including the user declining.
    public static func makeSelby2(completion: @escaping @Sendable (Error?) -> Void) {
        NSWorkspace.shared.setDefaultApplication(
            at: Bundle.main.bundleURL, toOpenURLsWithScheme: "http", completion: completion
        )
    }
}
