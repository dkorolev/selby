import Foundation

/// Applies the user's manual browser ordering to a discovery result.
public enum BrowserOrdering {
    /// Returns `browsers` arranged by `order` (a list of bundle IDs from
    /// Settings drag-reordering). Browsers not mentioned in `order` — newly
    /// installed ones, or all of them before the user ever re-arranges —
    /// keep their incoming (alphabetical) order and go after the ordered
    /// ones. IDs in `order` with no matching browser (uninstalled) are
    /// skipped, not remembered forever.
    public static func apply(order: [String], to browsers: [Browser]) -> [Browser] {
        var remaining = browsers
        var arranged: [Browser] = []
        for id in order {
            guard let index = remaining.firstIndex(where: { $0.id == id }) else { continue }
            arranged.append(remaining.remove(at: index))
        }
        return arranged + remaining
    }
}
