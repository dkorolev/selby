import AppKit
import Selby2Kit
import SwiftUI
import os

/// Owns the Settings window. A plain `NSWindow` rather than the SwiftUI
/// `Settings` scene, which can silently fail to appear when opened
/// programmatically from a background agent.
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    static let shared = SettingsWindow()

    private let log = Logger(subsystem: "dev.selby.Selby2", category: "settings")
    /// Created on first show, kept so later shows keep its position.
    private var window: NSWindow?

    /// Shows the window on the current Space, in front. It floats until the
    /// user moves on from it, so a declined activation request (the norm for
    /// background agents) cannot leave it buried under other apps' windows.
    func show() {
        NSApp.activate()
        let window = self.window ?? makeWindow()
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        log.notice("Settings shown (visible: \(window.isVisible), key: \(window.isKeyWindow))")
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView(store: .shared))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Selby2 Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        return window
    }

    /// Once the user has been in the window and left it, it behaves like an
    /// ordinary window again.
    func windowDidResignKey(_ notification: Notification) {
        window?.level = .normal
    }
}
