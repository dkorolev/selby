import AppKit

/// A key press the picker understands, decoded from a raw `NSEvent`.
/// Typed so the decision logic below stays pure and testable without
/// constructing AppKit events.
public enum PickerKey: Equatable {
    /// Return or keypad Enter: accept the currently selected row.
    case accept
    /// Escape: dismiss the picker without opening anything.
    case cancel
    /// Arrow down: move selection down one row, wrapping.
    case down
    /// Arrow up: move selection up one row, wrapping.
    case up
    /// Digit 1–9: jump straight to that row and open it.
    case digit(Int)

    /// Physical digit-row (kVK_ANSI_1…9) and keypad key codes. Matched by
    /// key code — not just typed character — because on shifted-digit layouts
    /// (French/Belgian AZERTY) the unshifted digit row produces punctuation,
    /// which would make the advertised 1–9 badges dead keys.
    private static let digitKeyCodes: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9,
        83: 1, 84: 2, 85: 3, 86: 4, 87: 5, 88: 6, 89: 7, 91: 8, 92: 9,
    ]

    /// The digit a physical key represents, layout-independently.
    /// Exposed for the `selby-tests` runner.
    public static func digit(forKeyCode keyCode: UInt16) -> Int? {
        digitKeyCodes[keyCode]
    }

    /// Decodes an AppKit key event. Returns `nil` for keys the picker ignores.
    public init?(event: NSEvent) {
        switch event.keyCode {
        case 36, 76: self = .accept // Return, keypad Enter
        case 53: self = .cancel // Escape
        case 125: self = .down
        case 126: self = .up
        default:
            // Physical key position first (works on every layout), then the
            // typed character (covers layouts with digits on other keys).
            if let digit = Self.digit(forKeyCode: event.keyCode) {
                self = .digit(digit)
            } else if let characters = event.charactersIgnoringModifiers,
                      let digit = Int(characters),
                      (1...9).contains(digit) {
                self = .digit(digit)
            } else {
                return nil
            }
        }
    }
}

/// The picker's reaction to a key press.
public enum PickerAction: Equatable {
    /// Open the browser at this row and close the picker.
    case choose(index: Int)
    /// Close the picker without opening anything.
    case dismiss
    /// Highlight this row.
    case moveSelection(to: Int)
}

/// Pure decision logic for the picker: given a key, the current selection, and
/// the row count, decide what happens. Free of window/event state; covered by
/// the `selby-tests` runner.
public enum PickerLogic {
    /// Returns the action for a key press, or `nil` when the key should be
    /// ignored (e.g. a digit beyond the last row).
    public static func action(for key: PickerKey, selection: Int, count: Int) -> PickerAction? {
        // Defensive: a picker with no rows has nothing to select or open.
        guard count > 0 else { return .dismiss }
        switch key {
        case .accept:
            return .choose(index: selection)
        case .cancel:
            return .dismiss
        case .down:
            return .moveSelection(to: (selection + 1) % count)
        case .up:
            return .moveSelection(to: (selection - 1 + count) % count)
        case .digit(let digit):
            return digit <= count ? .choose(index: digit - 1) : nil
        }
    }
}
