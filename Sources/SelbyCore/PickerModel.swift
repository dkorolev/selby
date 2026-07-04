import AppKit

/// Why a picker went away without opening anything.
public enum PickerCancelReason: Equatable, Sendable {
    /// The user explicitly dismissed it (Esc).
    case dismissed
    /// A click landed outside the panel. This may be the mouse-down of the
    /// user's *next* link click, whose URL will arrive moments later — the
    /// controller uses this distinction to reclaim the unopened URLs.
    case outsideClick
}

/// How a picker invocation ended. An enum rather than `Browser?` so the
/// cancel path carries its reason and no impossible combination exists.
public enum PickerOutcome: Equatable {
    /// The user picked this browser; open the URLs there.
    case chose(Browser)
    /// Nothing gets opened (for this invocation).
    case cancelled(PickerCancelReason)
    /// The user pressed the picker's gear button: close without opening
    /// anything and show the Settings window instead.
    case openSettings
}

/// Observable state for one picker invocation. Created fresh per link click,
/// discarded when the panel closes.
@MainActor
public final class PickerModel: ObservableObject {
    /// The URLs to open; all are handed to the chosen browser. Grows while the
    /// picker is up: macOS delivers link bursts as one open event per URL, and
    /// later arrivals coalesce into the visible picker via `add(_:)`.
    @Published public private(set) var urls: [URL]
    /// Browsers shown, in display order. Never empty — the caller
    /// short-circuits before building a model otherwise.
    public let browsers: [Browser]
    /// Row index of the Selby-default browser; marked with ↩ in the UI.
    public let defaultIndex: Int
    /// Currently highlighted row. Starts at `defaultIndex` so a bare Enter
    /// means "open the default browser".
    @Published public var selection: Int
    /// Completion callback with the invocation's outcome.
    /// Fires exactly once (guarded by `finished`).
    public var onFinish: ((PickerOutcome) -> Void)?

    /// Set once an outcome has fired. Guards against double-fire — e.g.
    /// `resignKey` arriving after Enter already chose a browser.
    private var finished = false

    /// Where the mouse was when the picker was invoked. Hover-selection stays
    /// disarmed until the pointer has moved away from here, so a panel that
    /// appears under a stationary cursor (bottom-of-screen clamping can park a
    /// browser row under the pointer) cannot steal the selection from the
    /// default row before Enter is pressed.
    private let initialMouseLocation = NSEvent.mouseLocation
    /// Latches true once the pointer has moved far enough; hover is then live
    /// for the rest of the invocation.
    private var hoverArmed = false

    public init(urls: [URL], browsers: [Browser], defaultIndex: Int) {
        self.urls = urls
        self.browsers = browsers
        self.defaultIndex = defaultIndex
        self.selection = defaultIndex
    }

    /// Coalesces a link burst: URLs arriving while the picker is up join this
    /// invocation instead of replacing it (which would silently drop links).
    /// Ignored once finished.
    public func add(_ newURLs: [URL]) {
        guard !finished else { return }
        urls.append(contentsOf: newURLs)
    }

    /// Whether hover events should move the selection yet. True once the
    /// pointer has moved ≳4pt from where the picker was invoked.
    /// Not unit-tested (depends on live `NSEvent.mouseLocation`); covered by
    /// SMOKE-TEST.md §5-6.
    public func shouldHonorHover() -> Bool {
        if hoverArmed { return true }
        let current = NSEvent.mouseLocation
        let distance = hypot(current.x - initialMouseLocation.x,
                             current.y - initialMouseLocation.y)
        if distance > 4 {
            hoverArmed = true
        }
        return hoverArmed
    }

    /// Routes a key event through `PickerLogic`. Returns `true` when consumed,
    /// so the panel can pass ignored keys up the responder chain.
    public func handleKey(_ event: NSEvent) -> Bool {
        guard let key = PickerKey(event: event),
              let action = PickerLogic.action(for: key, selection: selection, count: browsers.count)
        else { return false }
        switch action {
        case .choose(let index):
            choose(index)
        case .dismiss:
            cancel(.dismissed)
        case .moveSelection(let index):
            selection = index
        }
        return true
    }

    /// Accepts the row at `index`; ignored when out of range or already finished.
    public func choose(_ index: Int) {
        guard !finished, browsers.indices.contains(index) else { return }
        finished = true
        onFinish?(.chose(browsers[index]))
    }

    /// Dismisses without opening anything; ignored when already finished.
    public func cancel(_ reason: PickerCancelReason) {
        guard !finished else { return }
        finished = true
        onFinish?(.cancelled(reason))
    }

    /// Closes the picker and asks for the Settings window (the gear button);
    /// ignored when already finished.
    public func requestSettings() {
        guard !finished else { return }
        finished = true
        onFinish?(.openSettings)
    }
}
