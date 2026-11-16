import Foundation

/// Drops a URL that was just delivered again.
///
/// A click in some apps arrives twice, tens of milliseconds apart: the app
/// opens it through Launch Services, and `/usr/bin/open` opens it too. Both
/// reach `application(_:open:)` before a browser is chosen, and the picker
/// would open the page twice. A repeat inside the window is that second
/// copy. A different link, or the same link after the window, is a new open.
public struct RecentDeliveries: Equatable, Sendable {
    /// The two copies of one click arrived 20–60 ms apart.
    public let window: TimeInterval
    private var seen: [Delivery] = []

    public init(window: TimeInterval = 0.15) {
        self.window = window
    }

    /// The URLs from this delivery that were not just received.
    public mutating func fresh(_ urls: [URL], at now: Date) -> [URL] {
        seen.removeAll { now.timeIntervalSince($0.at) >= window || now < $0.at }
        var kept: [URL] = []
        for url in urls {
            let key = url.absoluteString
            if seen.contains(where: { $0.url == key }) { continue }
            seen.append(Delivery(url: key, at: now))
            kept.append(url)
        }
        return kept
    }

    private struct Delivery: Equatable, Sendable {
        var url: String
        var at: Date
    }
}
