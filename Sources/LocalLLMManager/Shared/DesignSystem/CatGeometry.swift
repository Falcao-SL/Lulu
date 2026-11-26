// Generated from docs/assets/icon.svg by Scripts/generate-icons.py.
import CoreGraphics

enum CatGeometry {
    enum Tone { case ink, ivory }

    private static let bounds = CGRect(x: 60.375025, y: 103.356789, width: 335.297800, height: 258.851636)

    static func transform(in rect: CGRect) -> CGAffineTransform {
        let scale = min(rect.width / bounds.width, rect.height / bounds.height)
        return CGAffineTransform(translationX: rect.midX, y: rect.midY)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -bounds.midX, y: -bounds.midY)
    }

    static let layers: [(tone: Tone, path: CGPath)] = [
        (.ink, {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 117.957000, y: 155.515000))
            p.addCurve(to: CGPoint(x: 119.273000, y: 140.466000), control1: CGPoint(x: 118.023000, y: 154.309000), control2: CGPoint(x: 118.463000, y: 146.154000))
            p.addCurve(to: CGPoint(x: 138.505000, y: 103.361000), control1: CGPoint(x: 123.034000, y: 114.063000), control2: CGPoint(x: 132.230000, y: 103.110000))
            p.addCurve(to: CGPoint(x: 196.926000, y: 157.168000), control1: CGPoint(x: 156.235000, y: 104.071000), control2: CGPoint(x: 192.046000, y: 150.528000))
            p.addCurve(to: CGPoint(x: 201.427000, y: 158.264000), control1: CGPoint(x: 198.480000, y: 159.282000), control2: CGPoint(x: 198.908000, y: 159.038000))
            p.addCurve(to: CGPoint(x: 228.502000, y: 154.235000), control1: CGPoint(x: 211.303000, y: 155.226000), control2: CGPoint(x: 222.178000, y: 154.153000))
            p.addCurve(to: CGPoint(x: 255.484000, y: 158.555000), control1: CGPoint(x: 243.232000, y: 154.426000), control2: CGPoint(x: 254.791000, y: 158.364000))
            p.addCurve(to: CGPoint(x: 260.368000, y: 155.398000), control1: CGPoint(x: 258.031000, y: 159.255000), control2: CGPoint(x: 258.258000, y: 158.053000))
            p.addCurve(to: CGPoint(x: 273.349000, y: 139.371000), control1: CGPoint(x: 261.395000, y: 154.107000), control2: CGPoint(x: 270.709000, y: 142.391000))
            p.addCurve(to: CGPoint(x: 316.496000, y: 103.469000), control1: CGPoint(x: 284.403000, y: 126.724000), control2: CGPoint(x: 302.750000, y: 105.814000))
            p.addCurve(to: CGPoint(x: 335.893000, y: 135.431000), control1: CGPoint(x: 325.184000, y: 101.986000), control2: CGPoint(x: 333.126000, y: 118.557000))
            p.addCurve(to: CGPoint(x: 335.118000, y: 198.428000), control1: CGPoint(x: 337.450000, y: 144.931000), control2: CGPoint(x: 340.615000, y: 167.524000))
            p.addCurve(to: CGPoint(x: 333.275000, y: 208.565000), control1: CGPoint(x: 334.116000, y: 204.057000), control2: CGPoint(x: 332.875000, y: 207.010000))
            p.addCurve(to: CGPoint(x: 334.864000, y: 211.244000), control1: CGPoint(x: 333.431000, y: 209.169000), control2: CGPoint(x: 334.722000, y: 211.039000))
            p.addCurve(to: CGPoint(x: 339.092000, y: 217.742000), control1: CGPoint(x: 337.078000, y: 214.450000), control2: CGPoint(x: 337.184000, y: 214.359000))
            p.addCurve(to: CGPoint(x: 351.756000, y: 266.330000), control1: CGPoint(x: 354.220000, y: 244.566000), control2: CGPoint(x: 350.685000, y: 265.170000))
            p.addCurve(to: CGPoint(x: 357.501000, y: 265.965000), control1: CGPoint(x: 352.451000, y: 267.082000), control2: CGPoint(x: 353.763000, y: 265.842000))
            p.addCurve(to: CGPoint(x: 390.521000, y: 266.047000), control1: CGPoint(x: 362.922000, y: 266.145000), control2: CGPoint(x: 388.336000, y: 265.964000))
            p.addCurve(to: CGPoint(x: 391.450000, y: 275.088000), control1: CGPoint(x: 397.332000, y: 266.306000), control2: CGPoint(x: 397.128000, y: 274.257000))
            p.addCurve(to: CGPoint(x: 356.504000, y: 275.146000), control1: CGPoint(x: 389.385000, y: 275.390000), control2: CGPoint(x: 359.300000, y: 275.166000))
            p.addCurve(to: CGPoint(x: 352.311000, y: 273.950000), control1: CGPoint(x: 352.759000, y: 275.118000), control2: CGPoint(x: 352.458000, y: 273.947000))
            p.addCurve(to: CGPoint(x: 351.339000, y: 274.288000), control1: CGPoint(x: 351.968000, y: 273.956000), control2: CGPoint(x: 351.647000, y: 274.137000))
            p.addCurve(to: CGPoint(x: 350.748000, y: 276.536000), control1: CGPoint(x: 350.449000, y: 274.724000), control2: CGPoint(x: 350.891000, y: 275.003000))
            p.addCurve(to: CGPoint(x: 350.115000, y: 280.433000), control1: CGPoint(x: 350.718000, y: 276.851000), control2: CGPoint(x: 350.704000, y: 276.830000))
            p.addCurve(to: CGPoint(x: 330.181000, y: 324.236000), control1: CGPoint(x: 346.838000, y: 300.468000), control2: CGPoint(x: 336.630000, y: 316.578000))
            p.addCurve(to: CGPoint(x: 286.562000, y: 352.681000), control1: CGPoint(x: 311.670000, y: 346.215000), control2: CGPoint(x: 292.001000, y: 350.804000))
            p.addCurve(to: CGPoint(x: 244.515000, y: 361.648000), control1: CGPoint(x: 265.985000, y: 359.782000), control2: CGPoint(x: 252.843000, y: 360.640000))
            p.addCurve(to: CGPoint(x: 216.475000, y: 361.949000), control1: CGPoint(x: 236.306000, y: 362.642000), control2: CGPoint(x: 218.717000, y: 362.027000))
            p.addCurve(to: CGPoint(x: 193.570000, y: 359.134000), control1: CGPoint(x: 207.558000, y: 361.637000), control2: CGPoint(x: 195.388000, y: 359.459000))
            p.addCurve(to: CGPoint(x: 174.545000, y: 354.369000), control1: CGPoint(x: 192.026000, y: 358.858000), control2: CGPoint(x: 182.454000, y: 357.144000))
            p.addCurve(to: CGPoint(x: 140.575000, y: 338.399000), control1: CGPoint(x: 167.472000, y: 351.887000), control2: CGPoint(x: 154.200000, y: 348.871000))
            p.addCurve(to: CGPoint(x: 106.878000, y: 285.414000), control1: CGPoint(x: 140.318000, y: 338.202000), control2: CGPoint(x: 114.750000, y: 320.659000))
            p.addCurve(to: CGPoint(x: 105.116000, y: 274.648000), control1: CGPoint(x: 105.130000, y: 277.590000), control2: CGPoint(x: 105.148000, y: 274.772000))
            p.addCurve(to: CGPoint(x: 103.688000, y: 273.947000), control1: CGPoint(x: 105.087000, y: 274.536000), control2: CGPoint(x: 104.016000, y: 273.953000))
            p.addCurve(to: CGPoint(x: 100.478000, y: 275.123000), control1: CGPoint(x: 103.598000, y: 273.945000), control2: CGPoint(x: 103.073000, y: 275.000000))
            p.addCurve(to: CGPoint(x: 65.514000, y: 275.135000), control1: CGPoint(x: 99.425000, y: 275.173000), control2: CGPoint(x: 66.224000, y: 275.149000))
            p.addCurve(to: CGPoint(x: 60.795000, y: 268.646000), control1: CGPoint(x: 59.979000, y: 275.020000), control2: CGPoint(x: 59.910000, y: 270.238000))
            p.addCurve(to: CGPoint(x: 71.500000, y: 266.036000), control1: CGPoint(x: 62.588000, y: 265.419000), control2: CGPoint(x: 65.572000, y: 266.035000))
            p.addCurve(to: CGPoint(x: 102.514000, y: 266.444000), control1: CGPoint(x: 100.290000, y: 266.045000), control2: CGPoint(x: 100.319000, y: 265.940000))
            p.addCurve(to: CGPoint(x: 104.539000, y: 265.508000), control1: CGPoint(x: 103.894000, y: 266.762000), control2: CGPoint(x: 104.420000, y: 266.928000))
            p.addCurve(to: CGPoint(x: 117.642000, y: 216.587000), control1: CGPoint(x: 104.694000, y: 263.651000), control2: CGPoint(x: 102.874000, y: 241.291000))
            p.addCurve(to: CGPoint(x: 122.341000, y: 209.408000), control1: CGPoint(x: 120.809000, y: 211.290000), control2: CGPoint(x: 121.522000, y: 210.834000))
            p.addCurve(to: CGPoint(x: 120.883000, y: 198.427000), control1: CGPoint(x: 123.485000, y: 207.415000), control2: CGPoint(x: 122.206000, y: 205.837000))
            p.addCurve(to: CGPoint(x: 117.957000, y: 155.515000), control1: CGPoint(x: 117.735000, y: 180.799000), control2: CGPoint(x: 117.694000, y: 170.689000))
            p.closeSubpath()
            return p
        }()),
        (.ivory, {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 273.491000, y: 286.935000))
            p.addCurve(to: CGPoint(x: 264.443000, y: 284.608000), control1: CGPoint(x: 271.435000, y: 286.827000), control2: CGPoint(x: 269.238000, y: 286.901000))
            p.addCurve(to: CGPoint(x: 251.913000, y: 272.252000), control1: CGPoint(x: 258.368000, y: 281.704000), control2: CGPoint(x: 253.372000, y: 274.806000))
            p.addCurve(to: CGPoint(x: 252.859000, y: 211.735000), control1: CGPoint(x: 239.473000, y: 250.488000), control2: CGPoint(x: 244.424000, y: 224.355000))
            p.addCurve(to: CGPoint(x: 300.119000, y: 222.625000), control1: CGPoint(x: 267.930000, y: 189.190000), control2: CGPoint(x: 291.720000, y: 197.448000))
            p.addCurve(to: CGPoint(x: 286.579000, y: 282.610000), control1: CGPoint(x: 308.374000, y: 247.369000), control2: CGPoint(x: 299.636000, y: 273.676000))
            p.addCurve(to: CGPoint(x: 273.491000, y: 286.935000), control1: CGPoint(x: 279.537000, y: 287.429000), control2: CGPoint(x: 275.282000, y: 286.857000))
            p.closeSubpath()
            return p
        }()),
        (.ivory, {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 182.509000, y: 286.935000))
            p.addCurve(to: CGPoint(x: 169.421000, y: 282.610000), control1: CGPoint(x: 180.716000, y: 286.857000), control2: CGPoint(x: 176.466000, y: 287.431000))
            p.addCurve(to: CGPoint(x: 155.881000, y: 222.625000), control1: CGPoint(x: 156.365000, y: 273.677000), control2: CGPoint(x: 147.625000, y: 247.372000))
            p.addCurve(to: CGPoint(x: 203.138000, y: 211.737000), control1: CGPoint(x: 164.285000, y: 197.432000), control2: CGPoint(x: 188.086000, y: 189.199000))
            p.addCurve(to: CGPoint(x: 199.456000, y: 278.460000), control1: CGPoint(x: 214.821000, y: 229.229000), control2: CGPoint(x: 214.973000, y: 261.460000))
            p.addCurve(to: CGPoint(x: 192.741000, y: 283.921000), control1: CGPoint(x: 196.542000, y: 281.653000), control2: CGPoint(x: 193.335000, y: 283.566000))
            p.addCurve(to: CGPoint(x: 182.509000, y: 286.935000), control1: CGPoint(x: 187.772000, y: 286.884000), control2: CGPoint(x: 184.129000, y: 286.850000))
            p.closeSubpath()
            return p
        }()),
        (.ink, {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 197.033000, y: 248.464000))
            p.addCurve(to: CGPoint(x: 168.856000, y: 254.417000), control1: CGPoint(x: 193.998000, y: 275.690000), control2: CGPoint(x: 174.379000, y: 277.535000))
            p.addCurve(to: CGPoint(x: 186.602000, y: 219.303000), control1: CGPoint(x: 164.396000, y: 235.747000), control2: CGPoint(x: 173.725000, y: 213.068000))
            p.addCurve(to: CGPoint(x: 196.110000, y: 234.586000), control1: CGPoint(x: 190.936000, y: 221.401000), control2: CGPoint(x: 194.673000, y: 227.896000))
            p.addCurve(to: CGPoint(x: 197.033000, y: 248.464000), control1: CGPoint(x: 197.466000, y: 240.895000), control2: CGPoint(x: 197.139000, y: 244.493000))
            p.closeSubpath()
            return p
        }()),
        (.ink, {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 258.967000, y: 248.464000))
            p.addCurve(to: CGPoint(x: 259.889000, y: 234.587000), control1: CGPoint(x: 258.861000, y: 244.485000), control2: CGPoint(x: 258.535000, y: 240.879000))
            p.addCurve(to: CGPoint(x: 269.398000, y: 219.303000), control1: CGPoint(x: 261.347000, y: 227.814000), control2: CGPoint(x: 265.103000, y: 221.382000))
            p.addCurve(to: CGPoint(x: 287.144000, y: 254.417000), control1: CGPoint(x: 282.274000, y: 213.068000), control2: CGPoint(x: 291.604000, y: 235.749000))
            p.addCurve(to: CGPoint(x: 258.967000, y: 248.464000), control1: CGPoint(x: 281.621000, y: 277.534000), control2: CGPoint(x: 262.002000, y: 275.691000))
            p.closeSubpath()
            return p
        }()),
        (.ivory, {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 296.448000, y: 174.965000))
            p.addCurve(to: CGPoint(x: 291.505000, y: 174.785000), control1: CGPoint(x: 293.974000, y: 174.831000), control2: CGPoint(x: 293.988000, y: 174.751000))
            p.addCurve(to: CGPoint(x: 285.518000, y: 175.308000), control1: CGPoint(x: 287.642000, y: 174.837000), control2: CGPoint(x: 285.920000, y: 175.310000))
            p.addCurve(to: CGPoint(x: 284.692000, y: 173.573000), control1: CGPoint(x: 285.331000, y: 175.307000), control2: CGPoint(x: 284.097000, y: 174.861000))
            p.addCurve(to: CGPoint(x: 298.293000, y: 155.320000), control1: CGPoint(x: 284.868000, y: 173.191000), control2: CGPoint(x: 291.194000, y: 163.295000))
            p.addCurve(to: CGPoint(x: 316.075000, y: 141.781000), control1: CGPoint(x: 299.934000, y: 153.475000), control2: CGPoint(x: 313.646000, y: 137.649000))
            p.addCurve(to: CGPoint(x: 316.461000, y: 175.500000), control1: CGPoint(x: 316.515000, y: 142.529000), control2: CGPoint(x: 316.461000, y: 142.604000))
            p.addCurve(to: CGPoint(x: 316.166000, y: 184.117000), control1: CGPoint(x: 316.461000, y: 183.426000), control2: CGPoint(x: 316.790000, y: 183.607000))
            p.addCurve(to: CGPoint(x: 313.829000, y: 183.105000), control1: CGPoint(x: 315.329000, y: 184.802000), control2: CGPoint(x: 314.399000, y: 183.655000))
            p.addCurve(to: CGPoint(x: 308.252000, y: 178.930000), control1: CGPoint(x: 313.428000, y: 182.718000), control2: CGPoint(x: 311.144000, y: 180.511000))
            p.addCurve(to: CGPoint(x: 296.448000, y: 174.965000), control1: CGPoint(x: 301.911000, y: 175.463000), control2: CGPoint(x: 297.614000, y: 175.202000))
            p.closeSubpath()
            return p
        }()),
        (.ivory, {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 159.552000, y: 174.965000))
            p.addCurve(to: CGPoint(x: 147.748000, y: 178.930000), control1: CGPoint(x: 158.381000, y: 175.203000), control2: CGPoint(x: 154.091000, y: 175.463000))
            p.addCurve(to: CGPoint(x: 142.171000, y: 183.105000), control1: CGPoint(x: 144.857000, y: 180.510000), control2: CGPoint(x: 142.572000, y: 182.718000))
            p.addCurve(to: CGPoint(x: 139.834000, y: 184.117000), control1: CGPoint(x: 141.601000, y: 183.655000), control2: CGPoint(x: 140.671000, y: 184.802000))
            p.addCurve(to: CGPoint(x: 139.539000, y: 175.500000), control1: CGPoint(x: 139.210000, y: 183.607000), control2: CGPoint(x: 139.539000, y: 183.426000))
            p.addCurve(to: CGPoint(x: 139.923000, y: 141.779000), control1: CGPoint(x: 139.539000, y: 142.601000), control2: CGPoint(x: 139.485000, y: 142.527000))
            p.addCurve(to: CGPoint(x: 157.707000, y: 155.320000), control1: CGPoint(x: 142.351000, y: 137.642000), control2: CGPoint(x: 156.098000, y: 153.511000))
            p.addCurve(to: CGPoint(x: 171.308000, y: 173.573000), control1: CGPoint(x: 164.806000, y: 163.295000), control2: CGPoint(x: 171.132000, y: 173.191000))
            p.addCurve(to: CGPoint(x: 170.482000, y: 175.308000), control1: CGPoint(x: 171.903000, y: 174.861000), control2: CGPoint(x: 170.669000, y: 175.307000))
            p.addCurve(to: CGPoint(x: 164.495000, y: 174.785000), control1: CGPoint(x: 170.080000, y: 175.310000), control2: CGPoint(x: 168.358000, y: 174.837000))
            p.addCurve(to: CGPoint(x: 159.552000, y: 174.965000), control1: CGPoint(x: 162.012000, y: 174.751000), control2: CGPoint(x: 162.026000, y: 174.831000))
            p.closeSubpath()
            return p
        }()),
        (.ink, {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 352.956000, y: 301.520000))
            p.addCurve(to: CGPoint(x: 358.555000, y: 296.700000), control1: CGPoint(x: 353.791000, y: 298.683000), control2: CGPoint(x: 353.615000, y: 297.983000))
            p.addCurve(to: CGPoint(x: 386.458000, y: 289.335000), control1: CGPoint(x: 384.255000, y: 290.024000), control2: CGPoint(x: 384.213000, y: 289.876000))
            p.addCurve(to: CGPoint(x: 389.359000, y: 298.061000), control1: CGPoint(x: 393.525000, y: 287.634000), control2: CGPoint(x: 395.571000, y: 295.882000))
            p.addCurve(to: CGPoint(x: 360.547000, y: 305.673000), control1: CGPoint(x: 387.579000, y: 298.685000), control2: CGPoint(x: 362.856000, y: 305.076000))
            p.addCurve(to: CGPoint(x: 352.956000, y: 301.520000), control1: CGPoint(x: 353.074000, y: 307.605000), control2: CGPoint(x: 353.141000, y: 302.462000))
            p.closeSubpath()
            return p
        }()),
        (.ink, {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 62.958000, y: 247.514000))
            p.addCurve(to: CGPoint(x: 64.839000, y: 243.970000), control1: CGPoint(x: 63.029000, y: 247.260000), control2: CGPoint(x: 63.071000, y: 245.320000))
            p.addCurve(to: CGPoint(x: 68.539000, y: 242.638000), control1: CGPoint(x: 65.491000, y: 243.472000), control2: CGPoint(x: 68.236000, y: 242.721000))
            p.addCurve(to: CGPoint(x: 96.442000, y: 235.273000), control1: CGPoint(x: 70.766000, y: 242.029000), control2: CGPoint(x: 88.035000, y: 237.306000))
            p.addCurve(to: CGPoint(x: 101.663000, y: 242.669000), control1: CGPoint(x: 102.679000, y: 233.765000), control2: CGPoint(x: 104.569000, y: 239.833000))
            p.addCurve(to: CGPoint(x: 70.528000, y: 251.603000), control1: CGPoint(x: 100.149000, y: 244.146000), control2: CGPoint(x: 99.861000, y: 243.711000))
            p.addCurve(to: CGPoint(x: 62.958000, y: 247.514000), control1: CGPoint(x: 63.490000, y: 253.496000), control2: CGPoint(x: 63.275000, y: 249.015000))
            p.closeSubpath()
            return p
        }()),
        (.ink, {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 67.496000, y: 289.072000))
            p.addCurve(to: CGPoint(x: 71.410000, y: 289.845000), control1: CGPoint(x: 69.481000, y: 289.329000), control2: CGPoint(x: 69.455000, y: 289.350000))
            p.addCurve(to: CGPoint(x: 99.577000, y: 297.286000), control1: CGPoint(x: 71.484000, y: 289.863000), control2: CGPoint(x: 98.663000, y: 296.978000))
            p.addCurve(to: CGPoint(x: 102.223000, y: 304.302000), control1: CGPoint(x: 103.323000, y: 298.549000), control2: CGPoint(x: 103.627000, y: 302.308000))
            p.addCurve(to: CGPoint(x: 95.452000, y: 305.675000), control1: CGPoint(x: 100.154000, y: 307.238000), control2: CGPoint(x: 95.855000, y: 305.779000))
            p.addCurve(to: CGPoint(x: 66.355000, y: 297.910000), control1: CGPoint(x: 93.119000, y: 305.073000), control2: CGPoint(x: 69.066000, y: 298.861000))
            p.addCurve(to: CGPoint(x: 63.871000, y: 290.790000), control1: CGPoint(x: 61.617000, y: 296.248000), control2: CGPoint(x: 63.107000, y: 291.705000))
            p.addCurve(to: CGPoint(x: 67.496000, y: 289.072000), control1: CGPoint(x: 65.384000, y: 288.979000), control2: CGPoint(x: 67.318000, y: 289.110000))
            p.closeSubpath()
            return p
        }()),
        (.ink, {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 357.502000, y: 234.968000))
            p.addCurve(to: CGPoint(x: 375.507000, y: 239.476000), control1: CGPoint(x: 358.971000, y: 235.186000), control2: CGPoint(x: 361.036000, y: 235.492000))
            p.addCurve(to: CGPoint(x: 389.595000, y: 243.234000), control1: CGPoint(x: 379.138000, y: 240.476000), control2: CGPoint(x: 388.352000, y: 242.797000))
            p.addCurve(to: CGPoint(x: 387.429000, y: 251.987000), control1: CGPoint(x: 395.070000, y: 245.162000), control2: CGPoint(x: 393.800000, y: 252.812000))
            p.addCurve(to: CGPoint(x: 356.371000, y: 243.864000), control1: CGPoint(x: 385.743000, y: 251.769000), control2: CGPoint(x: 357.360000, y: 244.209000))
            p.addCurve(to: CGPoint(x: 353.844000, y: 236.763000), control1: CGPoint(x: 351.706000, y: 242.238000), control2: CGPoint(x: 353.034000, y: 237.744000))
            p.addCurve(to: CGPoint(x: 357.502000, y: 234.968000), control1: CGPoint(x: 355.297000, y: 235.005000), control2: CGPoint(x: 357.105000, y: 235.062000))
            p.closeSubpath()
            return p
        }()),
    ]
}
