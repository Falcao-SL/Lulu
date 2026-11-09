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
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    context.translateBy(x: 0, y: CGFloat(pixels))
    context.scaleBy(x: 1, y: -1)
    let inset = CGFloat(pixels) * 0.11
    let rect = CGRect(x: inset, y: inset, width: CGFloat(pixels) - inset * 2, height: CGFloat(pixels) - inset * 2)
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.addPath(CatGeometry.head(in: rect))
    context.fillPath()
    context.setStrokeColor(CGColor(gray: 0, alpha: 1))
    context.setLineCap(.round)
    context.setLineWidth(CatGeometry.whiskerWidth(for: rect.width))
    for (start, end) in CatGeometry.whiskers(in: rect) {
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
    }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.addPath(CatGeometry.innerEarLeft(in: rect))
    context.addPath(CatGeometry.innerEarRight(in: rect))
    context.fillPath()
    context.fillEllipse(in: CatGeometry.eyeLeft(in: rect))
    context.fillEllipse(in: CatGeometry.eyeRight(in: rect))
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.fillEllipse(in: CatGeometry.pupilLeft(in: rect))
    context.fillEllipse(in: CatGeometry.pupilRight(in: rect))
    guard let image = context.makeImage() else { throw NSError(domain: "lulu", code: 2) }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "lulu", code: 3) }
    return data
}
