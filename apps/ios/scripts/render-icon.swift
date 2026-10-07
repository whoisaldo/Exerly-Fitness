import AppKit

// Package the established Exerly pulse mark as an opaque 1024px app icon.
// The source artwork is preserved; this step only sizes it for the asset catalog.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let source = root.appendingPathComponent("Brand/ExerlyMark.png")
let output = CommandLine.arguments.dropFirst().first.map { URL(fileURLWithPath: $0) }
    ?? root.appendingPathComponent("Exerly/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
guard let input = NSImage(contentsOf: source),
      let image = input.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("Exerly brand artwork is missing")
}
let size = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: 0, space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.interpolationQuality = .high
context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
