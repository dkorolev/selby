import Foundation

/// Everything the user can configure, as one value.
///
/// Visibility has two polarities on purpose: normal browsers are visible
/// unless listed in `hidden`, so a newly installed browser appears on its
/// own; private variants are hidden unless listed in `enabledPrivate`, so
/// they do not double every picker by default.
public struct Settings: Equatable, Sendable {
    /// Browser IDs in the user's drag order. Empty until the first drag.
    /// IDs of uninstalled browsers are tolerated and ignored.
    public var order: [String]
    /// Normal browsers the user switched off.
    public var hidden: Set<String>
    /// Private variants the user switched on.
    public var enabledPrivate: Set<String>

    public init(order: [String] = [], hidden: Set<String> = [], enabledPrivate: Set<String> = []) {
        self.order = order
        self.hidden = hidden
        self.enabledPrivate = enabledPrivate
    }

    public func isVisible(_ browser: Browser) -> Bool {
        browser.isPrivate ? enabledPrivate.contains(browser.id) : !hidden.contains(browser.id)
    }

    public mutating func setVisible(_ visible: Bool, _ browser: Browser) {
        if browser.isPrivate {
            if visible { enabledPrivate.insert(browser.id) } else { enabledPrivate.remove(browser.id) }
        } else {
            if visible { hidden.remove(browser.id) } else { hidden.insert(browser.id) }
        }
    }

    /// `browsers` in the user's order. Browsers absent from `order` keep
    /// their incoming (alphabetical) order after the ordered ones.
    public func arranged(_ browsers: [Browser]) -> [Browser] {
        var remaining = browsers
        var result: [Browser] = []
        for id in order {
            guard let index = remaining.firstIndex(where: { $0.id == id }) else { continue }
            result.append(remaining.remove(at: index))
        }
        return result + remaining
    }

    /// The picker's rows: arranged, then filtered by visibility.
    public func visible(_ browsers: [Browser]) -> [Browser] {
        arranged(browsers).filter(isVisible)
    }

    /// Applies a drag-reorder to an already-arranged list and records the
    /// resulting full order. Returns the moved list.
    public mutating func move(
        _ arranged: [Browser], fromOffsets source: IndexSet, toOffset destination: Int
    ) -> [Browser] {
        // Same semantics as SwiftUI's `onMove`: `destination` indexes the
        // list before removal. Implemented here so Core stays free of SwiftUI.
        let moving = source.map { arranged[$0] }
        var moved = arranged
        for index in source.sorted(by: >) { moved.remove(at: index) }
        let insertAt = destination - source.filter { $0 < destination }.count
        moved.insert(contentsOf: moving, at: insertAt)
        order = moved.map(\.id)
        return moved
    }
}

extension Settings: Codable {
    private enum CodingKeys: String, CodingKey {
        case order, hidden, enabledPrivate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        order = try container.decodeIfPresent([String].self, forKey: .order) ?? []
        hidden = Set(try container.decodeIfPresent([String].self, forKey: .hidden) ?? [])
        enabledPrivate = Set(try container.decodeIfPresent([String].self, forKey: .enabledPrivate) ?? [])
    }

    /// Sets are written sorted so the stored form is deterministic.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(order, forKey: .order)
        try container.encode(hidden.sorted(), forKey: .hidden)
        try container.encode(enabledPrivate.sorted(), forKey: .enabledPrivate)
    }
}
