import Foundation

/// Where a link opens inside Yab, beyond the ordinary handoff.
public enum MainTab: Hashable, Sendable {
    /// A tab in Yab's built-in Personal space, the one that is there from
    /// the first launch. Not a Small Window.
    case yabPersonal
}

/// Yab shows up as two rows. Launch Services opens a Small Window, which is
/// what Yab does with a link from another app. The second row asks Yab for a
/// tab in Personal instead.
public enum YabRows {
    public static let bundleID = "dev.serafim.fast"
    /// Yab's built-in first space. Its default name is Personal; the id
    /// stays if that name is edited.
    public static let personalSpaceID = "00000000-0000-0000-0000-000000000001"
    public static let smallWindowLabel = "Small Window"
    public static let personalLabel = "Personal"

    /// Replaces the plain Yab row with the Small Window row and inserts
    /// Personal directly after it. Idempotent.
    public static func inserting(into browsers: [Browser]) -> [Browser] {
        let existing = Set(browsers.map(\.id))
        return browsers.flatMap { browser -> [Browser] in
            guard browser.bundleID == bundleID, !browser.isPrivate, browser.mainTab == nil else {
                return [browser]
            }
            let base = baseName(browser.name)
            let small = Browser(bundleID: browser.bundleID, name: "\(base) (\(smallWindowLabel))", url: browser.url)
            let personalID = browser.bundleID + Browser.personalIDSuffix
            guard !existing.contains(personalID) else { return [small] }
            let personal = Browser(
                bundleID: browser.bundleID,
                name: "\(base) (\(personalLabel))",
                url: browser.url,
                mainTab: .yabPersonal
            )
            return [small, personal]
        }
    }

    /// Drops a label this function itself added, so a second pass does not
    /// nest "Yab (Small Window) (Small Window)".
    private static func baseName(_ name: String) -> String {
        for label in [smallWindowLabel, personalLabel] {
            let suffix = " (\(label))"
            if name.hasSuffix(suffix) { return String(name.dropLast(suffix.count)) }
        }
        return name
    }
}
