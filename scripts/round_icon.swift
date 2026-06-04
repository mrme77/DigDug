import AppKit

// Turns a source image into a 1024×1024 macOS-style app icon: scales it into a
// centered square with transparent margin, clipped to a rounded-rect mask that
// approximates the standard macOS icon shape.
//
// Usage: swift round_icon.swift <source.png> <output.png>

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: round_icon.swift <source.png> <output.png>\n".utf8))
    exit(2)
}

let sourcePath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

guard let source = NSImage(contentsOfFile: sourcePath) else {
    FileHandle.standardError.write(Data("could not read \(sourcePath)\n".utf8))
    exit(1)
}

let side: CGFloat = 1024
let margin: CGFloat = 100                       // transparent padding around the tile
let contentSide = side - margin * 2             // 824, matches the macOS icon grid
let cornerRadius = contentSide * 0.2237         // macOS-style continuous-ish corner

let canvas = NSImage(size: NSSize(width: side, height: side))
canvas.lockFocus()

// Transparent background.
NSColor.clear.set()
NSRect(x: 0, y: 0, width: side, height: side).fill()

// Clip to the rounded tile, then draw the source scaled to fill it.
let contentRect = NSRect(x: margin, y: margin, width: contentSide, height: contentSide)
let mask = NSBezierPath(roundedRect: contentRect, xRadius: cornerRadius, yRadius: cornerRadius)
mask.addClip()
source.draw(in: contentRect, from: .zero, operation: .sourceOver, fraction: 1.0)

canvas.unlockFocus()

guard
    let tiff = canvas.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("failed to render rounded icon\n".utf8))
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
} catch {
    FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
    exit(1)
}
