// Stitches captured PNG frames into an animated GIF and an H.264 MP4.
// Pure ImageIO/AVFoundation; no dependencies beyond the OS.
// Stitches capture-demo frames into demo.gif + demo.mp4 (AVFoundation; no deps).
// Usage: swift stitch-frames.swift <frames-dir> <out.gif> <out.mp4>
import Foundation
import ImageIO
import AVFoundation
import CoreGraphics
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 4 else {
    fatalError("Usage: stitch-frames <frames-dir> <out.gif> <out.mp4> [frame-seconds]")
}
let framesDir = args[1]
let gifURL = URL(fileURLWithPath: args[2])
let mp4URL = URL(fileURLWithPath: args[3])
let frameSeconds = args.count >= 5 ? Double(args[4]) ?? 1.1 : 1.1
let maxWidth: CGFloat = 960

let framePaths = (try FileManager.default.contentsOfDirectory(atPath: framesDir))
    .filter { $0.hasSuffix(".png") }.sorted().map { framesDir + "/" + $0 }
guard !framePaths.isEmpty else { fatalError("No PNG frames in \(framesDir)") }

func loadScaled(_ path: String) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    let scale = min(1, maxWidth / CGFloat(image.width))
    guard scale < 1 else { return image }
    let size = CGSize(width: floor(CGFloat(image.width) * scale), height: floor(CGFloat(image.height) * scale))
    guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                  bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(origin: .zero, size: size))
    return context.makeImage() ?? image
}

let frames = framePaths.compactMap(loadScaled)
guard !frames.isEmpty else { fatalError("No decodable frames") }

// ---- GIF
guard let destination = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
    fatalError("GIF destination unavailable")
}
CGImageDestinationSetProperties(destination, [
    kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
] as CFDictionary)
for image in frames {
    CGImageDestinationAddImage(destination, image, [
        kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFUnclampedDelayTime: frameSeconds]
    ] as CFDictionary)
}
guard CGImageDestinationFinalize(destination) else { fatalError("GIF finalize failed") }
print("GIF: \(gifURL.path) (\(frames.count) frames)")

// ---- MP4
let size = CGSize(width: frames[0].width, height: frames[0].height)
try? FileManager.default.removeItem(at: mp4URL)
let writer = try AVAssetWriter(outputURL: mp4URL, fileType: .mp4)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: Int(size.width),
    AVVideoHeightKey: Int(size.height)
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: Int(size.width),
    kCVPixelBufferHeightKey as String: Int(size.height)
])
writer.add(input)
guard writer.startWriting() else { fatalError("AssetWriter failed: \(writer.error?.localizedDescription ?? "unknown")") }
writer.startSession(atSourceTime: .zero)

func pixelBuffer(_ image: CGImage) -> CVPixelBuffer? {
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, nil, &buffer)
    guard let buffer else { return nil }
    CVPixelBufferLockBaseAddress(buffer, [])
    if let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Int(size.width), height: Int(size.height),
                               bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                               space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) {
        context.draw(image, in: CGRect(origin: .zero, size: size))
    }
    CVPixelBufferUnlockBaseAddress(buffer, [])
    return buffer
}

let sema = DispatchSemaphore(value: 0)
var index = 0
let timescale: CMTimeScale = 600
input.requestMediaDataWhenReady(on: DispatchQueue(label: "stitch")) {
    while input.isReadyForMoreMediaData {
        guard index < frames.count else { input.markAsFinished(); sema.signal(); return }
        if let buffer = pixelBuffer(frames[index]) {
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(Double(index) * frameSeconds * Double(timescale)), timescale: timescale))
        }
        index += 1
    }
}
sema.wait()
writer.finishWriting {
    print("MP4: \(mp4URL.path) status=\(writer.status.rawValue)")
    sema.signal()
}
sema.wait()
