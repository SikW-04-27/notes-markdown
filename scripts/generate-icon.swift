import AppKit
import Foundation

// Original, reproducible app artwork. No external images or font assets.
let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let resources = project.appendingPathComponent("Resources", isDirectory: true)
let iconset = project.appendingPathComponent(".build/AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "AppIcon", code: 1)
    }
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.shouldAntialias = true
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: pixels, height: pixels).fill()
    let scale = NSAffineTransform()
    scale.scale(by: CGFloat(pixels) / 1024)
    scale.concat()

    let tile = NSBezierPath(roundedRect: NSRect(x: 96, y: 96, width: 832, height: 832), xRadius: 184, yRadius: 184)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    NSColor(srgbRed: 0.98, green: 0.97, blue: 0.94, alpha: 1).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    NSGradient(starting: NSColor(srgbRed: 1, green: 0.83, blue: 0.32, alpha: 1),
               ending: NSColor(srgbRed: 1, green: 0.61, blue: 0.13, alpha: 1))!
        .draw(in: NSRect(x: 96, y: 706, width: 832, height: 222), angle: -90)
    NSColor(srgbRed: 0.76, green: 0.43, blue: 0.04, alpha: 0.2).setStroke()
    let divider = NSBezierPath()
    divider.move(to: NSPoint(x: 96, y: 706))
    divider.line(to: NSPoint(x: 928, y: 706))
    divider.lineWidth = 4
    divider.stroke()
    NSGraphicsContext.restoreGraphicsState()

    // M + a downward arrow express Markdown without copying an existing logo.
    NSColor(srgbRed: 0.17, green: 0.19, blue: 0.22, alpha: 1).setStroke()
    let letter = NSBezierPath()
    letter.move(to: NSPoint(x: 252, y: 358))
    letter.line(to: NSPoint(x: 252, y: 574))
    letter.line(to: NSPoint(x: 366, y: 444))
    letter.line(to: NSPoint(x: 480, y: 574))
    letter.line(to: NSPoint(x: 480, y: 358))
    letter.lineWidth = 58
    letter.lineJoinStyle = .round
    letter.lineCapStyle = .round
    letter.stroke()
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 668, y: 574))
    arrow.line(to: NSPoint(x: 668, y: 382))
    arrow.move(to: NSPoint(x: 586, y: 430))
    arrow.line(to: NSPoint(x: 668, y: 348))
    arrow.line(to: NSPoint(x: 750, y: 430))
    arrow.lineWidth = 58
    arrow.lineJoinStyle = .round
    arrow.lineCapStyle = .round
    arrow.stroke()

    if pixels >= 64 {
        NSColor(srgbRed: 0.72, green: 0.72, blue: 0.68, alpha: 0.45).setStroke()
        let rule = NSBezierPath()
        rule.move(to: NSPoint(x: 246, y: 250))
        rule.line(to: NSPoint(x: 774, y: 250))
        rule.lineWidth = 12
        rule.lineCapStyle = .round
        rule.stroke()
    }
    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "AppIcon", code: 2) }
    return png
}

for size in [16, 32, 128, 256, 512] {
    try render(pixels: size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(pixels: size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(pixels: 1024).write(to: resources.appendingPathComponent("AppIcon.png"))
try render(pixels: 256).write(to: resources.appendingPathComponent("AppIcon-preview.png"))
print("Generated icon artwork and iconset")
