import AppKit
import Foundation
let target = URL(fileURLWithPath: CommandLine.arguments[1])
for (name, emoji) in [("party", "🎉"), ("confetti", "🎊"), ("gift", "🎁")] {
    let size = 256
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill(using: .copy)
    let text = NSAttributedString(string: emoji, attributes: [.font: NSFont(name: "AppleColorEmoji", size: 208)!])
    let bounds = text.size()
    text.draw(at: NSPoint(x: (CGFloat(size) - bounds.width) / 2, y: (CGFloat(size) - bounds.height) / 2 + 5))
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: target.appendingPathComponent(name + ".png"))
    print(name)
}
