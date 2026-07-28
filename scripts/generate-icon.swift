import AppKit

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift generate-icon.swift OUTPUT.png\n", stderr)
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let pixelSize = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelSize,
    pixelsHigh: pixelSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Unable to create bitmap canvas\n", stderr)
    exit(1)
}

let context = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
defer { NSGraphicsContext.restoreGraphicsState() }

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()

let tileRect = NSRect(x: 72, y: 72, width: 880, height: 880)
let tile = NSBezierPath(roundedRect: tileRect, xRadius: 210, yRadius: 210)
NSGraphicsContext.current?.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
shadow.shadowBlurRadius = 52
shadow.shadowOffset = NSSize(width: 0, height: -22)
shadow.set()

let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.18, alpha: 1),
    NSColor(calibratedRed: 0.20, green: 0.12, blue: 0.34, alpha: 1),
    NSColor(calibratedRed: 0.07, green: 0.25, blue: 0.34, alpha: 1)
])!
background.draw(in: tile, angle: -48)
NSGraphicsContext.current?.restoreGraphicsState()

NSGraphicsContext.current?.saveGraphicsState()
tile.addClip()

let glow = NSGradient(colors: [
    NSColor(calibratedRed: 0.48, green: 0.30, blue: 1.00, alpha: 0.52),
    NSColor(calibratedRed: 0.22, green: 0.86, blue: 0.78, alpha: 0)
])!
glow.draw(
    fromCenter: NSPoint(x: 300, y: 780),
    radius: 20,
    toCenter: NSPoint(x: 420, y: 620),
    radius: 650,
    options: [.drawsBeforeStartingLocation]
)
NSGraphicsContext.current?.restoreGraphicsState()

let ringRect = NSRect(x: 238, y: 238, width: 548, height: 548)
let baseRing = NSBezierPath()
baseRing.appendArc(
    withCenter: NSPoint(x: ringRect.midX, y: ringRect.midY),
    radius: ringRect.width / 2,
    startAngle: 0,
    endAngle: 360
)
baseRing.lineWidth = 92
baseRing.lineCapStyle = .round
NSColor.white.withAlphaComponent(0.12).setStroke()
baseRing.stroke()

func drawArc(start: CGFloat, end: CGFloat, color: NSColor) {
    let arc = NSBezierPath()
    arc.appendArc(
        withCenter: NSPoint(x: ringRect.midX, y: ringRect.midY),
        radius: ringRect.width / 2,
        startAngle: start,
        endAngle: end
    )
    arc.lineWidth = 92
    arc.lineCapStyle = .round
    color.setStroke()
    arc.stroke()
}

drawArc(
    start: 92,
    end: 224,
    color: NSColor(calibratedRed: 0.77, green: 0.61, blue: 1.00, alpha: 1)
)
drawArc(
    start: 230,
    end: 336,
    color: NSColor(calibratedRed: 0.31, green: 0.88, blue: 0.79, alpha: 1)
)
drawArc(
    start: 342,
    end: 442,
    color: NSColor(calibratedRed: 1.00, green: 0.67, blue: 0.42, alpha: 1)
)

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let label = "TW"
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 190, weight: .heavy),
    .foregroundColor: NSColor.white,
    .kern: -8,
    .paragraphStyle: paragraph
]
label.draw(
    in: NSRect(x: 290, y: 397, width: 444, height: 230),
    withAttributes: attributes
)

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to render app icon\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL, options: .atomic)
