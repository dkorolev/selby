// AppKit regression checks against the real panel: `swift run selby2-ui-tests`.
// Needs a GUI session. Opens no browser and registers nothing.
import AppKit
import Selby2Core
import Selby2Kit
import Selby2TestSupport

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

@MainActor
func withPicker(_ body: (PickerPanel, PickerModel, () -> [PickerOutcome]) -> Void) {
    let browser = Browser(bundleID: "test", name: "Test", url: URL(fileURLWithPath: "/Test.app"))
    let session = PickerSession(urls: [URL(fileURLWithPath: "/dev/null")], browsers: [browser])
    let model = PickerModel(session: session, mouseLocation: .zero)
    var outcomes: [PickerOutcome] = []
    model.onFinish = { outcomes.append($0) }
    let panel = PickerPanel(model: model, maxListHeight: 300)
    panel.monitorOutsideClicks()
    defer {
        panel.stopMonitoringClicks()
        panel.close()
    }
    body(panel, model, { outcomes })
}

@MainActor
func mouseDown(timestamp: TimeInterval, windowNumber: Int = 0) -> NSEvent {
    guard let event = NSEvent.mouseEvent(
        with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: timestamp,
        windowNumber: windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1
    ) else { fatalError("could not synthesize a mouse event") }
    return event
}

@MainActor
func keyDown(keyCode: UInt16, characters: String) -> NSEvent {
    guard let event = NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
        characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode
    ) else { fatalError("could not synthesize a key event") }
    return event
}

let now = { ProcessInfo.processInfo.systemUptime }

withPicker { panel, model, outcomes in
    panel.resignKey()
    Harness.check(outcomes().isEmpty, "focus loss does not discard the pending link")
    model.choose(0)
    Harness.check(outcomes(), equals: [.chose(model.browsers[0])], "the link stays selectable after focus loss")
}
withPicker { panel, model, outcomes in
    panel.handleMouseDown(mouseDown(timestamp: 0), local: false)
    Harness.check(outcomes().isEmpty, "a delayed copy of the initiating click cannot cancel the picker")
    model.choose(0)
    Harness.check(outcomes(), equals: [.chose(model.browsers[0])], "the link survives the delayed click")
}
withPicker { panel, _, outcomes in
    panel.handleMouseDown(mouseDown(timestamp: now() + 1), local: false)
    Harness.check(outcomes(), equals: [.cancelled(.outsideClick)], "a later click in another app dismisses")
}
withPicker { panel, _, outcomes in
    let event = mouseDown(timestamp: now() + 1, windowNumber: panel.windowNumber)
    Harness.check(event.window === panel, "the synthesized event targets the panel")
    panel.handleMouseDown(event, local: true)
    Harness.check(outcomes().isEmpty, "a click inside the panel does not cancel")
}
withPicker { panel, _, outcomes in
    panel.handleMouseDown(mouseDown(timestamp: now() + 1), local: true)
    Harness.check(outcomes(), equals: [.cancelled(.outsideClick)], "a click in another Selby2 window dismisses")
}
withPicker { panel, _, outcomes in
    panel.cancelOperation(nil)
    panel.resignKey()
    panel.keyDown(with: keyDown(keyCode: 53, characters: "\u{1b}"))
    Harness.check(outcomes(), equals: [.cancelled(.dismissed)], "Escape dismisses exactly once")
}
withPicker { panel, model, outcomes in
    panel.keyDown(with: keyDown(keyCode: 36, characters: "\r"))
    Harness.check(outcomes(), equals: [.chose(model.browsers[0])], "Return through the panel chooses the default row")
}
withPicker { panel, _, _ in
    panel.place(near: CGPoint(x: 500, y: 500), within: CGRect(x: 0, y: 0, width: 2000, height: 2000))
    let frame = panel.frame
    Harness.check(frame.width >= 230 && frame.height > 40, "the panel sizes itself to its content")
    Harness.check(frame.maxY <= 500 + PickerPlacement.cursorOffset + 0.5, "the panel's top edge sits at the pointer")
}
withPicker { _, model, outcomes in
    model.hover(0)
    Harness.check(model.selection == 0 && outcomes().isEmpty, "hover never produces an outcome")
}

Harness.finish()
