import AppKit

guard CommandLine.arguments.count == 3,
      let logo = NSImage(contentsOfFile: CommandLine.arguments[1]),
      let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1_024, pixelsHigh: 1_024,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Muse logo input and icon output paths are required") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let tile = NSBezierPath(roundedRect: NSRect(x: 42, y: 42, width: 940, height: 940), xRadius: 210, yRadius: 210)
NSColor(srgbRed: 17.0 / 255, green: 17.0 / 255, blue: 18.0 / 255, alpha: 1).setFill()
tile.fill()
context.imageInterpolation = .high
logo.draw(in: NSRect(x: 180, y: 180, width: 664, height: 664))
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Could not encode app icon") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
// A PNG-backed 1024 px ICNS entry avoids relying on iconutil's conversion
// service, which is unavailable in the restricted build environment.
func bigEndian(_ value: UInt32) -> Data {
    Data([UInt8((value >> 24) & 255), UInt8((value >> 16) & 255), UInt8((value >> 8) & 255), UInt8(value & 255)])
}
var icon = Data("icns".utf8)
icon.append(bigEndian(UInt32(png.count + 16)))
icon.append(Data("ic10".utf8))
icon.append(bigEndian(UInt32(png.count + 8)))
icon.append(png)
try icon.write(to: URL(fileURLWithPath: CommandLine.arguments[2]).deletingPathExtension().appendingPathExtension("icns"))
