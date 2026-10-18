import AppKit
import Combine
import Selby2Core

/// Observable wrapper around one `PickerSession`. Fires `onFinish` exactly
/// once, when the session reaches its outcome.
@MainActor
public final class PickerModel: ObservableObject {
    @Published public private(set) var session: PickerSession
    private var hoverGate: HoverGate
    public var onFinish: ((PickerOutcome) -> Void)?

    /// `mouseLocation` is where the pointer was when the picker was invoked;
    /// hover stays disarmed until it moves away from there.
    public init(session: PickerSession, mouseLocation: CGPoint) {
        self.session = session
        hoverGate = HoverGate(origin: mouseLocation)
    }

    public var urls: [URL] { session.urls }
    public var browsers: [Browser] { session.browsers }
    public var defaultIndex: Int { session.defaultIndex }
    public var selection: Int { session.selection }
    public var isFinished: Bool { session.isFinished }

    public func add(_ urls: [URL]) {
        mutate { $0.add(urls) }
    }

    /// Returns whether the event was consumed.
    public func handleKey(_ event: NSEvent) -> Bool {
        guard let key = PickerKey(event: event) else { return false }
        var consumed = false
        mutate { consumed = $0.handle(key) }
        return consumed
    }

    /// Hover over `index`, honored only once the pointer has moved.
    public func hover(_ index: Int) {
        guard hoverGate.allowsHover(at: NSEvent.mouseLocation) else { return }
        mutate { $0.selection = index }
    }

    public func choose(_ index: Int) {
        mutate { $0.choose(index) }
    }

    public func cancel(_ reason: PickerCancelReason) {
        mutate { $0.cancel(reason) }
    }

    public func requestSettings() {
        mutate { $0.requestSettings() }
    }

    private func mutate(_ body: (inout PickerSession) -> Void) {
        let wasFinished = session.isFinished
        body(&session)
        if !wasFinished, let outcome = session.outcome {
            onFinish?(outcome)
        }
    }
}
