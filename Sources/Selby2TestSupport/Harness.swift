import Foundation

/// Assertion helpers for the executable test runners. Prints one line per
/// check and exits non-zero from `finish()` if anything failed.
@MainActor
public enum Harness {
    private static var passes = 0
    private static var failures = 0

    public static func check(_ condition: Bool, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        if condition {
            passes += 1
            print("ok    \(name)")
        } else {
            failures += 1
            let path = "\(file)".split(separator: "/").last.map(String.init) ?? "\(file)"
            print("FAIL  \(name) (\(path):\(line))")
        }
    }

    public static func check<T: Equatable>(
        _ actual: T, equals expected: T, _ name: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        check(actual == expected, name, file: file, line: line)
        if actual != expected {
            print("      expected: \(expected)\n      actual:   \(actual)")
        }
    }

    public static func finish() -> Never {
        print("\n\(passes) passed, \(failures) failed")
        exit(failures == 0 ? 0 : 1)
    }
}
