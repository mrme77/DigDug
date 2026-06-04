import AppKit

// Renders a 1024×1024 app icon: warm earthy gradient + white shovel glyph.
// Usage: swift scripts/generate_icon.swift <output.png>

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: generate_icon.swift <output.png>\n".utf8))
    exit(2)
}

let side: CGFloat = 1024
let size = NSSize(width: side, height: side)
let image = NSImage(size: size)

image.lockFocus()
let rect = NSRect(x: 0, y: 0, width: side, height: side)

// Rounded background with a warm dig-the-earth gradient.
let clip = NSBezierPath(roundedRect: rect, xRadius: 184, yRadius: 184)
clip.addClip()
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.96, green: 0.58, blue: 0.20, alpha: 1.0),
    NSColor(calibratedRed: 0.76, green: 0.31, blue: 0.09, alpha: 1.0)
])!
gradient.draw(in: rect, angle: -90)

// White shovel symbol, centered.
let config = NSImage.SymbolConfiguration(pointSize: 560, weight: .semibold)
let symbolName = NSImage(systemSymbolName: "shovel", accessibilityDescription: nil) != nil ? "shovel" : "hammer.fill"
if let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let glyph = NSImage(size: base.size)
    glyph.lockFocus()
    base.draw(in: NSRect(origin: .zero, size: base.size))
    NSColor.white.set()
    NSRect(origin: .zero, size: base.size).fill(using: .sourceAtop)
    glyph.unlockFocus()

    let origin = NSPoint(x: (side - base.size.width) / 2, y: (side - base.size.height) / 2)
    glyph.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 0.95)
}
image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("failed to render icon\n".utf8))
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
} catch {
    FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
    exit(1)
}
