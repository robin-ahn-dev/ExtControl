import AppKit

// Rendert das App-Icon in allen benötigten Größen nach Resources/AppIcon.iconset

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
}

let accent = color(0x4F46E5)
let gradient = NSGradient(colors: [color(0x6366F1), color(0x22D3EE)])!

func docPath(_ s: CGFloat) -> (NSBezierPath, NSBezierPath) {
    let w = 0.44 * s, h = 0.56 * s
    let x = (s - w) / 2, y = (s - h) / 2
    let r = 0.05 * s, f = 0.15 * s

    let p = NSBezierPath()
    p.move(to: NSPoint(x: x, y: y + r))
    p.appendArc(withCenter: NSPoint(x: x + r, y: y + r), radius: r, startAngle: 180, endAngle: 270)
    p.line(to: NSPoint(x: x + w - r, y: y))
    p.appendArc(withCenter: NSPoint(x: x + w - r, y: y + r), radius: r, startAngle: 270, endAngle: 360)
    p.line(to: NSPoint(x: x + w, y: y + h - f))          // Kante bis Faltung
    p.line(to: NSPoint(x: x + w - f, y: y + h))          // Faltungs-Schräge
    p.line(to: NSPoint(x: x + r, y: y + h))
    p.appendArc(withCenter: NSPoint(x: x + r, y: y + h - r), radius: r, startAngle: 90, endAngle: 180)
    p.close()

    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: x + w - f, y: y + h))
    fold.line(to: NSPoint(x: x + w - f, y: y + h - f))
    fold.line(to: NSPoint(x: x + w, y: y + h - f))
    fold.close()

    return (p, fold)
}

func slider(_ s: CGFloat, y: CGFloat, width: CGFloat, knobAt: CGFloat) {
    let barH = 0.030 * s
    let x = (s - width) / 2
    let bar = NSBezierPath(roundedRect: NSRect(x: x, y: y - barH / 2, width: width, height: barH),
                           xRadius: barH / 2, yRadius: barH / 2)
    accent.withAlphaComponent(0.30).setFill()
    bar.fill()

    let kr = 0.042 * s
    let kx = x + width * knobAt
    let knob = NSBezierPath(ovalIn: NSRect(x: kx - kr, y: y - kr, width: kr * 2, height: kr * 2))
    accent.setFill()
    knob.fill()
}

func render(size s: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocusFlipped(false)
    NSGraphicsContext.current?.imageInterpolation = .high

    let inset = 0.085 * s
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = 0.2237 * rect.width
    let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    bg.addClip()
    gradient.draw(in: rect, angle: -55)
    NSGraphicsContext.restoreGraphicsState()

    let (doc, fold) = docPath(s)
    NSColor.white.setFill()
    doc.fill()
    NSColor.white.withAlphaComponent(0.55).setFill()
    fold.fill()

    slider(s, y: s * 0.455, width: 0.26 * s, knobAt: 0.72)
    slider(s, y: s * 0.575, width: 0.26 * s, knobAt: 0.28)

    image.unlockFocus()
    return image
}

func png(_ image: NSImage, _ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.iconset")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

for (base, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
                      (256, 1), (256, 2), (512, 1), (512, 2)] {
    let pixels = base * scale
    let data = png(render(size: CGFloat(pixels)), pixels)
    let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
    try data.write(to: out.appendingPathComponent(name))
}
print("iconset: \(out.path)")
