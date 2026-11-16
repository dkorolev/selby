import AppKit
import Selby2Core
import Selby2Kit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "dev.selby.Selby", category: "delivery")
    private let picker = PickerController(store: .shared, launcher: BrowserLauncher())
    /// URLs delivered before launch completed. macOS hands a launching app
    /// its URL before `applicationDidFinishLaunching`; a panel created that
    /// early cannot take key focus, so presentation waits for launch.
    private var pendingURLs: [URL] = []
    private var finishedLaunching = false
    /// Same-click duplicates from an app that opens a link twice.
    private var recentDeliveries = RecentDeliveries()

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.notice("Selby launched, build \(BuildInfo.label, privacy: .public)")
        finishedLaunching = true
        SettingsStore.shared.refresh()
        if !pendingURLs.isEmpty {
            let urls = pendingURLs
            pendingURLs = []
            picker.present(urls: urls)
            return
        }
        // AppKit says why it launched us: a plain launch (Finder, `open -a
        // Selby`, Launchpad) is the user asking for Settings; a launch to
        // open a URL is not.
        let isDefaultLaunch = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? true
        if isDefaultLaunch {
            log.notice("Default launch; showing Settings")
            SettingsWindow.shared.show()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard !urls.isEmpty else { return }
        let fresh = recentDeliveries.fresh(urls, at: Date())
        let repeated = urls.count - fresh.count
        if repeated > 0 {
            log.notice("Ignored \(repeated) repeated URL(s)")
        }
        guard !fresh.isEmpty else { return }
        log.notice("Received \(fresh.count) URL(s) from macOS")
        if finishedLaunching {
            picker.present(urls: fresh)
        } else {
            pendingURLs += fresh
        }
    }

    /// Double-clicking Selby in Finder, or `open -a Selby`, while it is
    /// already running: the way into Settings when a crowded menu bar hides
    /// the globe. Never over a pending picker.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !picker.hasPendingPicker {
            SettingsWindow.shared.show()
        }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
