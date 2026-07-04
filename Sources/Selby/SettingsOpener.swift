import AppKit
import SwiftUI
import os

/// Owns the Settings window directly. The SwiftUI `Settings` scene proved
/// unreliable when opened programmatically from a background agent (its
/// window can silently fail to appear); a plain NSWindow we hold ourselves
/// can always be forced onto the user's screen.
@MainActor
final class SettingsOpener {
    static let shared = SettingsOpener()

    private let log = Logger(subsystem: "dev.selby.Selby", category: "settings")

    /// Created on first open, kept (not released on close) so every later
    /// open reuses it with its position intact.
    private var window: NSWindow?

    /// Shows the Settings window on the current Space, in front of everything.
    /// It floats for a moment so a declined activation request (the norm for
    /// background agents) cannot leave it buried under other apps' windows.
    func open() {
        NSApp.activate(ignoringOtherApps: true)
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let created = NSWindow(contentViewController: hosting)
            created.title = "Selby Settings"
            created.styleMask = [.titled, .closable, .miniaturizable]
            created.isReleasedWhenClosed = false
            created.center()
            window = created
        }
        guard let window else { return }
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak window] in
            window?.level = .normal
        }
        let screenName = window.screen?.localizedName ?? "none"
        log.notice("""
        Settings window ordered front (visible: \(window.isVisible), screen: \(screenName, privacy: .public))
        """)
    }
}
