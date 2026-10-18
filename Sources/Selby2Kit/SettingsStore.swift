import AppKit
import Combine
import Selby2Core

/// Owns the persisted `Settings` and the current browser list.
@MainActor
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore(defaults: .standard)

    private static let key = "settings"

    private let defaults: UserDefaults
    private let discover: () -> [Browser]

    /// Saved as JSON on every change.
    @Published public private(set) var settings: Settings {
        didSet { save() }
    }
    /// Every installed browser and private variant, in the user's order.
    /// Refreshed on launch, when Settings opens, and before each picker.
    @Published public private(set) var browsers: [Browser] = []

    public init(
        defaults: UserDefaults, discover: @escaping () -> [Browser] = { BrowserDiscovery.installedBrowsers() }
    ) {
        self.defaults = defaults
        self.discover = discover
        let (loaded, imported) = Self.load(from: defaults)
        settings = loaded
        if imported { save() }
        refresh()
    }

    public func refresh() {
        browsers = settings.arranged(discover())
    }

    /// The picker's rows.
    public var visibleBrowsers: [Browser] {
        browsers.filter(settings.isVisible)
    }

    public func isVisible(_ browser: Browser) -> Bool {
        settings.isVisible(browser)
    }

    public func setVisible(_ visible: Bool, _ browser: Browser) {
        settings.setVisible(visible, browser)
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        browsers = settings.move(browsers, fromOffsets: source, toOffset: destination)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }

    /// Reads the JSON blob. On first run, imports the three keys the
    /// original Selby (bundle ID `dev.selby.Selby`) stored, so switching
    /// keeps the user's order and toggles; `imported` asks the caller to
    /// persist the result so the import happens once.
    private static func load(from defaults: UserDefaults) -> (settings: Settings, imported: Bool) {
        if let data = defaults.data(forKey: key), let settings = try? JSONDecoder().decode(Settings.self, from: data) {
            return (settings, false)
        }
        guard let legacy = UserDefaults(suiteName: "dev.selby.Selby") else { return (Settings(), false) }
        let settings = Settings(
            order: legacy.stringArray(forKey: "browserOrder") ?? [],
            hidden: Set(legacy.stringArray(forKey: "disabledBrowserIDs") ?? []),
            enabledPrivate: Set(legacy.stringArray(forKey: "enabledPrivateBrowserIDs") ?? [])
        )
        return (settings, settings != Settings())
    }
}
