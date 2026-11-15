import AppKit
import Selby2Core
import SwiftUI
import os

/// A Spotlight-style floating panel: borderless, non-activating, takes
/// keyboard focus while the previously frontmost app stays active.
///
/// Dismissal is explicit: Escape, a click outside the panel, a choice, or
/// the gear. Losing key status is not a dismissal; app activation shuffles
/// focus around, and a pending link must survive that.
public final class PickerPanel: NSPanel {
    private let model: PickerModel
    private let log = Logger(subsystem: "dev.selby.Selby", category: "picker")
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var presentedAt: TimeInterval = 0

    public init(model: PickerModel, maxListHeight: CGFloat) {
        self.model = model
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        // Over full-screen apps, on whichever Space the click happened.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        // The controller orders the panel out and drops it; auto-release on
        // close would leave a dangling reference.
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow

        let host = NSHostingController(rootView: BrowserPickerView(model: model, maxListHeight: maxListHeight))
        host.sizingOptions = [.preferredContentSize]
        contentViewController = host
    }

    // Borderless windows refuse key status unless this is overridden.
    override public var canBecomeKey: Bool { true }

    override public func keyDown(with event: NSEvent) {
        if !model.handleKey(event) {
            super.keyDown(with: event)
        }
    }

    // Escape also arrives here via the responder chain; the session's
    // single-outcome guard makes the double call harmless.
    override public func cancelOperation(_ sender: Any?) {
        model.cancel(.dismissed)
    }

    override public func resignKey() {
        super.resignKey()
        log.debug("Picker lost key status; keeping pending links")
    }

    /// Sizes the panel to its content and places it near the pointer.
    public func place(near mouse: CGPoint, within visible: CGRect) {
        contentView?.layoutSubtreeIfNeeded()
        let size = contentView?.fittingSize ?? CGSize(width: 260, height: 200)
        setContentSize(size)
        setFrameOrigin(PickerPlacement.origin(panelSize: size, mouse: mouse, visible: visible))
    }

    /// Starts watching for clicks outside the panel. Event timestamps and
    /// `systemUptime` share a clock, so a delayed copy of the click that
    /// opened the picker cannot also dismiss it.
    public func monitorOutsideClicks() {
        stopMonitoringClicks()
        presentedAt = ProcessInfo.processInfo.systemUptime
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        // AppKit invokes both monitors on the main thread; handle the click
        // synchronously so cancellation cannot land after the next URL does.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.handleMouseDown(event, local: false) }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.handleMouseDown(event, local: true) }
            return event
        }
    }

    public func handleMouseDown(_ event: NSEvent, local: Bool) {
        guard event.timestamp > presentedAt else { return }
        guard !local || event.window !== self else { return }
        model.cancel(.outsideClick)
    }

    public func stopMonitoringClicks() {
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        globalMouseMonitor = nil
        localMouseMonitor = nil
    }
}
