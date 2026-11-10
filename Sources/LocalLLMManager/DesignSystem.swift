import AppKit
import SwiftUI

enum LuluTheme {
    // Identity colors stay fixed across appearances, like the pixels of the app icon.
    static let ink = Color(red: 0.07, green: 0.20, blue: 0.16)
    static let brandMint = Color(red: 0.70, green: 0.91, blue: 0.80)
    static let brandIvory = Color(red: 0.91, green: 0.98, blue: 0.96)

    static let accent = adaptive("LuluAccent", light: 0x246754, dark: 0x91D8BD)
    static let canvas = adaptive("LuluCanvas", light: 0xF3F6F2, dark: 0x131B1A)
    static let surface = adaptive("LuluSurface", light: 0xFDFFFC, dark: 0x1B2624)
    static let subtle = adaptive("LuluSubtle", light: 0xE5F2EB, dark: 0x243B34)
    static let border = adaptive("LuluBorder", light: 0xCCDAD1, dark: 0x354B42)

    fileprivate static func adaptive(_ name: String, light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name(name)) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let rgb = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                green: CGFloat((rgb >> 8) & 255) / 255,
                blue: CGFloat(rgb & 255) / 255,
                alpha: 1
            )
        })
    }

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let control: CGFloat = 8
        static let card: CGFloat = 14
    }

    enum TypeStyle {
        static let page = Font.system(.largeTitle, design: .rounded, weight: .semibold)
        static let section = Font.headline
        static let body = Font.body
        static let caption = Font.caption
        static let metric = Font.system(.title, design: .rounded, weight: .semibold).monospacedDigit()
    }
}

enum LuluTone: CaseIterable {
    case neutral, info, success, warning, danger

    var symbol: String {
        switch self {
        case .neutral: return "circle"
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .neutral: return .secondary
        case .info: return Self.informational
        case .success: return LuluTheme.accent
        case .warning: return Self.caution
        case .danger: return Self.failure
        }
    }

    private static let informational = LuluTheme.adaptive("LuluInfo", light: 0x246754, dark: 0x91D8BD)
    private static let caution = LuluTheme.adaptive("LuluWarning", light: 0x78490E, dark: 0xEDC788)
    private static let failure = LuluTheme.adaptive("LuluDanger", light: 0x943B3F, dark: 0xF3AAAE)
}

private struct LuluCardSurface: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: LuluTheme.Radius.card, style: .continuous)
        content
            .background(LuluTheme.surface, in: shape)
            .overlay {
                shape.strokeBorder(contrast == .increased ? Color.secondary : LuluTheme.border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    /// Applies the panel surface after the caller chooses the content padding.
    func luluCard() -> some View { modifier(LuluCardSurface()) }
}

/// Decorative glyph. Supply the accessible name on the adjacent label or control.
struct LuluIcon: View {
    let symbol: String
    init(_ symbol: String) { self.symbol = symbol }

    var body: some View {
        LuluGlyph(symbol)
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(LuluTheme.accent)
            .frame(width: LuluTheme.Space.xxl, height: LuluTheme.Space.xxl)
            .background(LuluTheme.subtle, in: RoundedRectangle(cornerRadius: LuluTheme.Radius.control))
            .accessibilityHidden(true)
    }
}

struct LuluPageHeader: View {
    let title: String
    let symbol: String

    init(_ title: String, symbol: String) {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: LuluTheme.Space.md) {
            LuluIcon(symbol)
            Text(title).font(LuluTheme.TypeStyle.page)
            Spacer(minLength: LuluTheme.Space.md)
            LuluSignature()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct LuluSectionHeader: View {
    let title: String
    let symbol: String

    init(_ title: String, symbol: String) {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: LuluTheme.Space.sm) {
            LuluGlyph(symbol).foregroundStyle(LuluTheme.accent).accessibilityHidden(true)
            Text(title)
        }
        .font(LuluTheme.TypeStyle.section)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct LuluStatusBadge: View {
    let title: String
    let tone: LuluTone

    init(_ title: String, tone: LuluTone) {
        self.title = title
        self.tone = tone
    }

    var body: some View {
        Label(title, luluSymbol: tone.symbol)
            .labelStyle(.titleAndIcon)
            .font(LuluTheme.TypeStyle.caption.weight(.semibold))
            .foregroundStyle(tone.color)
            .padding(.vertical, LuluTheme.Space.xs)
            .padding(.horizontal, LuluTheme.Space.sm)
            .background(tone.color.opacity(0.09), in: Capsule())
            .accessibilityLabel(Text(title))
    }
}

struct LuluMetric: View {
    let title: String
    let value: String
    let symbol: String

    init(_ title: String, value: String, symbol: String) {
        self.title = title
        self.value = value
        self.symbol = symbol
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.sm) {
            Label { Text(title).foregroundStyle(.secondary) } icon: {
                LuluGlyph(symbol).foregroundStyle(LuluTheme.accent)
            }
            .font(LuluTheme.TypeStyle.caption)
            Text(value).font(LuluTheme.TypeStyle.metric)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LuluTheme.Space.lg)
        .luluCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value))
    }
}

/// Signature derived from the cat's three whiskers.
struct LuluSignature: View {
    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Capsule().frame(width: 20, height: 2).rotationEffect(.degrees(-12), anchor: .trailing)
            Capsule().frame(width: 28, height: 2)
            Capsule().frame(width: 20, height: 2).rotationEffect(.degrees(12), anchor: .trailing)
        }
        .foregroundStyle(LuluTheme.accent.opacity(0.45))
        .frame(width: 32, height: 28)
        .accessibilityHidden(true)
    }
}

struct LuluEmblem: View {
    var side: CGFloat = 64

    var body: some View {
        CatMark()
            .padding(side * 0.14)
            .frame(width: side, height: side)
            .background(
                LinearGradient(colors: [LuluTheme.brandMint, LuluTheme.brandIvory], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
                    .strokeBorder(LuluTheme.ink.opacity(0.09), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

extension View {
    func luluIdentityPanel() -> some View {
        background(
            LinearGradient(colors: [LuluTheme.subtle, LuluTheme.surface], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: LuluTheme.Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: LuluTheme.Radius.card, style: .continuous)
                .strokeBorder(LuluTheme.border, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}
