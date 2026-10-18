// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Selby2",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure model and decision logic. Foundation only, no AppKit, so every
        // rule the picker follows is testable without a window server.
        .target(name: "Selby2Core"),
        // Everything that needs AppKit or SwiftUI: the panel, the views, the
        // settings store, and browser discovery. A library so the UI test
        // harness can link it like any other target.
        .target(name: "Selby2Kit", dependencies: ["Selby2Core"]),
        // Minimal assertion helpers shared by the executable test runners.
        .target(name: "Selby2TestSupport"),
        // `swift run selby2-tests`: unit tests for Selby2Core. A plain
        // executable because the Command Line Tools ship no usable test
        // framework (XCTest is absent; Swift Testing is missing a dylib).
        .executableTarget(
            name: "selby2-tests",
            dependencies: ["Selby2Core", "Selby2TestSupport"],
            path: "Sources/Selby2Tests"
        ),
        // `swift run selby2-ui-tests`: drives the real panel (focus loss,
        // outside clicks, Escape) without launching or registering the app.
        .executableTarget(
            name: "selby2-ui-tests",
            dependencies: ["Selby2Kit", "Selby2TestSupport"],
            path: "Sources/Selby2UITests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
