import CoreGraphics
import Foundation

/// Keeps hover from stealing the selection before the user moves the mouse.
///
/// Bottom-of-screen placement can park a browser row right under the
/// stationary pointer; without this gate that row would be hovered, and
/// Return would open it instead of the default. Hover is honored only once
/// the pointer has travelled `threshold` points from where the picker
/// appeared, and stays honored for the rest of the invocation.
public struct HoverGate: Equatable, Sendable {
    public let origin: CGPoint
    public let threshold: CGFloat
    private var armed = false

    public init(origin: CGPoint, threshold: CGFloat = 4) {
        self.origin = origin
        self.threshold = threshold
    }

    public mutating func allowsHover(at point: CGPoint) -> Bool {
        if armed { return true }
        let distance = hypot(point.x - origin.x, point.y - origin.y)
        if distance > threshold { armed = true }
        return armed
    }
}
