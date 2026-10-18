import AppKit
import Selby2Core
import Selby2Kit
import os

/// Owns the picker's lifecycle: one at a time, at the pointer, torn down on
/// choice, cancel, or the gear.
@MainActor
final class PickerController {
    private let log = Logger(subsystem: "dev.selby.Selby2", category: "picker")
    private let store: SettingsStore
    private let launcher: BrowserLauncher

    private var panel: PickerPanel?
    private var model: PickerModel?
    private var reclaimable = ReclaimableLinks()
    /// The app the user was in; focus goes back to it if the activation
    /// fallback made Selby2 active and the user then cancelled.
    private var previousApp: NSRunningApplication?
    private var activatedDuringFallback = false

    var hasPendingPicker: Bool { model != nil }

    init(store: SettingsStore, launcher: BrowserLauncher) {
        self.store = store
        self.launcher = launcher
    }

    /// Entry point for every incoming URL open.
    func present(urls incoming: [URL], forcePicker: Bool = false) {
        // A link burst is one delegate call per URL; join the visible picker
        // rather than replace it, or every URL but the last would be lost.
        if let model, !model.isFinished {
            model.add(incoming)
            log.notice("Coalesced \(incoming.count) URL(s) into the visible picker")
            return
        }
        dismissPanel()

        let reclaimed = reclaimable.reclaim(at: Date())
        if !reclaimed.isEmpty {
            log.notice("Reclaimed \(reclaimed.count) URL(s) from the picker the click cancelled")
        }
        let urls = reclaimed + incoming

        store.refresh()
        let browsers = store.visibleBrowsers
        guard !browsers.isEmpty else {
            log.error("No browsers visible; cannot open \(urls.count) URL(s)")
            NSSound.beep()
            SettingsWindow.shared.show()
            return
        }
        if browsers.count == 1, !forcePicker {
            log.notice("Single browser; opening directly in \(browsers[0].name, privacy: .public)")
            open(urls, with: browsers[0])
            return
        }
        log.notice("Presenting picker: \(browsers.count) browsers for \(urls.count) URL(s)")
        showPicker(urls: urls, browsers: browsers)
    }

    private func showPicker(urls: [URL], browsers: [Browser]) {
        previousApp = NSWorkspace.shared.frontmostApplication
        activatedDuringFallback = false

        let mouse = NSEvent.mouseLocation
        // Return opens the top of the user's order: reordering in Settings
        // is the default-browser configuration.
        let model = PickerModel(session: PickerSession(urls: urls, browsers: browsers), mouseLocation: mouse)
        model.onFinish = { [weak self] outcome in
            self?.finish(outcome, model: model)
        }
        self.model = model

        let visible = PickerPlacement.frame(containing: mouse, among: NSScreen.screens.map(\.frame))
            .flatMap { frame in NSScreen.screens.first { $0.frame == frame }?.visibleFrame }
            ?? CGRect(x: 0, y: 0, width: 1280, height: 800)
        let maxListHeight = PickerPlacement.maxListHeight(visibleHeight: visible.height)
        let panel = PickerPanel(model: model, maxListHeight: maxListHeight)
        self.panel = panel
        panel.place(near: mouse, within: visible)
        panel.monitorOutsideClicks()
        panel.makeKeyAndOrderFront(nil)
        log.notice("Picker visible: \(panel.isVisible), key: \(panel.isKeyWindow)")

        // A non-activating panel normally takes key focus without activating
        // the app. If it did not, activate explicitly. The identity check
        // keeps a stale hop from touching a replaced panel.
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let self, let panel, panel === self.panel, !panel.isKeyWindow else { return }
            self.log.notice("Panel not key; activating Selby2 as a fallback")
            self.activatedDuringFallback = true
            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
            self.log.notice("After fallback: active: \(NSApp.isActive), key: \(panel.isKeyWindow)")
        }
    }

    private func finish(_ outcome: PickerOutcome, model: PickerModel) {
        let urls = model.urls
        let mustRestoreFocus = activatedDuringFallback
        dismissPanel()
        switch outcome {
        case .chose(let browser):
            open(urls, with: browser)
        case .cancelled(let reason):
            log.notice("Picker cancelled: \(String(describing: reason), privacy: .public)")
            if reason == .outsideClick {
                reclaimable.park(urls, at: Date())
            }
            if mustRestoreFocus, NSApp.isActive {
                previousApp?.activate()
            }
        case .openSettings:
            SettingsWindow.shared.show()
        }
    }

    private func open(_ urls: [URL], with browser: Browser) {
        launcher.open(urls, in: browser) { [weak self] error in
            self?.offerRetry(urls, after: error, browser: browser)
        }
    }

    /// A failed handoff gets a visible error and another go at the picker,
    /// forced even if one browser remains, so a broken launch is never
    /// retried automatically.
    private func offerRetry(_ urls: [URL], after error: Error, browser: Browser) {
        let alert = NSAlert()
        alert.messageText = "Couldn’t open links in \(browser.name)"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "Choose Browser Again")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            present(urls: urls, forcePicker: true)
        }
    }

    private func dismissPanel() {
        panel?.stopMonitoringClicks()
        panel?.orderOut(nil)
        panel = nil
        model = nil
    }
}
