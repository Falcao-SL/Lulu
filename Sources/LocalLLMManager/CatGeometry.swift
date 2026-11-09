import CoreGraphics

/// Marca do Lulu em preto e branco. Coordenadas 0...100, Y para baixo.
enum CatGeometry {
    static func head(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: pt(50, 36, rect))
        c(path, 58, 26, 66, 14, 74, 15.5, rect)
        c(path, 84, 14, 94, 26, 88, 42, rect)
        c(path, 96, 54, 92, 66, 82, 74, rect)
        c(path, 72, 86, 58, 90, 50, 88, rect)
        c(path, 42, 90, 28, 86, 18, 74, rect)
        c(path, 8, 66, 4, 54, 12, 42, rect)
        c(path, 6, 26, 16, 14, 26, 15.5, rect)
        c(path, 34, 14, 42, 26, 50, 36, rect)
        path.closeSubpath()
        return path
    }

    static func innerEarLeft(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: pt(31, 31, rect))
        c(path, 24, 26, 25, 18, 32, 17.5, rect)
        c(path, 38, 17, 41, 24, 37, 31, rect)
        c(path, 34, 33.5, 32.5, 33, 31, 31, rect)
        path.closeSubpath()
        return path
    }

    static func innerEarRight(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: pt(69, 31, rect))
        c(path, 76, 26, 75, 18, 68, 17.5, rect)
        c(path, 62, 17, 59, 24, 63, 31, rect)
        c(path, 66, 33.5, 67.5, 33, 69, 31, rect)
        path.closeSubpath()
        return path
    }

    static func eyeLeft(in rect: CGRect) -> CGRect {
        box(27, 41, 18, 27, rect)
    }

    static func eyeRight(in rect: CGRect) -> CGRect {
        box(55, 41, 18, 27, rect)
    }

    static func pupilLeft(in rect: CGRect) -> CGRect {
        box(31.6, 47, 9, 16, rect)
    }

    static func pupilRight(in rect: CGRect) -> CGRect {
        box(59.4, 47, 9, 16, rect)
    }

    static func whiskers(in rect: CGRect) -> [(CGPoint, CGPoint)] {
        [
            (pt(1.0, 56, rect), pt(10.5, 53.5, rect)),
            (pt(0.2, 63, rect), pt(11.2, 63, rect)),
            (pt(1.0, 70, rect), pt(10.5, 72.5, rect)),
            (pt(99.0, 56, rect), pt(89.5, 53.5, rect)),
            (pt(99.8, 63, rect), pt(88.8, 63, rect)),
            (pt(99.0, 70, rect), pt(89.5, 72.5, rect)),
        ]
    }

    static func whiskerWidth(for side: CGFloat) -> CGFloat {
        side * 0.028
    }

    private static func c(_ path: CGMutablePath, _ c1x: CGFloat, _ c1y: CGFloat, _ c2x: CGFloat, _ c2y: CGFloat, _ x: CGFloat, _ y: CGFloat, _ rect: CGRect) {
        path.addCurve(to: pt(x, y, rect), control1: pt(c1x, c1y, rect), control2: pt(c2x, c2y, rect))
    }

    private static func pt(_ x: CGFloat, _ y: CGFloat, _ rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + x / 100 * rect.width, y: rect.minY + y / 100 * rect.height)
    }

    private static func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX + x / 100 * rect.width, y: rect.minY + y / 100 * rect.height, width: w / 100 * rect.width, height: h / 100 * rect.height)
    }
}
