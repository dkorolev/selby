import AppKit
import ApplicationServices
import Selby2Core
import os

enum LaunchError: LocalizedError {
    case noExecutable(String)
    case accessibilityDenied
    case helperFailed(String, Int32)

    var errorDescription: String? {
        switch self {
        case .noExecutable(let name):
            return "\(name) has no executable to launch."
        case .accessibilityDenied:
            return "Selby needs Accessibility access to open a Safari private window. "
                + "Grant it in System Settings › Privacy & Security › Accessibility, then try again."
        case .helperFailed(let name, let status):
            return "The \(name) helper exited with status \(status). "
                + "If macOS asked to allow Automation, allow it and try again."
        }
    }
}

/// Hands URLs to a browser.
@MainActor
final class BrowserLauncher {
    private let log = Logger(subsystem: "dev.selby.Selby2", category: "launch")
    /// Short-lived helpers kept until they exit, so they are reaped.
    private var helpers: [Process] = []

    /// `onFailure` is called on the main actor if the browser could not be
    /// asked; success is "the browser accepted the request", not "the page
    /// loaded".
    func open(_ urls: [URL], in browser: Browser, onFailure: @escaping @MainActor (Error) -> Void) {
        log.notice("Opening \(urls.count) URL(s) in \(browser.name, privacy: .public)")
        if browser.mainTab == .yabPersonal {
            openYabPersonalTab(urls, name: browser.name, onFailure: onFailure)
            return
        }
        switch browser.privateLaunch {
        case nil:
            openNormally(urls, in: browser, onFailure: onFailure)
        case .safariScripting:
            openSafariPrivateWindow(urls, onFailure: onFailure)
        case .flagBeforeURLs, .flagPerURL:
            openPrivateWindow(urls, in: browser, onFailure: onFailure)
        }
    }

    private func openNormally(_ urls: [URL], in browser: Browser, onFailure: @escaping @MainActor (Error) -> Void) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(urls, withApplicationAt: browser.url, configuration: configuration) { _, error in
            Task { @MainActor in
                if let error {
                    self.log.error("Handoff failed: \(error.localizedDescription)")
                    onFailure(error)
                } else {
                    self.log.notice("Browser accepted \(urls.count) URL(s)")
                }
            }
        }
    }

    /// LaunchServices cannot express a window mode, but every supported
    /// browser's command line can. A browser that is not running is launched
    /// through LaunchServices with the flag as its arguments, so it is a
    /// first-class app and not Selby2's child. A running browser gets a
    /// short-lived copy of its own binary that forwards the command line to
    /// the live instance and exits.
    private func openPrivateWindow(
        _ urls: [URL], in browser: Browser, onFailure: @escaping @MainActor (Error) -> Void
    ) {
        guard let launch = browser.privateLaunch else { return }
        let arguments = launch.arguments(for: urls)
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: browser.bundleID)
            .first { !$0.isTerminated }
        guard let running else {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = arguments
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: browser.url, configuration: configuration) { _, error in
                Task { @MainActor in
                    if let error {
                        self.log.error("Private launch failed: \(error.localizedDescription)")
                        onFailure(error)
                    } else {
                        self.log.notice("Launched \(browser.name, privacy: .public) with a private window")
                    }
                }
            }
            return
        }
        guard let executable = Bundle(url: browser.url)?.executableURL else {
            onFailure(LaunchError.noExecutable(browser.name))
            return
        }
        let forwarder = Process()
        forwarder.executableURL = executable
        forwarder.arguments = arguments
        run(forwarder, name: browser.name, onFailure: onFailure)
        running.activate()
    }

    /// Safari's scripting dictionary cannot create a private window, so the
    /// script clicks File › New Private Window through accessibility. The
    /// item is matched by its ⌘⇧N shortcut, not its localized name. Each
    /// wait aborts rather than pressing on against an unknown UI state.
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

    /// Asks Yab for a tab in its Personal space. Launch Services cannot say
    /// that: Yab treats a link from another app as a Small Window. The first
    /// run prompts for Automation, the same prompt Safari's private window uses.
    private static let yabPersonalScript = """
    on run argv
        tell application "Yab"
            activate
            repeat 30 times
                if (count of windows) > 0 then exit repeat
                delay 0.1
            end repeat
            if (count of windows) is 0 then make new window
            set targetWindow to missing value
            repeat with w in windows
                try
                    if (count of spaces of w) > 0 then
                        set targetWindow to w
                        exit repeat
                    end if
                end try
            end repeat
            if targetWindow is missing value then set targetWindow to window 1
            tell targetWindow
                set targetSpace to space 1
                repeat with s in spaces
                    if (id of s as text) is "\(YabRows.personalSpaceID)" then
                        set targetSpace to s
                        exit repeat
                    end if
                end repeat
                repeat with i from 1 to count of argv
                    tell targetSpace to make new tab with properties {URL:item i of argv}
                end repeat
            end tell
        end tell
    end run
    """

    private func openYabPersonalTab(
        _ urls: [URL], name: String, onFailure: @escaping @MainActor (Error) -> Void
    ) {
        let script = Process()
        script.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        script.arguments = ["-e", Self.yabPersonalScript] + urls.map(\.absoluteString)
        run(script, name: name, onFailure: onFailure)
    }

    /// Runs the script out of process so its waits never block Selby2. The
    /// menu click needs Accessibility; without it macOS shows its prompt and
    /// the user is told to retry.
    private func openSafariPrivateWindow(_ urls: [URL], onFailure: @escaping @MainActor (Error) -> Void) {
        // The literal spelling of kAXTrustedCheckOptionPrompt; the global
        // itself is not concurrency-safe to read under Swift 6.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            log.error("Safari private window needs Accessibility; prompted")
            onFailure(LaunchError.accessibilityDenied)
            return
        }
        let script = Process()
        script.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        script.arguments = ["-e", Self.safariPrivateScript] + PrivateLaunch.safariScripting.arguments(for: urls)
        run(script, name: "Safari (Private)", onFailure: onFailure)
    }

    /// Starts a short-lived helper and reports a non-zero exit as a failure.
    private func run(_ process: Process, name: String, onFailure: @escaping @MainActor (Error) -> Void) {
        let id = ObjectIdentifier(process)
        process.terminationHandler = { finished in
            let status = finished.terminationStatus
            Task { @MainActor in
                self.helpers.removeAll { ObjectIdentifier($0) == id }
                if status != 0 {
                    self.log.error("\(name, privacy: .public) helper exited with status \(status)")
                    onFailure(LaunchError.helperFailed(name, status))
                } else {
                    self.log.notice("\(name, privacy: .public) helper finished")
                }
            }
        }
        do {
            try process.run()
            helpers.append(process)
        } catch {
            log.error("Failed to start \(name, privacy: .public) helper: \(error.localizedDescription)")
            onFailure(error)
        }
    }
}
