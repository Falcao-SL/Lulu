import SwiftUI

struct OverviewPane: View {
    @ObservedObject var model: AppModel

    private typealias Space = LuluTheme.Space

    private var active: Bool { model.phase == .starting || model.phase == .ready }
    private var installed: Int { model.engines.filter(\.installed).count }
    private var downloads: Int { model.jobs.filter { $0.state == .running || $0.state == .queued }.count }
    private var memoryFraction: Double {
        guard model.memory.total > 0 else { return 0 }
        return 1 - Double(min(model.memory.available, model.memory.total)) / Double(model.memory.total)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                LuluPageHeader("Visão geral", symbol: "square.grid.2x2")
                session
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: Space.md)], spacing: Space.md) {
                    LuluMetric("Memória disponível", value: model.memory.total == 0 ? "—" : Format.bytes(model.memory.available), symbol: "memorychip")
                    LuluMetric("Geração · tok/s", value: model.phase == .ready ? Format.rate(model.memory.predictRate) : "—", symbol: "bolt")
                        .help("Taxa de geração informada pelo motor. O traço indica que a métrica está indisponível.")
                    LuluMetric("Modelos locais", value: String(model.models.count), symbol: "square.stack.3d.up")
                    LuluMetric("Downloads ativos", value: String(downloads), symbol: "arrow.down.circle")
                }
                memory
                shortcuts
            }
            .frame(maxWidth: 1100, alignment: .leading)
            .padding(.bottom, Space.md)
        }
    }

    @ViewBuilder private var phaseBadge: some View {
        switch model.phase {
        case .ready: LuluStatusBadge("Disponível", tone: .success)
        case .starting: LuluStatusBadge("Carregando", tone: .info)
        case .stopped: LuluStatusBadge("Parado", tone: .neutral)
        case .failed: LuluStatusBadge("Falha", tone: .danger)
        }
    }

    private var session: some View {
        HStack(spacing: Space.lg) {
            LuluEmblem(side: 68)
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    Text("Servidor local").font(LuluTheme.TypeStyle.section)
                    phaseBadge
                }
                Text(sessionDetail).font(LuluTheme.TypeStyle.body).foregroundStyle(.secondary)
                    .lineLimit(2).help(sessionDetail)
            }
            Spacer(minLength: Space.sm)
            Button {
                model.pane = !active && model.models.isEmpty ? .models : .server
            } label: {
                Text(active ? "Gerenciar servidor" : model.models.isEmpty ? "Escolher modelo" : "Configurar servidor")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(Space.xl)
        .luluIdentityPanel()
    }

    private var sessionDetail: String {
        if active, let running = model.runningModel { return running.name }
        if model.phase == .failed { return "Consulte o log do servidor para identificar a falha." }
        if model.models.isEmpty { return "Adicione um modelo à biblioteca para começar." }
        return "Escolha um modelo da biblioteca e inicie o servidor."
    }

    private var memory: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                LuluSectionHeader("Memória unificada", symbol: "memorychip")
                Spacer()
                Button("Ver detalhes") { model.pane = .speed }.buttonStyle(.bordered)
            }
            ProgressView(value: memoryFraction)
                .accessibilityLabel("Memória usada")
                .accessibilityValue("\(Int(memoryFraction * 100)) por cento")
            HStack {
                Text(model.memory.total == 0 ? "Lendo memória do Mac…" : "\(Int(memoryFraction * 100))% em uso · \(Format.bytes(model.memory.total)) no Mac")
                Spacer()
                Text("Servidor: \(Format.bytes(model.memory.footprint))")
            }
            .font(LuluTheme.TypeStyle.caption).monospacedDigit().foregroundStyle(.secondary)
            Divider()
            HStack {
                Text("O purge encerra o servidor e libera a memória inativa.")
                    .font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                Spacer()
                Button { model.confirmPurge = true } label: {
                    Label("Purge de memória", luluSymbol: "memorychip")
                }.buttonStyle(.bordered)
            }
        }
        .padding(Space.lg)
        .luluCard()
    }

    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            LuluSectionHeader("Acesso rápido", symbol: "arrow.up.forward.square")
            shortcut("cpu", "Motores", "\(installed) de \(model.engines.count) motores integrados instalados", .engines)
            Divider()
            shortcut("square.stack.3d.up", "Biblioteca e downloads", "Buscar modelos e gerenciar arquivos locais", .models)
            Divider()
            shortcut("network", "Conexão com a API", active ? "http://127.0.0.1:\(model.port)/v1" : "Configurar modelo, contexto e porta", .server)
            if model.phase == .ready {
                Button(model.copied ? "Endpoint copiado" : "Copiar endpoint da API") { model.copyEndpoint() }
            }
        }
        .padding(Space.lg)
        .luluCard()
    }

    private func shortcut(_ symbol: String, _ title: String, _ detail: String, _ pane: Pane) -> some View {
        Button { model.pane = pane } label: {
            HStack(spacing: Space.md) {
                LuluIcon(symbol)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(title).font(LuluTheme.TypeStyle.body.weight(.medium))
                    Text(detail).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                }
                Spacer()
                LuluGlyph("chevron.right").font(.caption).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
