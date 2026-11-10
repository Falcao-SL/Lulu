import AppKit
import SwiftUI

private enum GuideAppearance: String, CaseIterable {
    case system = "System", light = "Light", dark = "Dark"

    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
private final class GuideSettings: ObservableObject {
    @Published var appearance = GuideAppearance.system
    @Published var components = false
    @Published var showCode = false
}

struct LuluDesignGuide: View {
    @StateObject private var settings = GuideSettings()
    private typealias Space = LuluTheme.Space

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Section", selection: $settings.components) {
                    Text("Foundations").tag(false)
                    Text("Components").tag(true)
                }.labelsHidden().pickerStyle(.segmented).frame(width: 230)
                Spacer()
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(GuideAppearance.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.fixedSize()
            }
            .padding(.horizontal, Space.xl).padding(.vertical, Space.md)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    if settings.components { components } else { foundations }
                }
                .frame(maxWidth: 940, alignment: .leading)
                .padding(Space.xl)
                .frame(maxWidth: .infinity)
            }.id(settings.components)
        }
        .background(LuluTheme.canvas)
        .frame(minWidth: 620, minHeight: 480)
        .tint(LuluTheme.accent)
        .preferredColorScheme(settings.appearance.scheme)
    }

    @ViewBuilder private var foundations: some View {
        HStack(spacing: Space.xl) {
            LuluEmblem(side: 80)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Lulu").font(.system(size: 40, weight: .semibold, design: .rounded))
                Text("Design system for macOS").font(LuluTheme.TypeStyle.body)
            }.foregroundStyle(LuluTheme.ink)
            Spacer()
            LuluSignature()
        }
        .padding(Space.xl)
        .background(LuluTheme.brandMint, in: RoundedRectangle(cornerRadius: LuluTheme.Radius.card))

        VStack(alignment: .leading, spacing: Space.md) {
            LuluSectionHeader("Interface palette", symbol: "paintpalette")
            HStack(spacing: Space.sm) {
                swatch("Action", "accent", LuluTheme.accent)
                swatch("Background", "canvas", LuluTheme.canvas)
                swatch("Surface", "surface", LuluTheme.surface)
                swatch("Selection", "subtle", LuluTheme.subtle)
                swatch("Border", "border", LuluTheme.border)
            }
        }

        VStack(alignment: .leading, spacing: Space.md) {
            LuluSectionHeader("Typography", symbol: "textformat")
            VStack(spacing: Space.sm) {
                specimen("Page title", "Overview", LuluTheme.TypeStyle.page)
                specimen("Section title", "Local library", LuluTheme.TypeStyle.section)
                specimen("Body", "Choose a model", LuluTheme.TypeStyle.body)
                specimen("Caption", "Available memory", LuluTheme.TypeStyle.caption)
                specimen("Metric", "12,4 GB", LuluTheme.TypeStyle.metric)
            }.padding(Space.lg).luluCard()
        }
        VStack(alignment: .leading, spacing: Space.md) {
            LuluSectionHeader("Spacing", symbol: "ruler")
            HStack(alignment: .bottom, spacing: Space.xl) {
                ForEach([Space.xs, Space.sm, Space.md, Space.lg, Space.xl, Space.xxl], id: \.self) { size in
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Rectangle().fill(LuluTheme.accent).frame(width: size, height: Space.sm)
                        Text("\(Int(size)) pt").font(LuluTheme.TypeStyle.caption).monospacedDigit()
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(Space.lg).luluCard()
        }
    }

    private func swatch(_ label: String, _ token: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            RoundedRectangle(cornerRadius: LuluTheme.Radius.control)
                .fill(color).frame(height: 46)
                .overlay(RoundedRectangle(cornerRadius: LuluTheme.Radius.control).strokeBorder(LuluTheme.border))
            Text(label).font(LuluTheme.TypeStyle.body.weight(.medium))
            Text(token).font(LuluTheme.TypeStyle.caption.monospaced()).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func specimen(_ label: String, _ sample: String, _ font: Font) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                .frame(width: 122, alignment: .leading)
            Text(sample).font(font)
            Spacer()
        }
    }

    @ViewBuilder private var components: some View {
        LuluPageHeader("Components", symbol: "square.grid.2x2")
        VStack(alignment: .leading, spacing: Space.md) {
            LuluSectionHeader("Indicators", symbol: "gauge.with.dots.needle.67percent")
            HStack(spacing: Space.md) {
                LuluMetric("Available memory", value: "12,4 GB", symbol: "memorychip")
                LuluMetric("Generation · tok/s", value: "34,8", symbol: "bolt")
                LuluMetric("Local models", value: "3", symbol: "square.stack.3d.up")
            }
        }
        VStack(alignment: .leading, spacing: Space.md) {
            LuluSectionHeader("States", symbol: "circle.lefthalf.filled")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), alignment: .leading)], alignment: .leading, spacing: Space.md) {
                LuluStatusBadge("Stopped", tone: .neutral)
                LuluStatusBadge("In progress", tone: .info)
                LuluStatusBadge("Available", tone: .success)
                LuluStatusBadge("Warning", tone: .warning)
                LuluStatusBadge("Failed", tone: .danger)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(Space.lg).luluCard()
        VStack(alignment: .leading, spacing: Space.md) {
            LuluSectionHeader("SwiftUI usage", symbol: "chevron.left.forwardslash.chevron.right")
            let snippet = #"LuluStatusBadge("Disponível", tone: .success)"#
            HStack {
                Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(snippet, forType: .string) } label: {
                    Label("Copy example", luluSymbol: "doc.on.doc")
                }.buttonStyle(.borderedProminent)
                Button(settings.showCode ? "Hide code" : "Show code") { settings.showCode.toggle() }.buttonStyle(.bordered)
            }
            if settings.showCode {
                Text(snippet).font(.body.monospaced()).textSelection(.enabled)
                    .padding(Space.md).frame(maxWidth: .infinity, alignment: .leading)
                    .background(LuluTheme.subtle, in: RoundedRectangle(cornerRadius: LuluTheme.Radius.control))
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(Space.lg).luluCard()
    }
}
