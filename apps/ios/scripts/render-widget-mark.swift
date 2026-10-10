import AppKit

// Cut the established Exerly pulse mark out of its white tile for widgets and
// Live Activities, which draw it on dark surfaces. Coverage comes from how far
// each pixel is from white, so the glyph's geometry and edges are unchanged.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let source = root.appendingPathComponent("Brand/ExerlyMark.png")
let output = CommandLine.arguments.dropFirst().first.map { URL(fileURLWithPath: $0) }
    ?? root.appendingPathComponent("ExerlyWidgets/Assets.xcassets/ExerlyPulse.imageset/ExerlyPulse.png")
guard let input = NSImage(contentsOf: source),
      let image = input.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("Exerly brand artwork is missing")
}
let width = image.width, height = image.height
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let rgba = CGImageAlphaInfo.premultipliedLast.rawValue
let reader = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                       space: colorSpace, bitmapInfo: rgba)!
reader.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
let pixels = reader.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)

// The mark's purple, from the middle of the E's spine.
let probe = (height / 2 * width + width * 37 / 100) * 4
let ink = (r: Double(pixels[probe]), g: Double(pixels[probe + 1]), b: Double(pixels[probe + 2]))
let depth = 255 - ink.g
var minX = width, minY = height, maxX = 0, maxY = 0
for y in 0..<height {
    for x in 0..<width {
        let i = (y * width + x) * 4
        let alpha = max(0, min(1, (255 - Double(pixels[i + 1])) / depth))
        pixels[i] = UInt8(ink.r * alpha)
        pixels[i + 1] = UInt8(ink.g * alpha)
        pixels[i + 2] = UInt8(ink.b * alpha)
        pixels[i + 3] = UInt8(255 * alpha)
        if alpha > 0.05 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
    }
}
let cut = reader.makeImage()!
// A square around the glyph with a little room, scaled to 256 px.
let side = max(maxX - minX, maxY - minY) * 106 / 100
let crop = CGRect(x: (minX + maxX - side) / 2, y: (minY + maxY - side) / 2, width: side, height: side)
let size = 256
let writer = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                       space: colorSpace, bitmapInfo: rgba)!
writer.interpolationQuality = .high
writer.draw(cut.cropping(to: crop)!, in: CGRect(x: 0, y: 0, width: size, height: size))
let bitmap = NSBitmapImageRep(cgImage: writer.makeImage()!)
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
print("Wrote \(output.path)")
