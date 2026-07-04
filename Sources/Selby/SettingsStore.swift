import AppKit
import Combine
import SelbyCore

/// The single source of truth for user preferences, persisted in `UserDefaults`.
///
/// Persistence model: we store the set of *disabled* browser bundle IDs rather
/// than enabled ones, so a newly installed browser shows up in the picker
/// automatically instead of being silently hidden. Private-window variants
/// use the opposite polarity — an *enabled* set — so they are opt-in and
/// don't double the picker's rows for everyone.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    /// `UserDefaults` key holding the bundle IDs the user has hidden from the picker.
    private static let disabledKey = "disabledBrowserIDs"
    /// `UserDefaults` key holding the private-variant IDs the user has opted into.
    private static let enabledPrivateKey = "enabledPrivateBrowserIDs"
    /// `UserDefaults` key holding the user's manual browser order (bundle IDs).
    private static let orderKey = "browserOrder"

    private let defaults = UserDefaults.standard

    /// All HTTP(S)-capable apps currently installed, in display order: the
    /// user's manual arrangement first, newly discovered browsers after it
    /// alphabetically. Refreshed on launch, when Settings opens, and before
    /// each picker display.
    @Published private(set) var browsers: [Browser] = []

    /// The user's manual ordering from Settings drag-reordering, as bundle
    /// IDs. Empty until the user first re-arranges. Persisted because the
    /// picker's rows, digit shortcuts, and "first in list" default all follow
    /// this order.
    @Published private(set) var browserOrder: [String] {
        didSet { defaults.set(browserOrder, forKey: Self.orderKey) }
    }

    /// Bundle IDs the user has excluded from the picker. Stored (instead of an
    /// enabled-set) so new browsers default to visible.
    @Published var disabledIDs: Set<String> {
        didSet { defaults.set(Array(disabledIDs).sorted(), forKey: Self.disabledKey) }
    }

    /// Private-variant IDs the user has opted into showing in the picker.
    @Published var enabledPrivateIDs: Set<String> {
        didSet { defaults.set(Array(enabledPrivateIDs).sorted(), forKey: Self.enabledPrivateKey) }
    }

    private init() {
        disabledIDs = Set(defaults.stringArray(forKey: Self.disabledKey) ?? [])
        enabledPrivateIDs = Set(defaults.stringArray(forKey: Self.enabledPrivateKey) ?? [])
        browserOrder = defaults.stringArray(forKey: Self.orderKey) ?? []
        refresh()
    }

    /// Re-scans installed browsers via LaunchServices and applies the user's
    /// manual order.
    func refresh() {
        browsers = BrowserOrdering.apply(order: browserOrder, to: BrowserDiscovery.installedBrowsers())
    }

    /// Handles a drag-reorder from Settings; the resulting full arrangement
    /// becomes the persisted order.
    func moveBrowsers(fromOffsets source: IndexSet, toOffset destination: Int) {
        var arranged = browsers
        arranged.move(fromOffsets: source, toOffset: destination)
        browsers = arranged
        browserOrder = arranged.map(\.id)
    }

    /// Browsers shown in the picker, in display order.
    var enabledBrowsers: [Browser] {
        browsers.filter { isEnabled($0) }
    }

    func isEnabled(_ browser: Browser) -> Bool {
        browser.privateLaunch == nil
            ? !disabledIDs.contains(browser.id)
            : enabledPrivateIDs.contains(browser.id)
    }

    func setEnabled(_ enabled: Bool, for browser: Browser) {
        if browser.privateLaunch == nil {
            if enabled {
                disabledIDs.remove(browser.id)
            } else {
                disabledIDs.insert(browser.id)
            }
        } else {
            if enabled {
                enabledPrivateIDs.insert(browser.id)
            } else {
                enabledPrivateIDs.remove(browser.id)
            }
        }
    }

    /// Whether Selby is currently the macOS default browser.
    var isSystemDefault: Bool {
        // Force-unwrap is safe: the literal is a well-formed URL.
        let probe = URL(string: "http://example.com")!
        guard let handler = NSWorkspace.shared.urlForApplication(toOpen: probe) else { return false }
        return Bundle(url: handler)?.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    /// Asks macOS to make Selby the default browser. The system shows its own
    /// confirmation dialog; `completion` receives `nil` on success, the error
    /// otherwise (including user refusal).
    func makeSystemDefault(completion: @escaping @Sendable (Error?) -> Void) {
        NSWorkspace.shared.setDefaultApplication(
            at: Bundle.main.bundleURL,
            toOpenURLsWithScheme: "http",
            completion: completion
        )
    }
}
