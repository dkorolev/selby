// Generates Resources/AppIcon.icns — the Selby app icon.
//
// Design: an Apple-template rounded square (the 824/1024 grid squircle) with
// an azure→indigo gradient and a white `arrow.triangle.branch` symbol: one
// incoming link, routed to one of several browsers.
//
// Usage: swift scripts/make-icon.swift   (run from the repo root)
// Tested by: not unit-tested — run it and look. `scripts/build.sh` fails if
// the output is missing, and SMOKE-TEST.md §1 checks the built app shows it.
import AppKit

/// iconutil's required iconset entries: filename stem and pixel size.
let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

/// Draws one icon rendition at the given pixel size.
func draw(pixels: Int) -> NSBitmapImageRep {
    // Force-unwrap is safe: these are fixed, valid bitmap parameters.
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    // Force-unwrap is safe: a context over a fresh RGBA bitmap always exists.
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)!

    let side = CGFloat(pixels)
    // Apple's icon grid: the squircle spans 824/1024 of the canvas, centered;
    // the margin is transparent so macOS renders it like every native icon.
    let inset = side * (100.0 / 1024.0)
    let rect = NSRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
    let squircle = NSBezierPath(
        roundedRect: rect,
        xRadius: rect.width * 0.2237, // Big Sur corner ratio
        yRadius: rect.width * 0.2237
    )

    let azure = NSColor(calibratedRed: 0.33, green: 0.64, blue: 1.00, alpha: 1)
    let indigo = NSColor(calibratedRed: 0.22, green: 0.27, blue: 0.86, alpha: 1)
    // Force-unwrap is safe: two valid colors always form a gradient.
    NSGradient(starting: azure, ending: indigo)!.draw(in: squircle, angle: -90)

    // The glyph: white branching arrow, ~58% of the squircle, centered.
    let config = NSImage.SymbolConfiguration(pointSize: side * 0.5, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let target = rect.width * 0.58
        let scale = min(target / symbol.size.width, target / symbol.size.height)
        let drawSize = NSSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
        symbol.draw(in: NSRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        ))
    } else {
        // Symbol lookup can only fail on ancient macOS; fall back to an "S".
        let font = NSFont.systemFont(ofSize: rect.width * 0.6, weight: .bold)
        let text = NSAttributedString(string: "S", attributes: [.font: font, .foregroundColor: NSColor.white])
        let textSize = text.size()
        text.draw(at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2))
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let fileManager = FileManager.default
let iconset = fileManager.temporaryDirectory.appendingPathComponent("Selby.iconset")
try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

for (name, pixels) in sizes {
    let rep = draw(pixels: pixels)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("error: PNG encoding failed for \(name)\n".utf8))
        exit(1)
    }
    try png.write(to: iconset.appendingPathComponent("\(name).png"))
    FileHandle.standardError.write(Data("rendered \(name).png\n".utf8))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("error: iconutil exited \(process.terminationStatus)\n".utf8))
    exit(1)
}
FileHandle.standardError.write(Data("wrote Resources/AppIcon.icns\n".utf8))
