import AppKit
import CoreGraphics

@main
struct RenderIcon {
    static func main() throws {
        let directory = CommandLine.arguments.dropFirst().first ?? "AppIcon.iconset"
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let sizes = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024),
        ]
        for (name, pixels) in sizes {
            let data = try png(pixels)
            try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name))
        }
    }
}

func png(_ pixels: Int) throws -> Data {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: pixels * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "lulu", code: 1)
    }
    context.translateBy(x: 0, y: CGFloat(pixels))
    context.scaleBy(x: 1, y: -1)
    let side = CGFloat(pixels)
    let tile = CGRect(x: side * 0.06, y: side * 0.06, width: side * 0.88, height: side * 0.88)
    context.saveGState()
    context.addPath(CGPath(roundedRect: tile, cornerWidth: side * 0.20, cornerHeight: side * 0.20, transform: nil))
    context.clip()
    let colors = [CGColor(red: 0.70, green: 0.91, blue: 0.80, alpha: 1), CGColor(red: 0.22, green: 0.55, blue: 0.48, alpha: 1)]
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: side, y: side), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()
    let inset = CGFloat(pixels) * 0.18
    let rect = CGRect(x: inset, y: inset, width: CGFloat(pixels) - inset * 2, height: CGFloat(pixels) - inset * 2)
    let ink = CGColor(srgbRed: 20 / 255, green: 66 / 255, blue: 54 / 255, alpha: 1)
    let ivory = CGColor(srgbRed: 235 / 255, green: 250 / 255, blue: 246 / 255, alpha: 1)
    context.saveGState()
    context.concatenate(CatGeometry.transform(in: rect))
    for (tone, path) in CatGeometry.layers {
        context.setFillColor(tone == .ink ? ink : ivory)
        context.addPath(path)
        context.fillPath()
    }
    context.restoreGState()
    guard let image = context.makeImage() else { throw NSError(domain: "lulu", code: 2) }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "lulu", code: 3) }
    return data
}
