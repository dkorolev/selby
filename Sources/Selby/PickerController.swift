import AppKit
import ApplicationServices
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
    /// Private-window launches in flight; each removes itself on termination.
    private var privateLaunchProcesses: [Process] = []

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
        showPicker(for: urls, browsers: browsers)
    }

    /// Builds the model and panel for one picker invocation and puts it on
    /// screen, key, at the mouse. `browsers` has at least two entries — the
    /// zero- and one-browser cases were short-circuited in `present`.
    private func showPicker(for urls: [URL], browsers: [Browser]) {
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
        if let privateLaunch = browser.privateLaunch {
            openPrivateWindow(urls, with: browser, launch: privateLaunch)
            return
        }
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

    /// Opens the URLs in a private window by invoking the browser binary with
    /// its private-window flag — LaunchServices has no way to express "this
    /// window mode", but every supported browser's command line forwards the
    /// request to the running instance (or starts one). Safari has no such
    /// command line and takes the scripted path instead.
    private func openPrivateWindow(_ urls: [URL], with browser: Browser, launch: PrivateLaunch) {
        if launch == .safariScripting {
            openSafariPrivateWindow(urls, launch: launch)
            return
        }
        guard let executable = Bundle(url: browser.url)?.executableURL else {
            log.error("No executable in \(browser.url.path) for \(browser.name, privacy: .public)")
            NSSound.beep()
            return
        }
        let process = Process()
        process.executableURL = executable
        process.arguments = launch.arguments(for: urls)
        launchAndRetain(process, name: browser.name, beepOnFailureExit: false)
        activateBrowser(bundleID: browser.bundleID)
    }

    /// AppleScript that opens a Safari private window and loads argv's URLs
    /// into it. Safari's scripting dictionary cannot create a private window,
    /// so the script clicks File → New Private Window through accessibility —
    /// matched by its shortcut metadata (⌘⇧N: cmd char "N", modifiers 1 =
    /// shift+cmd), not by its localized name. A synthesized ⌘⇧N keystroke is
    /// NOT used: keystroke delivery right after activation proved flaky, and
    /// a menu-item click either lands or throws. Each wait aborts hard on
    /// timeout rather than pressing on against an unknown UI state.
    private static let safariPrivateScript = """
    on run argv
        tell application "Safari" to activate
        tell application "System Events"
            repeat 30 times
                if frontmost of process "Safari" then exit repeat
                delay 0.1
            end repeat
            if not frontmost of process "Safari" then error "Safari did not become frontmost"
        end tell
        tell application "Safari" to set oldCount to count of windows
        tell application "System Events"
            tell process "Safari"
                set fileMenu to menu 1 of menu bar item 3 of menu bar 1
                click (first menu item of fileMenu whose ¬
                    value of attribute "AXMenuItemCmdChar" is "N" and ¬
                    value of attribute "AXMenuItemCmdModifiers" is 1)
            end tell
        end tell
        tell application "Safari"
            repeat 30 times
                if (count of windows) > oldCount then exit repeat
                delay 0.1
            end repeat
            if (count of windows) is not greater than oldCount then error "no private window appeared"
            set URL of current tab of front window to item 1 of argv
            repeat with i from 2 to count of argv
                tell front window to make new tab with properties {URL:item i of argv}
            end repeat
        end tell
    end run
    """

    /// Runs the Safari private-window script via `osascript` (out of process,
    /// so the delays inside it never block Selby). The menu-item click
    /// requires Accessibility; when missing, this shows the system prompt and
    /// bails — the user grants once and the next attempt works.
    private func openSafariPrivateWindow(_ urls: [URL], launch: PrivateLaunch) {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        guard AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary) else {
            log.error("Safari private window needs Accessibility permission; prompted")
            NSSound.beep()
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", Self.safariPrivateScript] + launch.arguments(for: urls)
        // Beep on failure: a nonzero exit here means the user declined the
        // Automation prompt (Safari or System Events) or the script broke.
        launchAndRetain(process, name: "Safari (Private)", beepOnFailureExit: true)
    }

    /// Starts `process`, keeping a reference until exit so the child is
    /// reaped, not zombied. A private-window forwarder exits in milliseconds;
    /// a browser that wasn't already running IS this process and lives for
    /// hours — which is why `beepOnFailureExit` must stay off for browser
    /// binaries (their exit status at logout means nothing to the user).
    private func launchAndRetain(_ process: Process, name: String, beepOnFailureExit: Bool) {
        process.terminationHandler = { [weak self] finished in
            let status = finished.terminationStatus
            Task { @MainActor in
                self?.privateLaunchProcesses.removeAll { $0 === finished }
                if beepOnFailureExit, status != 0 {
                    self?.log.error("\(name, privacy: .public) helper exited with status \(status)")
                    NSSound.beep()
                }
            }
        }
        do {
            try process.run()
            privateLaunchProcesses.append(process)
        } catch {
            log.error("Failed to launch \(name, privacy: .public): \(error.localizedDescription)")
            NSSound.beep()
        }
    }

    /// Brings the browser frontmost after a private-window launch: a directly
    /// spawned binary gets no LaunchServices activation, and a running
    /// instance receiving a forwarded command stays in the background. Polls
    /// briefly because a cold start takes a moment to register with AppKit.
    private func activateBrowser(bundleID: String, attemptsLeft: Int = 10) {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { !$0.isTerminated }) {
            app.activate()
        } else if attemptsLeft > 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.activateBrowser(bundleID: bundleID, attemptsLeft: attemptsLeft - 1)
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
