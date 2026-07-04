import AppKit
import SelbyCore
import os

/// Owns the lifecycle of the picker panel: one at a time, shown at the mouse,
/// torn down on choice, cancel, or replacement by a newer link click.
@MainActor
final class PickerController {
    static let shared = PickerController()

    private let log = Logger(subsystem: "dev.selby.Selby", category: "picker")

    /// How long unopened URLs from an outside-click cancel stay reclaimable.
    /// The cancel-to-URL-delivery gap for a single link click is ~100–300ms
    /// (mouse-down cancels instantly; the URL takes an Apple-Event round
    /// trip); 0.5s covers that while making it unlikely an unrelated later
    /// click resurrects deliberately dismissed URLs.
    private static let reclaimWindow: TimeInterval = 0.5

    /// The currently visible panel, if any.
    private var panel: PickerPanel?
    /// The model backing `panel`; kept so URL bursts can coalesce into it.
    private var model: PickerModel?
    /// Global mouse monitor that cancels the picker when the user clicks in
    /// another application (our panel never sees those events).
    private var mouseMonitor: Any?
    /// The app the user was in when the picker appeared; used to hand focus
    /// back if the activation fallback made Selby the active app.
    private var previousApp: NSRunningApplication?
    /// True when the key-window fallback had to activate Selby. On cancel we
    /// must then re-activate `previousApp`, or keystrokes go nowhere (Selby is
    /// a windowless agent once the panel closes).
    private var activatedDuringFallback = false
    /// URLs from a picker that an outside click cancelled, plus when. When the
    /// cancelling click was itself a link click, its URL arrives moments later
    /// and reclaims these — otherwise every link but the last in a rapid
    /// click sequence would be silently dropped.
    private var reclaimableURLs: [URL] = []
    private var reclaimableSince: Date?

    /// Entry point for every incoming URL open.
    func present(urls incomingURLs: [URL]) {
        // macOS delivers link bursts as one delegate call per URL. If a picker
        // is already up, join it instead of cancelling it — cancelling would
        // silently drop every URL but the last.
        if let model, panel != nil {
            model.add(incomingURLs)
            log.notice("Coalesced \(incomingURLs.count) URL(s) into the visible picker")
            return
        }
        dismissPanel()

        // A picker cancelled by an outside mouse-down may have been cancelled
        // by the very click that produced this URL; reclaim its URLs so both
        // links open, not just the newest.
        var urls = incomingURLs
        if let since = reclaimableSince, Date().timeIntervalSince(since) < Self.reclaimWindow {
            log.notice("Reclaiming \(self.reclaimableURLs.count) URL(s) from the just-cancelled picker")
            urls = reclaimableURLs + urls
        }
        reclaimableURLs = []
        reclaimableSince = nil

        let store = SettingsStore.shared
        store.refresh()
        let browsers = store.enabledBrowsers

        guard !browsers.isEmpty else {
            log.error("No browsers enabled; cannot open \(urls.map(\.absoluteString).joined(separator: " "))")
            NSSound.beep()
            return
        }
        // A menu with a single row is pure friction — open directly.
        if browsers.count == 1 {
            log.notice("Single browser enabled; opening directly in \(browsers[0].name, privacy: .public)")
            open(urls, with: browsers[0])
            return
        }
        log.notice("Presenting picker: \(browsers.count) browsers for \(urls.count) URL(s)")

        previousApp = NSWorkspace.shared.frontmostApplication
        activatedDuringFallback = false

        // Enter always opens the top of the user's order; reordering in
        // Settings IS the default-browser configuration.
        let model = PickerModel(
            urls: urls,
            browsers: browsers,
            defaultIndex: 0
        )
        model.onFinish = { [weak self] outcome in
            guard let self else { return }
            // Read the coalesced list before dismissPanel() drops the model.
            let unopenedURLs = self.model?.urls ?? urls
            let mustRestoreFocus = self.activatedDuringFallback
            self.dismissPanel()
            switch outcome {
            case .chose(let browser):
                self.open(unopenedURLs, with: browser)
            case .cancelled(let reason):
                if reason == .outsideClick {
                    self.reclaimableURLs = unopenedURLs
                    self.reclaimableSince = Date()
                }
                if mustRestoreFocus, NSApp.isActive {
                    // The fallback made Selby active; hand focus back so the
                    // user's keystrokes don't go nowhere after Esc.
                    self.previousApp?.activate()
                }
            case .openSettings:
                SettingsOpener.shared.open()
            }
        }
        self.model = model

        let mouse = NSEvent.mouseLocation
        let visibleFrame = screen(for: mouse)?.visibleFrame
        // Cap the browser list so the panel always fits on this screen; the
        // list scrolls when there are more rows than fit.
        let maxListHeight = max(150, (visibleFrame?.height ?? 800) - 80)

        let panel = PickerPanel(model: model, maxListHeight: maxListHeight)
        self.panel = panel
        position(panel, near: mouse, within: visibleFrame)
        panel.makeKeyAndOrderFront(nil)

        // Non-activating panels normally take key focus without activating the
        // app, but fall back to explicit activation if that didn't happen.
        // The identity check keeps a stale async hop from touching a panel
        // that has already been replaced.
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let self, let panel, panel === self.panel, !panel.isKeyWindow else { return }
            self.activatedDuringFallback = true
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak model] _ in
            Task { @MainActor in model?.cancel(.outsideClick) }
        }
    }

    /// Hands the URLs to the chosen browser and lets it come to the front.
    private func open(_ urls: [URL], with browser: Browser) {
        log.notice("Opening \(urls.count) URL(s) in \(browser.name, privacy: .public)")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(urls, withApplicationAt: browser.url, configuration: configuration) { _, error in
            if let error {
                Task { @MainActor [log = self.log] in
                    log.error("Failed to open in \(browser.name): \(error.localizedDescription)")
                    NSSound.beep()
                }
            }
        }
    }

    /// The screen the mouse is on. NSMouseInRect, not NSRect.contains: a
    /// cursor pinned at the top edge reports y == frame.maxY, which contains()
    /// excludes. Falls back to the nearest screen rather than NSScreen.main
    /// (the wrong monitor for clicks on secondary displays).
    private func screen(for point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
            ?? NSScreen.screens.min { lhs, rhs in
                distanceSquared(from: lhs.frame, to: point) < distanceSquared(from: rhs.frame, to: point)
            }
    }

    /// Squared distance from `point` to the nearest edge of `rect`; zero when
    /// inside.
    private func distanceSquared(from rect: NSRect, to point: NSPoint) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }

    /// Positions the panel like a context menu: top-left corner at the mouse,
    /// so the pointer rests on the hover-free URL header rather than a browser
    /// row. Clamped to the screen's visible frame; near the bottom edge the
    /// panel flips above the cursor instead, because the upward clamp would
    /// otherwise slide a row directly under the pointer.
    private func position(_ panel: PickerPanel, near mouse: NSPoint, within visible: NSRect?) {
        panel.contentView?.layoutSubtreeIfNeeded()
        let size = panel.contentView?.fittingSize ?? NSSize(width: 260, height: 200)
        panel.setContentSize(size)

        // Screen coordinates are bottom-left origin: subtracting the height
        // puts the panel's top edge at the cursor. Small offsets keep the
        // first row from sitting exactly under the pointer.
        var origin = NSPoint(x: mouse.x - 12, y: mouse.y - size.height + 12)
        if let visible {
            let wouldClampUp = origin.y < visible.minY + 8
            let fitsAbove = mouse.y + 12 + size.height <= visible.maxY - 8
            if wouldClampUp, fitsAbove {
                origin.y = mouse.y + 12
            }
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        }
        panel.setFrameOrigin(origin)
    }

    private func dismissPanel() {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
        model = nil
    }
}
