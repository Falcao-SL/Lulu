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
                LuluPageHeader("Overview", symbol: "square.grid.2x2")
                session
                updates
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: Space.md)], spacing: Space.md) {
                    LuluMetric("Available memory", value: model.memory.total == 0 ? "—" : Format.bytes(model.memory.available), symbol: "memorychip")
                    LuluMetric("Generation · tok/s", value: model.phase == .ready ? Format.rate(model.memory.predictRate) : "—", symbol: "bolt")
                        .help("Generation rate reported by the engine. A dash means the metric is unavailable.")
                    LuluMetric("Local models", value: String(model.models.count), symbol: "square.stack.3d.up")
                    LuluMetric("Active downloads", value: String(downloads), symbol: "arrow.down.circle")
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
        case .ready: LuluStatusBadge("Available", tone: .success)
        case .starting: LuluStatusBadge("Starting", tone: .info)
        case .stopped: LuluStatusBadge("Stopped", tone: .neutral)
        case .failed: LuluStatusBadge("Failed", tone: .danger)
        }
    }

    private var updates: some View {
        HStack(spacing: Space.md) {
            LuluIcon("arrow.down.circle")
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(model.updateVersion.map { "Lulu \($0) is available" } ?? "Lulu \(AppUpdates.current)")
                    .font(LuluTheme.TypeStyle.body.weight(.medium))
                Text(model.updateVersion == nil ? "Check for a newer release." : "Install the latest version for this Mac.")
                    .font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if model.updateURL != nil {
                Button("Install update") { model.downloadUpdate() }.buttonStyle(.borderedProminent)
            } else {
                Button(model.checkingUpdate ? "Checking…" : "Check for updates") { model.checkForUpdates(showFeedback: true) }
                    .disabled(model.checkingUpdate)
            }
        }
        .padding(Space.lg)
        .luluCard()
    }

    private var session: some View {
        HStack(spacing: Space.lg) {
            LuluEmblem(side: 68)
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    Text("Local server").font(LuluTheme.TypeStyle.section)
                    phaseBadge
                }
                Text(sessionDetail).font(LuluTheme.TypeStyle.body).foregroundStyle(.secondary)
                    .lineLimit(2).help(sessionDetail)
            }
            Spacer(minLength: Space.sm)
            Button {
                model.pane = !active && model.models.isEmpty ? .models : .server
            } label: {
                Text(active ? "Manage server" : model.models.isEmpty ? "Choose model" : "Configure server")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(Space.xl)
        .luluIdentityPanel()
    }

    private var sessionDetail: String {
        if active, let running = model.runningModel { return running.name }
        if model.phase == .failed { return "Check the server log to identify the error." }
        if model.models.isEmpty { return "Add a model to your library to get started." }
        return "Choose a model from your library and start the server."
    }

    private var memory: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                LuluSectionHeader("Unified memory", symbol: "memorychip")
                Spacer()
                Button("View details") { model.pane = .speed }.buttonStyle(.bordered)
            }
            ProgressView(value: memoryFraction)
                .accessibilityLabel("Used memory")
                .accessibilityValue("\(Int(memoryFraction * 100)) percent")
            HStack {
                Text(model.memory.total == 0 ? "Reading Mac memory…" : "\(Int(memoryFraction * 100))% used · \(Format.bytes(model.memory.total)) on this Mac")
                Spacer()
                Text("Server: \(Format.bytes(model.memory.footprint))")
            }
            .font(LuluTheme.TypeStyle.caption).monospacedDigit().foregroundStyle(.secondary)
            Divider()
            HStack {
                Text("Purge stops the server and requests release of inactive memory.")
                    .font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                Spacer()
                Button { model.confirmPurge = true } label: {
                    Label("Purge memory", luluSymbol: "memorychip")
                }.buttonStyle(.bordered)
            }
        }
        .padding(Space.lg)
        .luluCard()
    }

    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            LuluSectionHeader("Quick access", symbol: "arrow.up.forward.square")
            shortcut("cpu", "Engines", "\(installed) of \(model.engines.count) built-in engines installed", .engines)
            Divider()
            shortcut("square.stack.3d.up", "Library and downloads", "Search models and manage local files", .models)
            Divider()
            shortcut("network", "API connection", active ? "http://127.0.0.1:\(model.port)/v1" : "Configure model, context and port", .server)
            if model.phase == .ready {
                Button(model.copied ? "Endpoint copied" : "Copy API endpoint") { model.copyEndpoint() }
            }
            ClientRack(model: model)
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
