import AppKit
import SelbyCore
import SwiftUI

/// A Spotlight-style floating panel: borderless, non-activating, able to take
/// keyboard focus while the previously frontmost app stays active. Dismisses
/// on Escape, on losing key status, or via `PickerModel` callbacks.
final class PickerPanel: NSPanel {
    private let model: PickerModel

    init(model: PickerModel, maxListHeight: CGFloat) {
        self.model = model
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        // Panels hide on app deactivation by default; we manage dismissal
        // ourselves via resignKey, so keep the panel visible.
        hidesOnDeactivate = false
        // Show over full-screen apps and on whichever Space the click happened.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        // We order the panel out manually; auto-release on close would leave a
        // dangling reference and crash on the second dismissal path.
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow

        let host = NSHostingController(
            rootView: BrowserPickerView(model: model, maxListHeight: maxListHeight)
        )
        host.sizingOptions = [.preferredContentSize]
        contentViewController = host
    }

    // Borderless windows refuse key status unless this is overridden; the
    // picker is keyboard-driven, so it must become key.
    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if !model.handleKey(event) {
            super.keyDown(with: event)
        }
    }

    // Escape arrives here (via the responder chain) as well as through
    // keyDown; PickerModel's `finished` guard makes the double call harmless.
    override func cancelOperation(_ sender: Any?) {
        model.cancel(.dismissed)
    }

    // Losing key status means the user clicked elsewhere — cancel, but flag it
    // as an outside click so a link click's URL can reclaim these URLs.
    override func resignKey() {
        super.resignKey()
        model.cancel(.outsideClick)
    }
}
