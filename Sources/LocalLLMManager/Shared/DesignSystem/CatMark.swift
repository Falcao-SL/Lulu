import SwiftUI

struct CatMark: View {
    private static let ink = Color(red: 20 / 255, green: 66 / 255, blue: 54 / 255)
    private static let ivory = Color(red: 235 / 255, green: 250 / 255, blue: 246 / 255)

    var body: some View {
        Canvas { context, size in
            let transform = CatGeometry.transform(in: CGRect(origin: .zero, size: size))
            for (tone, path) in CatGeometry.layers {
                context.fill(Path(path).applying(transform), with: .color(tone == .ink ? Self.ink : Self.ivory))
            }
        }
        .accessibilityLabel("Lulu")
    }
}
