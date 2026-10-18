import Foundation

/// URLs from a picker that an outside click cancelled.
///
/// When the user clicks a second link while the picker is up, the picker
/// sees the mouse-down first and cancels; the new link's URL arrives an
/// Apple-Event round trip later. Parking the cancelled URLs for a short
/// window lets that next invocation pick them up, so both links open rather
/// than only the last. A click that produces no URL (an ordinary click
/// elsewhere) lets the window lapse, and the URLs are forgotten.
public struct ReclaimableLinks: Equatable, Sendable {
    /// Measured cancel-to-URL gap for one link click is 100–300 ms.
    public let window: TimeInterval
    private var urls: [URL] = []
    private var parkedAt: Date?

    public init(window: TimeInterval = 0.5) {
        self.window = window
    }

    public mutating func park(_ urls: [URL], at now: Date) {
        self.urls = urls
        parkedAt = now
    }

    /// Returns the parked URLs if the window has not lapsed, and clears the
    /// buffer either way.
    public mutating func reclaim(at now: Date) -> [URL] {
        defer {
            urls = []
            parkedAt = nil
        }
        guard let parkedAt, now.timeIntervalSince(parkedAt) < window, now >= parkedAt else { return [] }
        return urls
    }
}
