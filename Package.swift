// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Selby",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure types and decision logic — no UI. Kept separate so the test
        // runner can exercise it without AppKit windows or an Xcode toolchain.
        .target(name: "SelbyCore", path: "Sources/SelbyCore"),
        // The menu-bar app itself.
        .executableTarget(name: "Selby", dependencies: ["SelbyCore"], path: "Sources/Selby"),
        // Plain-executable test runner (`swift run selby-tests`): the Command
        // Line Tools toolchain ships neither XCTest nor Swift Testing, so
        // tests are a dependency-free executable that exits non-zero on failure.
        .executableTarget(name: "selby-tests", dependencies: ["SelbyCore"], path: "Sources/SelbyTests"),
    ]
)
