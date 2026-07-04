import AppKit

/// One installed browser as discovered via LaunchServices.
public struct Browser: Identifiable, Hashable, Sendable {
    /// Bundle identifier — the stable identity used for persistence, so
    /// settings survive the app moving on disk or being updated.
    public let id: String
    /// Human-readable name shown in the picker and Settings.
    public let name: String
    /// Filesystem location of the .app bundle; where URLs get dispatched.
    public let url: URL

    public init(id: String, name: String, url: URL) {
        self.id = id
        self.name = name
        self.url = url
    }

    /// The app's icon, resolved lazily (NSWorkspace caches internally).
    /// Computed rather than stored so `Browser` stays `Hashable` by value.
    public var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}

/// Finds every app on the system that claims it can open web URLs.
public enum BrowserDiscovery {
    /// Returns installed HTTP(S) handlers, deduplicated by bundle ID,
    /// excluding Selby itself, sorted by name.
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
            result.append(Browser(id: bundleID, name: name, url: appURL))
        }
        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
