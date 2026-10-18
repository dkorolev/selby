import Foundation

/// How a browser is asked for a private window from its command line. macOS
/// has no API to route a URL into a particular window mode, so private
/// entries pass the browser its own flag; every supported engine forwards
/// that to an already-running instance.
public enum PrivateLaunch: Hashable, Sendable {
    /// One flag ahead of all URLs (Chromium style: `--incognito a b`).
    case flagBeforeURLs(String)
    /// The flag repeats before each URL (Firefox style: `-private-window a
    /// -private-window b`; a bare trailing URL would open a normal window).
    case flagPerURL(String)
    /// Safari has no private-window flag; the app layer scripts the UI.
    case safariScripting

    /// The launch arguments for `urls`. For `safariScripting` these are the
    /// bare URLs, which become the script's argv.
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

/// One picker row: an installed browser, or a private-window variant of one.
public struct Browser: Identifiable, Hashable, Sendable {
    /// Appended to the bundle ID to form a private variant's `id`. `#` cannot
    /// appear in a bundle ID, so variant IDs never collide with app IDs.
    public static let privateIDSuffix = "#private"

    /// Stable identity for persistence: the bundle ID, or bundle ID plus
    /// `privateIDSuffix`. Survives the app moving on disk or being updated.
    public let id: String
    public let bundleID: String
    /// Human-readable name shown in the picker and in Settings.
    public let name: String
    /// Location of the `.app` bundle.
    public let url: URL
    /// Present on private variants only.
    public let privateLaunch: PrivateLaunch?

    public var isPrivate: Bool { privateLaunch != nil }

    public init(bundleID: String, name: String, url: URL, privateLaunch: PrivateLaunch? = nil) {
        self.id = privateLaunch == nil ? bundleID : bundleID + Self.privateIDSuffix
        self.bundleID = bundleID
        self.name = name
        self.url = url
        self.privateLaunch = privateLaunch
    }

    /// This browser's private-window entry, named "<name> (<label>)".
    public func privateVariant(label: String, launch: PrivateLaunch) -> Browser {
        Browser(bundleID: bundleID, name: "\(name) (\(label))", url: url, privateLaunch: launch)
    }
}
