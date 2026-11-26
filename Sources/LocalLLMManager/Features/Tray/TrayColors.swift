import AppKit
import SwiftUI

enum TrayColors {
    static let secondaryText = Color(nsColor: NSColor(name: "LuluTraySecondary") { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? NSColor(white: 0.86, alpha: 1) : NSColor(white: 0.32, alpha: 1)
    })
}
