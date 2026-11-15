import AppKit
import Selby2Core

extension Browser {
    /// The app's icon. Computed, not stored, so `Browser` stays a plain
    /// value; `NSWorkspace` caches the lookup.
    public var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}

extension PickerKey {
    /// Decodes an AppKit key event.
    public init?(event: NSEvent) {
        self.init(keyCode: event.keyCode, characters: event.charactersIgnoringModifiers)
    }
}

/// Identity stamped into the bundle by `scripts/build.sh`.
public enum BuildInfo {
    /// "1.2.3 (abc1234)" from a built bundle, "dev" under `swift run`.
    public static var label: String {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let sha = info["SelbyGitSHA"] as? String else { return "dev" }
        let version = info["CFBundleShortVersionString"] as? String ?? "0"
        return "\(version) (\(sha))"
    }
}
