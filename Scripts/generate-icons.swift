import Foundation
import CoreGraphics
import ImageIO

let source = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(source as CFURL, nil)!, 0, nil)!
let sizes = ["AppIcon1024": 1024, "AppIcon20x20": 20, "AppIcon20x20@2x": 40, "AppIcon20x20@3x": 60,
             "AppIcon29x29": 29, "AppIcon29x29@2x": 58, "AppIcon29x29@3x": 87,
             "AppIcon40x40": 40, "AppIcon40x40@2x": 80, "AppIcon40x40@3x": 120,
             "AppIcon60x60@2x": 120, "AppIcon60x60@3x": 180,
             "AppIcon76x76": 76, "AppIcon76x76@2x": 152, "AppIcon83.5x83.5@2x": 167]
for (name, size) in sizes {
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(name + ".png") as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    precondition(CGImageDestinationFinalize(destination))
}
print("Generated \(sizes.count) opaque 8-bit app icons.")
