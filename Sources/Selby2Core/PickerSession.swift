import Foundation

/// Why a picker went away without opening anything.
public enum PickerCancelReason: Equatable, Sendable {
    /// Escape.
    case dismissed
    /// A click outside the panel. It may be the mouse-down of the user's next
    /// link click, whose URL arrives moments later; see `ReclaimableLinks`.
    case outsideClick
}

/// How one picker invocation ended.
public enum PickerOutcome: Equatable, Sendable {
    case chose(Browser)
    case copyURLs
    case cancelled(PickerCancelReason)
    /// The gear button: close and show Settings instead.
    case openSettings
}

/// The state of one picker invocation, from first URL to outcome. A value
/// type with no callbacks: the UI layer observes `outcome` and reacts once.
public struct PickerSession: Equatable, Sendable {
    /// The URLs to open; a link burst arrives as several opens and they all
    /// join this session via `add(_:)`.
    public private(set) var urls: [URL]
    /// Rows in display order. Never empty: callers short-circuit otherwise.
    public let browsers: [Browser]
    /// The row Return opens; marked ↩ in the UI.
    public let defaultIndex: Int
    public var selection: Int
    /// Set exactly once; every later mutation is ignored.
    public private(set) var outcome: PickerOutcome?

    public var isFinished: Bool { outcome != nil }

    public init(urls: [URL], browsers: [Browser], defaultIndex: Int = 0) {
        self.urls = urls
        self.browsers = browsers
        self.defaultIndex = defaultIndex
        self.selection = defaultIndex
    }

    public mutating func add(_ newURLs: [URL]) {
        guard !isFinished else { return }
        urls.append(contentsOf: newURLs)
    }

    /// Routes a key through `PickerLogic`. Returns whether it was consumed,
    /// so the panel can pass ignored keys up the responder chain.
    @discardableResult
    public mutating func handle(_ key: PickerKey) -> Bool {
        guard !isFinished,
              let action = PickerLogic.action(for: key, selection: selection, count: browsers.count)
        else { return false }
        switch action {
        case .choose(let index): choose(index)
        case .copyURLs: finish(.copyURLs)
        case .dismiss: cancel(.dismissed)
        case .moveSelection(let index): selection = index
        }
        return true
    }

    /// Ignored when out of range.
    public mutating func choose(_ index: Int) {
        guard browsers.indices.contains(index) else { return }
        finish(.chose(browsers[index]))
    }

    public mutating func cancel(_ reason: PickerCancelReason) {
        finish(.cancelled(reason))
    }

    public mutating func requestSettings() {
        finish(.openSettings)
    }

    private mutating func finish(_ result: PickerOutcome) {
        guard !isFinished else { return }
        outcome = result
    }
}
