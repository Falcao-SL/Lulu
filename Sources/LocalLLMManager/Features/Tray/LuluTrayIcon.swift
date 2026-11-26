import AppKit

@MainActor
enum LuluTrayIcon {
    static let image: NSImage = {
        let size = NSSize(width: 22, height: 18)
        let image = NSImage(size: size, flipped: true) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let rect = CatTrayGeometry.fittedRect(in: bounds.insetBy(dx: 0.5, dy: 0.5))
            context.setFillColor(NSColor.black.cgColor)
            context.addPath(CatTrayGeometry.mark(in: rect))
            context.fillPath()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
