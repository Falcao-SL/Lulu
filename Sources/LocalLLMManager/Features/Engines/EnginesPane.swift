import SwiftUI
import AppKit

struct EnginesPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.lg) {
            HStack {
                LuluPageHeader("Engines", symbol: "cpu")
                Spacer()
                Button("Refresh", luluSymbol: "arrow.clockwise") { model.refreshEngines() }
            }
            LuluSectionHeader("Built-in engines", symbol: "slider.horizontal.3")
            #if arch(x86_64)
            Text("On Intel Macs, use GGUF models with llama.cpp. MLX engines require Apple Silicon.")
                .font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
            #endif
            ForEach(model.engines) { engine in
                HStack(alignment: .top, spacing: LuluTheme.Space.md) {
                    LuluIcon(engine.id == "mlx-vlm" ? "eye" : engine.id == "llama.cpp" ? "shippingbox" : "cpu")
                    VStack(alignment: .leading, spacing: LuluTheme.Space.sm) {
                        Text(engine.name).font(LuluTheme.TypeStyle.section)
                        Text(engine.blurb).font(LuluTheme.TypeStyle.body)
                        Text(engineLine(engine)).font(LuluTheme.TypeStyle.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle).help(engineLine(engine))
                    }
                    Spacer(minLength: LuluTheme.Space.sm)
                    VStack(alignment: .trailing, spacing: LuluTheme.Space.sm) {
                        LuluStatusBadge(statusTitle(engine), tone: engine.installed ? .success : .neutral)
                        if model.busyEngineID == engine.id {
                            ProgressView("In progress").controlSize(.small)
                        } else if engine.installed && engine.managed {
                            Button("Remove", role: .destructive) { model.removeEngine(engine.id) }
                                .disabled(model.busyEngineID != nil)
                        } else if !engine.installed {
                            Button("Install", luluSymbol: "arrow.down.circle") { model.installEngine(engine.id) }
                                .disabled(model.busyEngineID != nil)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(LuluTheme.Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .luluCard()
            }
            DisclosureGroup("Installation activity") {
                logBox(model.operationText, empty: "Installation and removal activity appears here.")
            }
            AdditionalEnginesView(model: model)
        }
    }

    private func statusTitle(_ engine: EngineStatus) -> String {
        if !engine.installed { return "Available" }
        return engine.managed ? "Installed" : "Manual installation"
    }

    private func engineLine(_ engine: EngineStatus) -> String {
        if !engine.installed { return engine.id == "llama.cpp" ? "Homebrew" : "uv" }
        return [engine.version, engine.sizeBytes.map(Format.bytes) ?? "", engine.binary]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

}
