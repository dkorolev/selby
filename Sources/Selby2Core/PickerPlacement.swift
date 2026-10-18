import CoreGraphics
import Foundation

/// Where the picker goes, as pure geometry over screen rectangles.
/// Coordinates are AppKit's: origin bottom-left, y grows upward.
public enum PickerPlacement {
    /// Margin kept between the panel and the screen's visible edge.
    public static let margin: CGFloat = 8
    /// Offset so the pointer rests on the hover-free URL header rather than
    /// exactly on a browser row.
    public static let cursorOffset: CGFloat = 12

    /// The frame containing `point`, with edges inclusive: a cursor pinned
    /// at the top of a screen reports y == maxY. Falls back to the nearest
    /// frame rather than the main screen, which is the wrong monitor for
    /// clicks on a secondary display.
    public static func frame(containing point: CGPoint, among frames: [CGRect]) -> CGRect? {
        if let hit = frames.first(where: { contains($0, point) }) { return hit }
        return frames.min { distanceSquared(from: $0, to: point) < distanceSquared(from: $1, to: point) }
    }

    /// The panel's origin: top-left corner at the pointer, like a context
    /// menu, clamped into `visible`. Near the bottom edge the panel flips
    /// above the pointer, because clamping upward would slide a browser row
    /// under the stationary cursor.
    public static func origin(panelSize size: CGSize, mouse: CGPoint, visible: CGRect) -> CGPoint {
        var origin = CGPoint(x: mouse.x - cursorOffset, y: mouse.y - size.height + cursorOffset)
        let wouldClampUp = origin.y < visible.minY + margin
        let fitsAbove = mouse.y + cursorOffset + size.height <= visible.maxY - margin
        if wouldClampUp, fitsAbove {
            origin.y = mouse.y + cursorOffset
        }
        origin.x = min(max(origin.x, visible.minX + margin), visible.maxX - size.width - margin)
        origin.y = min(max(origin.y, visible.minY + margin), visible.maxY - size.height - margin)
        return origin
    }

    /// The tallest the browser list may be on a screen of this visible
    /// height, leaving room for header, footer, and margins.
    public static func maxListHeight(visibleHeight: CGFloat) -> CGFloat {
        max(150, visibleHeight - 80)
    }

    private static func contains(_ rect: CGRect, _ point: CGPoint) -> Bool {
        point.x >= rect.minX && point.x <= rect.maxX && point.y >= rect.minY && point.y <= rect.maxY
    }

    private static func distanceSquared(from rect: CGRect, to point: CGPoint) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }
}
