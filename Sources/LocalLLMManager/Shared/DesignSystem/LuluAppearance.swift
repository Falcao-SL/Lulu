import AppKit
import SwiftUI

enum LuluAppearance: String, CaseIterable, Encodable {
    case system, light, dark

    static let preferenceKey = "lulu.appearance"

    static var stored: Self {
        UserDefaults.standard.string(forKey: preferenceKey).flatMap(Self.init(rawValue:)) ?? .system
    }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    @MainActor func apply() {
        let name: NSAppearance.Name? = switch self {
        case .system: nil
        case .light: .aqua
        case .dark: .darkAqua
        }
        NSApp.appearance = name.flatMap { NSAppearance(named: $0) }
    }
}
