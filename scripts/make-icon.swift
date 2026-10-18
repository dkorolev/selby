// Renders Resources/AppIcon.icns: an Apple-grid rounded square with an
// azure-to-indigo gradient and a white branching-arrow symbol (one link in,
// one of several browsers out).
//
// Usage, from the repo root: swift scripts/make-icon.swift
import AppKit

let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

func render(pixels: Int) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: rep) else { fail("could not create a \(pixels)px bitmap") }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }

    // Apple's icon grid: the squircle spans 824/1024 of the canvas.
    let side = CGFloat(pixels)
    let inset = side * (100.0 / 1024.0)
    let rect = NSRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
    let squircle = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.2237, yRadius: rect.width * 0.2237)
    let azure = NSColor(calibratedRed: 0.33, green: 0.64, blue: 1.00, alpha: 1)
    let indigo = NSColor(calibratedRed: 0.22, green: 0.27, blue: 0.86, alpha: 1)
    NSGradient(starting: azure, ending: indigo)?.draw(in: squircle, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: side * 0.5, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    guard let symbol = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)?
        .withSymbolConfiguration(config)
    else { fail("SF Symbol arrow.triangle.branch is unavailable") }
    let target = rect.width * 0.58
    let scale = min(target / symbol.size.width, target / symbol.size.height)
    let drawSize = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
    symbol.draw(in: NSRect(
        x: rect.midX - drawSize.width / 2, y: rect.midY - drawSize.height / 2,
        width: drawSize.width, height: drawSize.height
    ))
    return rep
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("Selby2-\(getpid()).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }
for (name, pixels) in sizes {
    guard let png = render(pixels: pixels).representation(using: .png, properties: [:]) else {
        fail("PNG encoding failed for \(name)")
    }
    try png.write(to: iconset.appendingPathComponent("\(name).png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fail("iconutil exited \(iconutil.terminationStatus)") }
FileHandle.standardError.write(Data("wrote Resources/AppIcon.icns\n".utf8))
