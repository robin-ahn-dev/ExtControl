import AppKit

// Rendert den DMG-Hintergrund als Multi-Resolution-TIFF (1x + 2x).

let W: CGFloat = 620, H: CGFloat = 400
let leftIcon = NSPoint(x: 158, y: 212)     // Finder-Koordinaten (Ursprung oben links)
let rightIcon = NSPoint(x: 462, y: 212)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let indigo = color(0x6366F1)
let cyan = color(0x22D3EE)

func flip(_ p: NSPoint) -> NSPoint { NSPoint(x: p.x, y: H - p.y) }

func text(_ string: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, centerY: CGFloat) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attributed = NSAttributedString(string: string, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: style
    ])
    let height = attributed.size().height
    attributed.draw(in: NSRect(x: 0, y: H - centerY - height / 2, width: W, height: height + 4))
}

func slot(at point: NSPoint) {
    let center = flip(point)
    let w: CGFloat = 158, h: CGFloat = 184
    // Etwas nach unten versetzt, damit der Finder-Dateiname mit im Feld liegt
    let rect = NSRect(x: center.x - w / 2, y: center.y - h / 2 - 18, width: w, height: h)
    let path = NSBezierPath(roundedRect: rect, xRadius: 30, yRadius: 30)
    color(0xFFFFFF, 0.05).setFill()
    path.fill()
    color(0xFFFFFF, 0.12).setStroke()
    path.lineWidth = 1.5
    path.setLineDash([7, 7], count: 2, phase: 0)
    path.stroke()
}

func arrow() {
    let y = flip(NSPoint(x: 0, y: 212)).y
    let start: CGFloat = 252, end: CGFloat = 362
    let gradient = NSGradient(colors: [indigo, cyan])!
    let box = NSRect(x: start - 12, y: y - 24, width: end - start + 24, height: 48)

    let shaft = NSBezierPath(roundedRect: NSRect(x: start, y: y - 5, width: end - 26 - start, height: 10),
                             xRadius: 5, yRadius: 5)

    NSGraphicsContext.saveGraphicsState()
    shaft.addClip()
    gradient.draw(in: box, angle: 0)
    NSGraphicsContext.restoreGraphicsState()

    let head = NSBezierPath()
    head.move(to: NSPoint(x: end + 10, y: y))
    head.line(to: NSPoint(x: end - 26, y: y + 21))
    head.line(to: NSPoint(x: end - 26, y: y - 21))
    head.close()

    NSGraphicsContext.saveGraphicsState()
    head.addClip()
    gradient.draw(in: box, angle: 0)
    NSGraphicsContext.restoreGraphicsState()
}

func render(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    NSGradient(colors: [color(0x0B1020), color(0x171335)])!
        .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 250)

    for (point, tint) in [(leftIcon, indigo), (rightIcon, cyan)] {
        let c = flip(point)
        // Weicher Schein: viele Kreise mit geringer Deckkraft übereinander
        let steps = 70
        for i in 0..<steps {
            let r = 180 * (1 - CGFloat(i) / CGFloat(steps))
            tint.withAlphaComponent(0.0055).setFill()
            NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)).fill()
        }
    }

    slot(at: leftIcon)
    slot(at: rightIcon)
    arrow()

    text("ExtControl", size: 29, weight: .bold, color: .white, centerY: 46)
    text("Standard-Apps für Dateiendungen", size: 13, weight: .medium,
         color: .white, centerY: 74)
    text("App nach rechts in den Programme-Ordner ziehen", size: 12, weight: .semibold,
         color: .white, centerY: 358)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/dmg-background.tiff"
let reps = [render(scale: 1), render(scale: 2)]
let data = NSBitmapImageRep.representationOfImageReps(in: reps, using: .tiff, properties: [:])!
try data.write(to: URL(fileURLWithPath: out))
try reps[1].representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: (out as NSString).deletingPathExtension + "-preview.png"))
print("fertig: \(out)")
