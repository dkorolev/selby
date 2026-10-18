import Foundation

/// Which browsers can open a private window on demand, and how.
public enum PrivateVariants {
    /// Each vendor's own name for the mode, so the picker says "Google Chrome
    /// (Incognito)" rather than a made-up term.
    public static let catalog: [String: (label: String, launch: PrivateLaunch)] = [
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

    /// Inserts each supported browser's private variant directly after it.
    /// Idempotent: existing variants are kept and never duplicated.
    public static func inserting(into browsers: [Browser]) -> [Browser] {
        let existing = Set(browsers.map(\.id))
        return browsers.flatMap { browser -> [Browser] in
            guard !browser.isPrivate,
                  let entry = catalog[browser.bundleID],
                  !existing.contains(browser.id + Browser.privateIDSuffix)
            else { return [browser] }
            return [browser, browser.privateVariant(label: entry.label, launch: entry.launch)]
        }
    }
}
