import AppKit
import SwiftUI

struct TrayGlass: ViewModifier {
    static let secondaryText = Color(white: 0.86)

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            let shape = RoundedRectangle(cornerRadius: 22)
            content
                .glassEffect(.clear, in: shape)
                .background(.black.opacity(0.60), in: shape)
                .containerBackground(Color.clear, for: .window)
                .background(TransparentTrayWindow())
        } else {
            content
        }
    }
}

@available(macOS 26, *)
private struct TransparentTrayWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> Anchor { Anchor() }

    func updateNSView(_ nsView: Anchor, context: Context) {}

    final class Anchor: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.isOpaque = false
            window?.backgroundColor = .clear
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
