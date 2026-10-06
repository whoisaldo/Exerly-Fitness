import AppKit

// Original Exerly monogram. Render as opaque sRGB; iOS supplies the icon mask.
let output = CommandLine.arguments.dropFirst().first ?? "Exerly/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let size = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: 0, space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0.055, green: 0.086, blue: 0.102, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
context.setFillColor(CGColor(red: 0.88, green: 0.96, blue: 0.91, alpha: 1))
// A continuous E with a diagonal terminal on each horizontal stroke.
let mark = CGMutablePath()
mark.move(to: CGPoint(x: 272, y: 248))
for point in [CGPoint(x: 752, y: 248), CGPoint(x: 752, y: 372), CGPoint(x: 410, y: 372),
              CGPoint(x: 410, y: 452), CGPoint(x: 682, y: 452), CGPoint(x: 734, y: 576),
              CGPoint(x: 410, y: 576), CGPoint(x: 410, y: 652), CGPoint(x: 752, y: 652),
              CGPoint(x: 752, y: 776), CGPoint(x: 272, y: 776)] { mark.addLine(to: point) }
mark.closeSubpath()
context.addPath(mark)
context.fillPath()
context.setFillColor(CGColor(red: 0.39, green: 0.85, blue: 0.64, alpha: 1))
context.fill(CGRect(x: 786, y: 452, width: 34, height: 124))
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
