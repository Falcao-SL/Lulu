import CoreGraphics

/// Silhueta da tray, derivada de `docs/assets/icon-tray.svg` (Affinity).
/// Coordenadas 0...100 no quadrado do mark; use `aspectRatio` para encaixar sem esticar.
enum CatTrayGeometry {
    static let aspectRatio: CGFloat = 1.294511

    static func mark(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: pt(18.460, 28.110, rect))
        c(path, 18.480, 27.770, 18.610, 25.450, 18.840, 23.830, rect)
        c(path, 19.910, 16.300, 22.530, 13.180, 24.320, 13.250, rect)
        c(path, 29.370, 13.460, 39.580, 26.690, 40.970, 28.590, rect)
        c(path, 41.410, 29.190, 41.530, 29.120, 42.250, 28.900, rect)
        c(path, 45.060, 28.030, 48.160, 27.730, 49.970, 27.750, rect)
        c(path, 54.160, 27.800, 57.460, 28.930, 57.660, 28.980, rect)
        c(path, 58.380, 29.180, 58.450, 28.840, 59.050, 28.080, rect)
        c(path, 59.340, 27.710, 61.990, 24.370, 62.750, 23.510, rect)
        c(path, 65.900, 19.910, 71.120, 13.950, 75.040, 13.280, rect)
        c(path, 77.520, 12.860, 79.780, 17.580, 80.570, 22.390, rect)
        c(path, 81.010, 25.100, 81.910, 31.540, 80.350, 40.340, rect)
        c(path, 80.060, 41.950, 79.710, 42.790, 79.820, 43.230, rect)
        c(path, 79.870, 43.400, 80.240, 43.940, 80.280, 44.000, rect)
        c(path, 80.910, 44.910, 80.940, 44.880, 81.480, 45.850, rect)
        c(path, 85.790, 53.490, 84.780, 59.360, 85.090, 59.690, rect)
        c(path, 85.290, 59.910, 85.660, 59.550, 86.730, 59.590, rect)
        c(path, 88.270, 59.640, 95.510, 59.590, 96.140, 59.610, rect)
        c(path, 98.080, 59.690, 98.020, 61.950, 96.400, 62.190, rect)
        c(path, 95.810, 62.280, 87.240, 62.210, 86.440, 62.210, rect)
        c(path, 85.380, 62.200, 85.290, 61.860, 85.250, 61.860, rect)
        c(path, 85.150, 61.870, 85.060, 61.920, 84.970, 61.960, rect)
        c(path, 84.720, 62.090, 84.840, 62.160, 84.800, 62.600, rect)
        c(path, 84.790, 62.690, 84.790, 62.690, 84.620, 63.710, rect)
        c(path, 83.690, 69.420, 80.780, 74.010, 78.940, 76.190, rect)
        c(path, 73.670, 82.460, 68.060, 83.770, 66.510, 84.300, rect)
        c(path, 60.650, 86.320, 56.900, 86.570, 54.530, 86.860, rect)
        c(path, 52.190, 87.140, 47.180, 86.960, 46.540, 86.940, rect)
        c(path, 44.000, 86.850, 40.530, 86.230, 40.010, 86.140, rect)
        c(path, 39.570, 86.060, 36.840, 85.570, 34.590, 84.780, rect)
        c(path, 32.570, 84.070, 28.790, 83.210, 24.910, 80.230, rect)
        c(path, 24.840, 80.170, 17.550, 75.180, 15.310, 65.130, rect)
        c(path, 14.810, 62.900, 14.810, 62.100, 14.810, 62.060, rect)
        c(path, 14.800, 62.030, 14.490, 61.870, 14.400, 61.860, rect)
        c(path, 14.370, 61.860, 14.220, 62.160, 13.480, 62.200, rect)
        c(path, 13.180, 62.210, 3.720, 62.210, 3.520, 62.200, rect)
        c(path, 1.940, 62.170, 1.920, 60.810, 2.180, 60.350, rect)
        c(path, 2.690, 59.430, 3.540, 59.610, 5.230, 59.610, rect)
        c(path, 13.430, 59.610, 13.440, 59.580, 14.060, 59.730, rect)
        c(path, 14.460, 59.820, 14.610, 59.860, 14.640, 59.460, rect)
        c(path, 14.690, 58.930, 14.170, 52.560, 18.370, 45.520, rect)
        c(path, 19.280, 44.010, 19.480, 43.880, 19.710, 43.470, rect)
        c(path, 20.040, 42.900, 19.680, 42.450, 19.300, 40.340, rect)
        c(path, 18.400, 35.320, 18.390, 32.440, 18.460, 28.110, rect)
        path.closeSubpath()

        path.move(to: pt(85.430, 69.720, rect))
        c(path, 85.670, 68.910, 85.620, 68.710, 87.030, 68.350, rect)
        c(path, 94.350, 66.450, 94.340, 66.400, 94.980, 66.250, rect)
        c(path, 96.990, 65.760, 97.580, 68.110, 95.800, 68.740, rect)
        c(path, 95.300, 68.910, 88.250, 70.730, 87.590, 70.900, rect)
        c(path, 85.460, 71.460, 85.480, 69.990, 85.430, 69.720, rect)
        path.closeSubpath()

        path.move(to: pt(2.790, 54.330, rect))
        c(path, 2.810, 54.260, 2.820, 53.710, 3.330, 53.320, rect)
        c(path, 3.510, 53.180, 4.300, 52.970, 4.380, 52.940, rect)
        c(path, 5.020, 52.770, 9.940, 51.420, 12.330, 50.840, rect)
        c(path, 14.110, 50.410, 14.650, 52.140, 13.820, 52.950, rect)
        c(path, 13.390, 53.370, 13.310, 53.250, 4.950, 55.500, rect)
        c(path, 2.940, 56.040, 2.880, 54.760, 2.790, 54.330, rect)
        path.closeSubpath()

        path.move(to: pt(4.080, 66.170, rect))
        c(path, 4.650, 66.250, 4.640, 66.250, 5.200, 66.390, rect)
        c(path, 5.220, 66.400, 12.970, 68.430, 13.230, 68.510, rect)
        c(path, 14.290, 68.870, 14.380, 69.950, 13.980, 70.510, rect)
        c(path, 13.390, 71.350, 12.170, 70.940, 12.050, 70.910, rect)
        c(path, 11.390, 70.730, 4.530, 68.960, 3.760, 68.690, rect)
        c(path, 2.410, 68.220, 2.830, 66.920, 3.050, 66.660, rect)
        c(path, 3.480, 66.150, 4.030, 66.180, 4.080, 66.170, rect)
        path.closeSubpath()

        path.move(to: pt(86.730, 50.760, rect))
        c(path, 87.150, 50.820, 87.730, 50.910, 91.860, 52.040, rect)
        c(path, 92.890, 52.330, 95.520, 52.990, 95.870, 53.110, rect)
        c(path, 97.430, 53.660, 97.070, 55.840, 95.250, 55.610, rect)
        c(path, 94.770, 55.540, 86.690, 53.390, 86.400, 53.290, rect)
        c(path, 85.080, 52.830, 85.450, 51.550, 85.680, 51.270, rect)
        c(path, 86.100, 50.770, 86.610, 50.780, 86.730, 50.760, rect)
        path.closeSubpath()

        return path
    }

    /// Retângulo centrado em `bounds` que preserva `aspectRatio`.
    static func fittedRect(in bounds: CGRect) -> CGRect {
        let available = bounds
        let fittedWidth: CGFloat
        let fittedHeight: CGFloat
        if available.width / available.height > aspectRatio {
            fittedHeight = available.height
            fittedWidth = fittedHeight * aspectRatio
        } else {
            fittedWidth = available.width
            fittedHeight = fittedWidth / aspectRatio
        }
        return CGRect(
            x: available.midX - fittedWidth / 2,
            y: available.midY - fittedHeight / 2,
            width: fittedWidth,
            height: fittedHeight
        )
    }

    private static func c(_ path: CGMutablePath, _ c1x: CGFloat, _ c1y: CGFloat, _ c2x: CGFloat, _ c2y: CGFloat, _ x: CGFloat, _ y: CGFloat, _ rect: CGRect) {
        path.addCurve(to: pt(x, y, rect), control1: pt(c1x, c1y, rect), control2: pt(c2x, c2y, rect))
    }

    private static func pt(_ x: CGFloat, _ y: CGFloat, _ rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + x / 100 * rect.width, y: rect.minY + y / 100 * rect.height)
    }
}
