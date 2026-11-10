import SwiftUI
import AppKit

@main
struct LuluApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Lulu", id: "main") {
            RootView(model: model)
                .frame(minWidth: 920, minHeight: 640)
        }
        .defaultSize(width: 1120, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .help) {
                Button("Guia visual do Lulu") { openWindow(id: "design-guide") }
            }
        }

        Window("Guia visual do Lulu", id: "design-guide") {
            LuluDesignGuide()
        }
        .defaultSize(width: 850, height: 740)
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: LuluTheme.Space.lg) {
                HStack(spacing: 10) {
                    LuluEmblem(side: 44)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Lulu").font(.system(size: 22, weight: .semibold, design: .rounded))
                        Text("Sua IA, neste Mac").font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                VStack(spacing: LuluTheme.Space.xs) {
                    navigationItem("Visão geral", "square.grid.2x2", .overview)
                    navigationItem("Motores", "cpu", .engines)
                    navigationItem("Modelos", "square.and.arrow.down", .models)
                    navigationItem("Servidor", "server.rack", .server)
                    navigationItem("Desempenho", "gauge.with.dots.needle.67percent", .speed)
                }.padding(.horizontal, LuluTheme.Space.sm)
                Spacer()

            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
                if let banner = model.banner {
                    HStack {
                        LuluGlyph("info.circle").foregroundStyle(LuluTheme.accent)
                            .accessibilityHidden(true)
                        Text(banner).font(LuluTheme.TypeStyle.body)
                        Spacer()
                        Button("Fechar") { model.banner = nil }.buttonStyle(.borderless)
                    }
                    .padding(LuluTheme.Space.md)
                    .luluCard()
                }
                switch model.pane {
                case .overview: OverviewPane(model: model)
                case .engines: ScrollView { EnginesPane(model: model) }
                case .models: ModelsPane(model: model)
                case .server: ScrollView { ServerPane(model: model) }
                case .speed: ScrollView { SpeedPane(model: model) }
                }
                Spacer(minLength: 0)
            }
            .padding(LuluTheme.Space.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(LuluTheme.canvas)
        }
        .onChange(of: scenePhase) { _, phase in model.setMonitoringActive(phase == .active) }
        .tint(LuluTheme.accent)
        .accentColor(LuluTheme.accent)
        .confirmationDialog("Remover este motor?", isPresented: removeShown, titleVisibility: .visible) {
            Button("Remover", role: .destructive) { model.confirmEngineRemoval() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("O programa sai do disco. Os modelos em ~/models ficam.")
        }
        .confirmationDialog("Apagar este modelo?", isPresented: deleteShown, titleVisibility: .visible) {
            Button("Apagar", role: .destructive) { model.confirmModelDeletion() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Os arquivos saem de ~/models. O download parcial também pode ser tirado da fila.")
        }
        .sheet(item: $model.configuredNotice) { notice in
            ConfiguredSheet(notice: notice)
        }
        .confirmationDialog("Purge de memória?", isPresented: $model.confirmPurge, titleVisibility: .visible) {
            Button("Purge", role: .destructive) { model.purge() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Derruba o servidor, solta pesos, KV cache e contexto, e pede ao macOS para liberar a memória inativa.")
        }
    }

    private func navigationItem(_ title: String, _ symbol: String, _ pane: Pane) -> some View {
        Button { model.pane = pane } label: {
            HStack(spacing: LuluTheme.Space.md) {
                LuluGlyph(symbol).foregroundStyle(LuluTheme.accent)
                Text(title).font(LuluTheme.TypeStyle.body.weight(model.pane == pane ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .padding(LuluTheme.Space.md)
            .foregroundStyle(Color.primary)
            .background(model.pane == pane ? LuluTheme.subtle : Color.clear,
                        in: RoundedRectangle(cornerRadius: LuluTheme.Radius.control))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.pane == pane ? .isSelected : [])
    }

    private var removeShown: Binding<Bool> {
        Binding(get: { model.confirmRemoveEngine != nil }, set: { if !$0 { model.confirmRemoveEngine = nil } })
    }

    private var deleteShown: Binding<Bool> {
        Binding(get: { model.confirmDeleteModel != nil }, set: { if !$0 { model.confirmDeleteModel = nil } })
    }
}

struct CatMark: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(CatGeometry.head(in: rect)), with: .color(LuluTheme.ink))
            var whiskers = Path()
            for (start, end) in CatGeometry.whiskers(in: rect) {
                whiskers.move(to: start)
                whiskers.addLine(to: end)
            }
            context.stroke(whiskers, with: .color(LuluTheme.ink), style: StrokeStyle(lineWidth: CatGeometry.whiskerWidth(for: size.width), lineCap: .round))
            context.fill(Path(CatGeometry.innerEarLeft(in: rect)), with: .color(LuluTheme.brandIvory))
            context.fill(Path(CatGeometry.innerEarRight(in: rect)), with: .color(LuluTheme.brandIvory))
            context.fill(Path(ellipseIn: CatGeometry.eyeLeft(in: rect)), with: .color(LuluTheme.brandIvory))
            context.fill(Path(ellipseIn: CatGeometry.eyeRight(in: rect)), with: .color(LuluTheme.brandIvory))
            context.fill(Path(ellipseIn: CatGeometry.pupilLeft(in: rect)), with: .color(LuluTheme.ink))
            context.fill(Path(ellipseIn: CatGeometry.pupilRight(in: rect)), with: .color(LuluTheme.ink))
        }
        .accessibilityLabel("Lulu")
    }
}

private struct EnginesPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.lg) {
            HStack {
                LuluPageHeader("Motores", symbol: "cpu")
                Spacer()
                Button("Atualizar", luluSymbol: "arrow.clockwise") { model.refreshEngines() }
            }
            LuluSectionHeader("Motores integrados", symbol: "slider.horizontal.3")
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
                            ProgressView("Em andamento").controlSize(.small)
                        } else if engine.installed && engine.managed {
                            Button("Remover", role: .destructive) { model.removeEngine(engine.id) }
                                .disabled(model.busyEngineID != nil)
                        } else if !engine.installed {
                            Button("Instalar", luluSymbol: "arrow.down.circle") { model.installEngine(engine.id) }
                                .disabled(model.busyEngineID != nil)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(LuluTheme.Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .luluCard()
            }
            DisclosureGroup("Atividade de instalação") {
                logBox(model.operationText, empty: "A instalação e a remoção aparecem aqui.")
            }
            AdditionalEnginesView(model: model)
        }
    }

    private func statusTitle(_ engine: EngineStatus) -> String {
        if !engine.installed { return "Disponível" }
        return engine.managed ? "Instalado" : "Instalação manual"
    }

    private func engineLine(_ engine: EngineStatus) -> String {
        if !engine.installed { return engine.id == "llama.cpp" ? "Homebrew" : "uv" }
        return [engine.version, engine.sizeBytes.map(Format.bytes) ?? "", engine.binary]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

}

private struct ModelsPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LuluTheme.Space.lg) {
                LuluPageHeader("Modelos", symbol: "square.stack.3d.up")
                libraryCard
                downloadCard
                DisclosureGroup("Acesso ao Hugging Face · opcional") {
                    keyCard.padding(.top, 8)
                }
            }
        }
    }

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.sm) {
            LuluSectionHeader("Chave do Hugging Face", symbol: "key")
            Text("Cole a chave que começa com hf_. Ela fica no Keychain e só sai no pedido de busca ou download.").font(.callout).foregroundStyle(.secondary)
            HStack {
                SecureField("hf_…", text: $model.tokenDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Guardar chave") { model.saveToken() }
                    .buttonStyle(.borderedProminent)
                    .tint(LuluTheme.accent)
                    .disabled(model.tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Apagar chave") { model.clearToken() }
            }
            Text(model.tokenNote).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
        }
        .padding(LuluTheme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .luluCard()
    }

    private var downloadCard: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.sm) {
            LuluSectionHeader("Explorar modelos", symbol: "magnifyingglass")
            HStack {
                TextField("organização/modelo ou um pedaço do nome", text: $model.repoQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.searchHub() }
                Button(model.searching ? "Buscando…" : "Buscar") { model.searchHub() }
                    .disabled(model.searching)
            }
            HStack {
                TextField("Publicador / organização", text: $model.searchAuthor)
                    .textFieldStyle(.roundedBorder).onSubmit { model.searchHub() }
                Picker("Formato", selection: $model.searchFormat) {
                    Text("Todos").tag("")
                    Text("MLX").tag("mlx")
                    Text("GGUF").tag("gguf")
                }.frame(maxWidth: 180)
                Picker("Ordenar", selection: $model.searchSort) {
                    Text("Downloads").tag("downloads")
                    Text("Curtidas").tag("likes")
                    Text("Atualizados").tag("lastModified")
                }.frame(maxWidth: 200)
            }
            Text("Buscar aplica os filtros e retorna até 40 resultados. A quantização vem do nome e das tags. O laboratório vem do modelo base.")
                .font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
            if model.searching { ProgressView("Consultando Hugging Face…").controlSize(.small) }
            if model.searchFinished && model.hubHits.isEmpty && !model.searching {
                Label("Nenhum resultado. Tente outro nome, publicador ou formato.", luluSymbol: "magnifyingglass")
                    .foregroundStyle(.secondary).padding(.vertical, 12)
            }
            if !model.hubHits.isEmpty {
                Text("\(model.hubHits.count) resultados").font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(model.hubHits) { hit in
                            HubResultView(hit: hit, selected: model.selectedHubHit?.id == hit.id && model.listedRepo == hit.id) {
                                model.selectedHubHit = hit
                                model.loadFiles(hit.id)
                            }
                        }
                    }.padding(2)
                }.frame(maxHeight: 420)
            }
            if !model.listedRepo.isEmpty {
                Divider().padding(.vertical, 8)
                Label(model.listedRepo, luluSymbol: "folder").font(.headline).textSelection(.enabled)
                if let hit = model.selectedHubHit { HubMetadataView(hit: hit) }
                Text("Selecione os arquivos · quantização identificada pelo nome quando disponível.")
                    .font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                Text(Hub.destination(repo: model.listedRepo, files: model.listedFiles).path).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary).lineLimit(1)
                ScrollView {
                    VStack(alignment: .leading, spacing: LuluTheme.Space.xs) {
                        ForEach($model.listedFiles) { $file in
                            Toggle(isOn: $file.selected) {
                                HStack {
                                    LuluGlyph(file.path.hasSuffix(".gguf") || file.path.hasSuffix(".safetensors") ? "cube" : "doc.text")
                                        .foregroundStyle(LuluTheme.accent)
                                    Text(file.path).lineLimit(1).truncationMode(.middle).help(file.path)
                                    if let quant = ModelMetadata.quantization(in: file.path) {
                                        Text(quant).font(.caption2.monospaced()).foregroundStyle(LuluTheme.accent)
                                    }
                                    Spacer()
                                    Text(Format.bytes(UInt64(max(file.size, 0)))).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                }
                .frame(maxHeight: 220)
                HStack {
                    Text(selectedSummary).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Baixar selecionados") { model.enqueueSelected() }
                        .buttonStyle(.borderedProminent)
                        .tint(LuluTheme.accent)
                        .disabled(!model.listedFiles.contains(where: \.selected))
                }
            }
            if !model.jobs.isEmpty {
                LuluSectionHeader("Downloads", symbol: "arrow.down.circle").padding(.top, LuluTheme.Space.sm)
                ForEach(model.jobs) { job in
                    jobRow(job)
                }
            }
        }
        .padding(LuluTheme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .luluCard()
    }

    private var selectedSummary: String {
        let chosen = model.listedFiles.filter(\.selected)
        let bytes = chosen.reduce(Int64(0)) { $0 + max($1.size, 0) }
        return "\(chosen.count) arquivos · \(Format.bytes(UInt64(bytes)))"
    }

    private func jobRow(_ job: DownloadJob) -> some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.xs) {
            HStack {
                Text(job.repo).font(.callout.weight(.semibold)).lineLimit(1)
                Spacer()
                jobStatus(job.state)
            }
            ProgressView(value: progress(job))
                .tint(LuluTheme.accent)
            HStack {
                Text("\(Format.bytes(UInt64(max(job.received, 0)))) / \(Format.bytes(UInt64(max(job.total, 0))))")
                    .font(.caption.monospacedDigit())
                if job.state == .running, model.downloadSpeed > 0 {
                    Text(Format.bytes(UInt64(model.downloadSpeed)) + "/s").font(.caption)
                }
                Spacer()
                if job.state == .running || job.state == .queued {
                    Button("Pausar") { model.pauseDownload(job.id) }
                }
                if job.state == .paused || job.state == .failed {
                    Button("Continuar") { model.resumeDownload(job.id) }
                }
                Button("Remover") { model.removeDownload(job.id) }
            }
            if let error = job.error, !error.isEmpty {
                Text(error).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
            }
            Text(job.destination).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func jobStatus(_ state: DownloadState) -> some View {
        switch state {
        case .queued: LuluStatusBadge("Na fila", tone: .neutral)
        case .running: LuluStatusBadge("Baixando", tone: .info)
        case .paused: LuluStatusBadge("Pausado", tone: .warning)
        case .failed: LuluStatusBadge("Falha", tone: .danger)
        case .done: LuluStatusBadge("Concluído", tone: .success)
        }
    }

    private func progress(_ job: DownloadJob) -> Double {
        guard job.total > 0 else { return job.state == .done ? 1 : 0 }
        return min(1, Double(job.received) / Double(job.total))
    }

    private var libraryCard: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.sm) {
            HStack {
                LuluSectionHeader("Biblioteca local", symbol: "externaldrive")
                Spacer()
                Button("Atualizar") { Task { await model.rescanModels() } }
            }
            if model.models.isEmpty {
                Label("Adicione um modelo em ~/models/mlx ou ~/models/gguf, ou baixe um abaixo.", luluSymbol: "folder")
                    .font(LuluTheme.TypeStyle.body).foregroundStyle(.secondary)
            }
            ForEach(model.models) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).lineLimit(1)
                        Text("\(item.engineID) · \(Format.bytes(item.sizeBytes)) · \(item.arch?.summary ?? "KV desconhecido")")
                            .font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button("Apagar", role: .destructive) { model.deleteModel(item.id) }
                }
            }
        }
        .padding(LuluTheme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .luluCard()
    }
}

private struct ServerPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
            HStack {
                LuluPageHeader("Servidor", symbol: "server.rack")
                Spacer()
                LuluStatusBadge(phaseLabel, tone: phaseTone)
            }
            VStack(alignment: .leading, spacing: LuluTheme.Space.lg) {
                Picker("Modelo", selection: $model.selectedModelID) {
                    if model.models.isEmpty { Text("Nenhum modelo").tag("") }
                    ForEach(model.models) { item in
                        Text("\(item.name) · \(item.engineID) · \(Format.bytes(item.sizeBytes))").tag(item.id)
                    }
                }
                .disabled(serverActive)
                .onChange(of: model.selectedModelID) { _, _ in model.persist() }

                VStack(alignment: .leading, spacing: LuluTheme.Space.sm) {
                    HStack {
                        Text("Contexto")
                        Spacer()
                        Text("\(Format.tokens(model.contextLength)) tokens")
                            .font(LuluTheme.TypeStyle.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Picker("Contexto", selection: $model.contextLength) {
                        ForEach(model.contextOptions, id: \.self) { value in
                            Text(Format.tokens(value)).tag(value)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Contexto")
                    .pickerStyle(.segmented)
                    .disabled(serverActive)
                    .onChange(of: model.contextLength) { _, _ in model.persist() }
                }

                HStack {
                    Text("Porta")
                    TextField("Porta", value: $model.port, format: .number.grouping(.never))
                        .frame(width: 74)
                        .disabled(serverActive)
                        .onChange(of: model.port) { _, _ in model.persist() }
                    Spacer()
                    if serverActive {
                        Button("Parar servidor", luluSymbol: "stop.fill") { model.stopServer() }
                            .buttonStyle(.bordered)
                    } else {
                        Button("Iniciar servidor", luluSymbol: "play.fill") { model.startServer() }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.models.isEmpty)
                    }
                }
            }
            .padding(LuluTheme.Space.lg)
            .luluCard()

            HStack(spacing: LuluTheme.Space.md) {
                LuluIcon("link")
                Text(verbatim: "http://127.0.0.1:\(model.port)/v1")
                    .font(LuluTheme.TypeStyle.body.monospaced()).textSelection(.enabled)
                Spacer()
                if serverActive {
                    Button(model.copied ? "Copiado" : "Copiar", luluSymbol: model.copied ? "checkmark" : "doc.on.doc") {
                        model.copyEndpoint()
                    }
                }
            }
            .padding(LuluTheme.Space.lg)
            .luluCard()

            ClientRack(model: model)

            if !serverActive && model.models.isEmpty {
                Button("Escolher um modelo", luluSymbol: "square.stack.3d.up") { model.pane = .models }
            }
            DisclosureGroup("Logs do servidor") {
                logBox(model.logText, empty: "O log do servidor aparece aqui.")
            }
        }
    }

    private var serverActive: Bool { model.phase == .starting || model.phase == .ready }

    private var phaseTone: LuluTone {
        switch model.phase {
        case .stopped: return .neutral
        case .starting: return .info
        case .ready: return .success
        case .failed: return .danger
        }
    }

    private var phaseLabel: String {
        switch model.phase {
        case .stopped: return "Parado"
        case .starting: return "Iniciando"
        case .ready: return "Disponível"
        case .failed: return "Falha"
        }
    }
}

private struct SpeedPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let memory = model.memory
        VStack(alignment: .leading, spacing: LuluTheme.Space.lg) {
            LuluPageHeader("Desempenho", symbol: "gauge.with.dots.needle.67percent")
            VStack(alignment: .leading, spacing: LuluTheme.Space.xs) {
                if model.phase == .ready {
                    Text(Format.rate(memory.predictRate)).font(LuluTheme.TypeStyle.metric)
                    Text("tokens por segundo na geração").font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                } else {
                    Text(memory.total == 0 ? "—" : Format.bytes(memory.available)).font(LuluTheme.TypeStyle.metric)
                    Text("memória disponível").font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                }
            }.accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
                LuluSectionHeader("Processo do servidor", symbol: "server.rack")
                LazyVGrid(columns: columns, alignment: .leading, spacing: LuluTheme.Space.lg) {
                    tile("Prompt", Format.rate(memory.promptRate) + " tok/s")
                    tile("Processo", Format.bytes(memory.footprint))
                    tile("Pesos", Format.bytes(memory.weights))
                    tile("KV reservado", Format.bytes(memory.kvReserved))
                    tile("KV em uso", Format.bytes(memory.kvUsed))
                    tile("Contexto", contextLine(memory))
                }
                Text(memory.kvSummary).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
            }
            .padding(LuluTheme.Space.lg).luluCard()

            VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
                LuluSectionHeader("Memória do Mac", symbol: "memorychip")
                LazyVGrid(columns: columns, alignment: .leading, spacing: LuluTheme.Space.lg) {
                    tile("Total", Format.bytes(memory.total))
                    tile("Disponível", Format.bytes(memory.available))
                    tile("Wired", Format.bytes(memory.wired))
                    tile("Comprimida", Format.bytes(memory.compressed))
                    tile("Ativa", Format.bytes(memory.active))
                    tile("Liberável", Format.bytes(memory.purgeable))
                }
                Meter(footprint: fraction(memory.footprint, memory.total), other: fraction(otherUsed(memory), memory.total))
                HStack {
                    Label("Servidor", luluSymbol: "circle.fill").foregroundStyle(LuluTheme.accent)
                    Label("Outros processos", luluSymbol: "circle.lefthalf.filled")
                    Label("Disponível", luluSymbol: "circle")
                    Spacer()
                    Button("Purge de memória", luluSymbol: "sparkles") { model.confirmPurge = true }
                }
                .font(LuluTheme.TypeStyle.caption)
            }
            .padding(LuluTheme.Space.lg).luluCard()

            Text("O llama.cpp reserva o cache KV ao iniciar. No MLX, o valor em uso estima quanto o processo cresceu após carregar os pesos.")
                .font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3)

    private func contextLine(_ memory: MemorySnapshot) -> String {
        if let peak = memory.contextPeak {
            return "\(Format.tokens(peak)) / \(Format.tokens(memory.contextTokens))"
        }
        return Format.tokens(memory.contextTokens)
    }

    private func otherUsed(_ memory: MemorySnapshot) -> UInt64 {
        let used = memory.total > memory.available ? memory.total - memory.available : 0
        return used > memory.footprint ? used - memory.footprint : 0
    }

    private func fraction(_ part: UInt64, _ total: UInt64) -> Double {
        guard total > 0 else { return 0 }
        return min(1, Double(part) / Double(total))
    }
}

private struct Meter: View {
    var footprint: Double
    var other: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            HStack(spacing: 0) {
                Rectangle().fill(LuluTheme.accent).frame(width: width * footprint)
                Rectangle().fill(Color.primary.opacity(0.28)).frame(width: width * min(other, max(0, 1 - footprint)))
                Rectangle().fill(Color.primary.opacity(0.08))
            }
        }
        .frame(height: 10)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private func tile(_ title: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(title).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
        Text(value).font(.body.monospacedDigit().weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
}

private func logBox(_ text: String, empty: String) -> some View {
    ScrollView {
        Text(text.isEmpty ? empty : text)
            .font(LuluTheme.TypeStyle.caption.monospaced())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .textSelection(.enabled)
    }
    .frame(height: 120)
    .background(LuluTheme.subtle)
    .clipShape(RoundedRectangle(cornerRadius: LuluTheme.Radius.control))
}
