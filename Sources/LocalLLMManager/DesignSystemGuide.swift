import AppKit
import SwiftUI

private enum GuideAppearance: String, CaseIterable {
    case system = "Sistema", light = "Claro", dark = "Escuro"

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
                Picker("Seção", selection: $settings.components) {
                    Text("Fundamentos").tag(false)
                    Text("Componentes").tag(true)
                }.labelsHidden().pickerStyle(.segmented).frame(width: 230)
                Spacer()
                Picker("Aparência", selection: $settings.appearance) {
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
                Text("Sistema de design para macOS").font(LuluTheme.TypeStyle.body)
            }.foregroundStyle(LuluTheme.ink)
            Spacer()
            LuluSignature()
        }
        .padding(Space.xl)
        .background(LuluTheme.brandMint, in: RoundedRectangle(cornerRadius: LuluTheme.Radius.card))

        VStack(alignment: .leading, spacing: Space.md) {
            LuluSectionHeader("Paleta de interface", symbol: "paintpalette")
            HStack(spacing: Space.sm) {
                swatch("Ação", "accent", LuluTheme.accent)
                swatch("Fundo", "canvas", LuluTheme.canvas)
                swatch("Painel", "surface", LuluTheme.surface)
                swatch("Seleção", "subtle", LuluTheme.subtle)
                swatch("Contorno", "border", LuluTheme.border)
            }
        }

        VStack(alignment: .leading, spacing: Space.md) {
            LuluSectionHeader("Tipografia", symbol: "textformat")
            VStack(spacing: Space.sm) {
                specimen("Título de página", "Visão geral", LuluTheme.TypeStyle.page)
                specimen("Título de seção", "Biblioteca local", LuluTheme.TypeStyle.section)
                specimen("Corpo", "Escolha um modelo", LuluTheme.TypeStyle.body)
                specimen("Legenda", "Memória disponível", LuluTheme.TypeStyle.caption)
                specimen("Métrica", "12,4 GB", LuluTheme.TypeStyle.metric)
            }.padding(Space.lg).luluCard()
        }
        VStack(alignment: .leading, spacing: Space.md) {
            LuluSectionHeader("Espaçamento", symbol: "ruler")
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
        LuluPageHeader("Componentes", symbol: "square.grid.2x2")
        VStack(alignment: .leading, spacing: Space.md) {
            LuluSectionHeader("Indicadores", symbol: "gauge.with.dots.needle.67percent")
            HStack(spacing: Space.md) {
                LuluMetric("Memória disponível", value: "12,4 GB", symbol: "memorychip")
                LuluMetric("Geração · tok/s", value: "34,8", symbol: "bolt")
                LuluMetric("Modelos locais", value: "3", symbol: "square.stack.3d.up")
            }
        }
        VStack(alignment: .leading, spacing: Space.md) {
            LuluSectionHeader("Estados", symbol: "circle.lefthalf.filled")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), alignment: .leading)], alignment: .leading, spacing: Space.md) {
                LuluStatusBadge("Parado", tone: .neutral)
                LuluStatusBadge("Em andamento", tone: .info)
                LuluStatusBadge("Disponível", tone: .success)
                LuluStatusBadge("Atenção", tone: .warning)
                LuluStatusBadge("Falha", tone: .danger)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(Space.lg).luluCard()
        VStack(alignment: .leading, spacing: Space.md) {
            LuluSectionHeader("Uso em SwiftUI", symbol: "chevron.left.forwardslash.chevron.right")
            let snippet = #"LuluStatusBadge("Disponível", tone: .success)"#
            HStack {
                Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(snippet, forType: .string) } label: {
                    Label("Copiar exemplo", luluSymbol: "doc.on.doc")
                }.buttonStyle(.borderedProminent)
                Button(settings.showCode ? "Ocultar código" : "Mostrar código") { settings.showCode.toggle() }.buttonStyle(.bordered)
            }
            if settings.showCode {
                Text(snippet).font(.body.monospaced()).textSelection(.enabled)
                    .padding(Space.md).frame(maxWidth: .infinity, alignment: .leading)
                    .background(LuluTheme.subtle, in: RoundedRectangle(cornerRadius: LuluTheme.Radius.control))
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(Space.lg).luluCard()
    }
}
