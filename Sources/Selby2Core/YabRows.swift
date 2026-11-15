import Foundation

/// Where a link opens inside Yab, beyond the ordinary handoff.
public enum MainTab: Hashable, Sendable {
    /// A tab in Yab's built-in Personal space, the one that is there from
    /// the first launch. Not a Small Window.
    case yabPersonal
}

/// Yab shows up as two rows. Launch Services opens a new small window, which
/// is what Yab does with a link from another app. The other row asks Yab for
/// a tab in the window already open, in its Personal space.
public enum YabRows {
    public static let bundleID = "dev.serafim.fast"
    /// Yab's built-in first space. Its default name is Personal; the id
    /// stays if that name is edited.
    public static let personalSpaceID = "00000000-0000-0000-0000-000000000001"
    /// Opens a new small window over the app that was clicked.
    public static let newWindowLabel = "new window"
    /// Opens a tab in the window Yab already has.
    public static let defaultWindowLabel = "default window"

    /// Replaces the plain Yab row with the new-window row and inserts the
    /// default-window row directly after it. Idempotent.
    public static func inserting(into browsers: [Browser]) -> [Browser] {
        let existing = Set(browsers.map(\.id))
        return browsers.flatMap { browser -> [Browser] in
            guard browser.bundleID == bundleID, !browser.isPrivate, browser.mainTab == nil else {
                return [browser]
            }
            let base = baseName(browser.name)
            let newWindow = Browser(bundleID: browser.bundleID, name: "\(base) \(newWindowLabel)", url: browser.url)
            let personalID = browser.bundleID + Browser.personalIDSuffix
            guard !existing.contains(personalID) else { return [newWindow] }
            let defaultWindow = Browser(
                bundleID: browser.bundleID,
                name: "\(base) \(defaultWindowLabel)",
                url: browser.url,
                mainTab: .yabPersonal
            )
            return [newWindow, defaultWindow]
        }
    }

    /// Drops a label this function itself added, so a second pass does not
    /// nest "Yab new window new window". Also accepts the previous
    /// parenthetical labels.
    private static func baseName(_ name: String) -> String {
        let suffixes = [
            " \(newWindowLabel)",
            " \(defaultWindowLabel)",
            " (Small Window)",
            " (Personal)",
        ]
        for suffix in suffixes where name.hasSuffix(suffix) {
            return String(name.dropLast(suffix.count))
        }
        return name
    }
}
