import Foundation

/// A key press the picker understands. Decoded from key code and typed
/// characters so the logic stays free of AppKit event objects.
public enum PickerKey: Equatable, Sendable {
    /// Return or keypad Enter: accept the selected row.
    case accept
    /// Escape: dismiss without opening anything.
    case cancel
    case copyURLs
    case down
    case up
    /// Digit 1–9: open that row directly.
    case digit(Int)

    /// Physical digit-row and keypad key codes. Matched by position, not
    /// typed character, so the advertised 1–9 badges work on layouts where
    /// the unshifted digit row types punctuation (French AZERTY).
    private static let digitKeyCodes: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9,
        83: 1, 84: 2, 85: 3, 86: 4, 87: 5, 88: 6, 89: 7, 91: 8, 92: 9,
    ]

    public static func digit(forKeyCode keyCode: UInt16) -> Int? {
        digitKeyCodes[keyCode]
    }

    /// Returns `nil` for keys the picker ignores.
    public init?(keyCode: UInt16, characters: String?) {
        switch keyCode {
        case 36, 76: self = .accept
        case 53: self = .cancel
        case 125: self = .down
        case 126: self = .up
        default:
            if let digit = Self.digit(forKeyCode: keyCode) {
                self = .digit(digit)
            } else if let characters, let digit = Int(characters), (1...9).contains(digit) {
                self = .digit(digit)
            } else if characters?.lowercased() == "c" {
                self = .copyURLs
            } else {
                return nil
            }
        }
    }
}

/// The picker's reaction to a key press.
public enum PickerAction: Equatable, Sendable {
    case choose(index: Int)
    case dismiss
    case copyURLs
    case moveSelection(to: Int)
}

/// Pure keyboard rules: given a key, the selection, and the row count,
/// decide what happens.
public enum PickerLogic {
    /// `nil` when the key should be ignored (a digit beyond the last row).
    public static func action(for key: PickerKey, selection: Int, count: Int) -> PickerAction? {
        guard count > 0 else { return .dismiss }
        switch key {
        case .accept:
            return .choose(index: selection)
        case .copyURLs:
            return .copyURLs
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
