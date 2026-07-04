import SwiftUI
import os

@main
struct SelbyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Selby", systemImage: "globe") {
            MenuBarContent()
        }
    }
}

private struct MenuBarContent: View {
    var body: some View {
        Button("Settings…") {
            SettingsOpener.shared.open()
        }
        Divider()
        Button("Quit Selby") {
            NSApp.terminate(nil)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set as soon as any URL arrives. Distinguishes "launched by a link
    /// click" (URL follows within milliseconds) from "opened deliberately by
    /// the user", which should land in Settings.
    private var receivedURL = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsStore.shared.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.receivedURL else { return }
            SettingsOpener.shared.open()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard !urls.isEmpty else { return }
        receivedURL = true
        PickerController.shared.present(urls: urls)
    }

    // Double-clicking Selby in Finder/Launchpad (or `open -a Selby`) lands
    // here when the app is already running. It is the escape hatch into
    // Settings when a crowded menu bar hides the globe icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            SettingsOpener.shared.open()
        }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
