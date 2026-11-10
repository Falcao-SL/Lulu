import SwiftUI

/// Lucide geometry is compiled into the executable and shared by every instance.
struct LuluGlyph: View {
    let symbol: String
    init(_ symbol: String) { self.symbol = symbol }

    private var path: Path {
        LuluVectorPaths.all[Self.names[symbol] ?? symbol] ?? LuluVectorPaths.all["circle"]!
    }

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            path.applying(CGAffineTransform(scaleX: side / 24, y: side / 24))
                .stroke(style: StrokeStyle(lineWidth: side / 14, lineCap: .round, lineJoin: .round))
                .frame(width: side, height: side)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }

    private static let names: [String: String] = [
        "square.grid.2x2": "layout-dashboard", "server.rack": "server",
        "square.stack.3d.up": "layers", "square.stack.3d.up.fill": "layers",
        "square.and.arrow.down": "download", "arrow.down.circle": "download", "arrow.down": "download",
        "gauge.with.dots.needle.67percent": "gauge", "bolt": "sparkles", "bolt.horizontal": "sparkles",
        "info.circle": "info", "info.circle.fill": "info", "circle.dotted": "circle",
        "checkmark": "check", "checkmark.circle.fill": "circle-check",
        "exclamationmark.triangle.fill": "info", "xmark.octagon.fill": "circle-x",
        "arrow.clockwise": "refresh-cw", "magnifyingglass": "search", "shippingbox": "box", "cube": "box",
        "doc.text": "file-text", "doc.plaintext": "file-text", "stop.fill": "square", "play.fill": "play",
        "doc.on.doc": "copy", "circle.fill": "circle", "circle.lefthalf.filled": "circle",
        "person.crop.square": "user", "building.2": "building", "text.bubble": "message-square",
        "memorychip": "memory-stick", "chevron.right": "chevron-right", "arrow.up.right": "arrow-up-right",
        "arrow.up.forward.square": "arrow-up-right", "paintpalette": "palette", "textformat": "type",
        "chevron.left.forwardslash.chevron.right": "code", "square.3.layers.3d": "layers",
        "desktopcomputer": "server", "slider.horizontal.3": "sliders-horizontal"
    ]
}

extension Label where Title == Text, Icon == LuluGlyph {
    init(_ title: String, luluSymbol: String) {
        self.init { Text(title) } icon: { LuluGlyph(luluSymbol) }
    }
}

extension Button where Label == SwiftUI.Label<Text, LuluGlyph> {
    init(_ title: String, luluSymbol: String, action: @escaping () -> Void) {
        self.init(action: action) { SwiftUI.Label(title, luluSymbol: luluSymbol) }
    }
}
