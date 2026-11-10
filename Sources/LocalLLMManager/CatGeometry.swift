import CoreGraphics

/// Marca do Lulu em preto e branco. Coordenadas 0...100, Y para baixo.
enum CatGeometry {
    static func head(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: pt(18, 44, rect))
        c(path, 15, 33, 16, 15, 22, 12, rect)
        c(path, 27, 11, 38, 25, 41, 29, rect)
        c(path, 47, 27, 53, 27, 59, 29, rect)
        c(path, 62, 25, 73, 11, 78, 12, rect)
        c(path, 84, 15, 85, 33, 82, 44, rect)
        c(path, 94, 60, 86, 83, 68, 88, rect)
        c(path, 57, 92, 43, 92, 32, 88, rect)
        c(path, 14, 83, 6, 60, 18, 44, rect)
        path.closeSubpath()
        return path
    }

    static func innerEarLeft(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: pt(23, 24, rect))
        c(path, 23, 21, 31, 30, 33, 34, rect)
        c(path, 28, 33, 25, 35, 23, 37, rect)
        path.closeSubpath()
        return path
    }

    static func innerEarRight(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: pt(77, 24, rect))
        c(path, 77, 21, 69, 30, 67, 34, rect)
        c(path, 72, 33, 75, 35, 77, 37, rect)
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
