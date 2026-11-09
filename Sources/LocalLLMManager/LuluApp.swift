import SwiftUI
import AppKit

@main
struct LuluApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Lulu", id: "main") {
            RootView(model: model)
                .frame(minWidth: 920, minHeight: 640)
        }
        .defaultSize(width: 1040, height: 720)
        .windowResizability(.contentMinSize)
    }
}

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    CatMark()
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.primary.opacity(0.2), lineWidth: 1))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Lulu").font(.system(size: 18, weight: .semibold))
                        Text("desempenho local").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                List(selection: $model.pane) {
                    Label("Motores", systemImage: "cpu").tag(Pane.engines)
                    Label("Modelos", systemImage: "square.and.arrow.down").tag(Pane.models)
                    Label("Servidor", systemImage: "server.rack").tag(Pane.server)
                    Label("Desempenho", systemImage: "gauge.with.dots.needle.67percent").tag(Pane.speed)
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            VStack(alignment: .leading, spacing: 12) {
                if let banner = model.banner {
                    HStack {
                        Text(banner).font(.callout)
                        Spacer()
                        Button("Fechar") { model.banner = nil }.buttonStyle(.borderless)
                    }
                    .padding(10)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.35), lineWidth: 1))
                }
                switch model.pane {
                case .engines: EnginesPane(model: model)
                case .models: ModelsPane(model: model)
                case .server: ServerPane(model: model)
                case .speed: SpeedPane(model: model)
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
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
        .confirmationDialog("Purge de memória?", isPresented: $model.confirmPurge, titleVisibility: .visible) {
            Button("Purge", role: .destructive) { model.purge() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Derruba o servidor, solta pesos, KV cache e contexto, e pede ao macOS para liberar a memória inativa.")
        }
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
            context.fill(Path(CatGeometry.head(in: rect)), with: .color(.black))
            var whiskers = Path()
            for (start, end) in CatGeometry.whiskers(in: rect) {
                whiskers.move(to: start)
                whiskers.addLine(to: end)
            }
            context.stroke(whiskers, with: .color(.black), style: StrokeStyle(lineWidth: CatGeometry.whiskerWidth(for: size.width), lineCap: .round))
            context.fill(Path(CatGeometry.innerEarLeft(in: rect)), with: .color(.white))
            context.fill(Path(CatGeometry.innerEarRight(in: rect)), with: .color(.white))
            context.fill(Path(ellipseIn: CatGeometry.eyeLeft(in: rect)), with: .color(.white))
            context.fill(Path(ellipseIn: CatGeometry.eyeRight(in: rect)), with: .color(.white))
            context.fill(Path(ellipseIn: CatGeometry.pupilLeft(in: rect)), with: .color(.black))
            context.fill(Path(ellipseIn: CatGeometry.pupilRight(in: rect)), with: .color(.black))
        }
        .accessibilityLabel("Lulu")
    }
}

private struct EnginesPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Motores").font(.title2.weight(.semibold))
                Spacer()
                Button("Atualizar") { model.refreshEngines() }
            }
            ForEach(model.engines) { engine in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(engine.name).font(.headline)
                        Spacer()
                        Text(engine.installed ? (engine.managed ? "instalado" : "manual") : "ausente")
                            .font(.caption.weight(.semibold))
                    }
                    Text(engine.blurb).font(.callout).foregroundStyle(.secondary)
                    Text(engineLine(engine)).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                    HStack {
                        if engine.installed && engine.managed {
                            Button("Remover") { model.removeEngine(engine.id) }
                                .disabled(model.busyEngineID != nil)
                        } else if !engine.installed {
                            Button("Instalar") { model.installEngine(engine.id) }
                                .disabled(model.busyEngineID != nil)
                                .buttonStyle(.borderedProminent)
                                .tint(.primary)
                        }
                        if model.busyEngineID == engine.id {
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.18), lineWidth: 1))
            }
            logBox(model.operationText, empty: "A instalação e a remoção aparecem aqui.")
        }
    }

    private func engineLine(_ engine: EngineStatus) -> String {
        let version = engine.version.isEmpty ? "sem versão" : engine.version
        let size = engine.sizeBytes.map { Format.bytes($0) } ?? "medindo…"
        let binary = engine.binary.isEmpty ? "sem binário" : engine.binary
        return "\(version) · \(size) · \(binary)"
    }
}

private struct ModelsPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Modelos").font(.title2.weight(.semibold))
                keyCard
                downloadCard
                libraryCard
            }
        }
    }

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chave do Hugging Face").font(.headline)
            Text("Cole a chave que começa com hf_. Ela fica no Keychain e só sai no pedido de busca ou download.").font(.callout).foregroundStyle(.secondary)
            HStack {
                SecureField("hf_…", text: $model.tokenDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Guardar chave") { model.saveToken() }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                    .disabled(model.tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Apagar chave") { model.clearToken() }
            }
            Text(model.tokenNote).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.18), lineWidth: 1))
    }

    private var downloadCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Baixar do Hugging Face").font(.headline)
            HStack {
                TextField("organização/modelo ou um pedaço do nome", text: $model.repoQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.searchHub() }
                Button(model.searching ? "Buscando…" : "Buscar") { model.searchHub() }
                    .disabled(model.searching)
            }
            if !model.hubHits.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.hubHits) { hit in
                        Button {
                            model.repoQuery = hit.id
                            model.loadFiles(hit.id)
                        } label: {
                            HStack {
                                Text(hit.id).lineLimit(1)
                                Spacer()
                                Text("\(Format.tokens(hit.downloads)) downloads").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !model.listedRepo.isEmpty {
                Text(model.listedRepo).font(.caption.monospaced())
                Text(Hub.destination(repo: model.listedRepo, files: model.listedFiles).path).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach($model.listedFiles) { $file in
                            Toggle(isOn: $file.selected) {
                                HStack {
                                    Text(file.path).lineLimit(1)
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
                    Text(selectedSummary).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Baixar selecionados") { model.enqueueSelected() }
                        .buttonStyle(.borderedProminent)
                        .tint(.primary)
                }
            }
            if !model.jobs.isEmpty {
                Text("Downloads").font(.headline).padding(.top, 4)
                ForEach(model.jobs) { job in
                    jobRow(job)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.18), lineWidth: 1))
    }

    private var selectedSummary: String {
        let chosen = model.listedFiles.filter(\.selected)
        let bytes = chosen.reduce(Int64(0)) { $0 + max($1.size, 0) }
        return "\(chosen.count) arquivos · \(Format.bytes(UInt64(bytes)))"
    }

    private func jobRow(_ job: DownloadJob) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(job.repo).font(.callout.weight(.semibold)).lineLimit(1)
                Spacer()
                Text(job.state.rawValue).font(.caption)
            }
            ProgressView(value: progress(job))
                .tint(.primary)
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
                Text(error).font(.caption).foregroundStyle(.secondary)
            }
            Text(job.destination).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private func progress(_ job: DownloadJob) -> Double {
        guard job.total > 0 else { return job.state == .done ? 1 : 0 }
        return min(1, Double(job.received) / Double(job.total))
    }

    private var libraryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Na máquina").font(.headline)
                Spacer()
                Button("Atualizar") { Task { await model.rescanModels() } }
            }
            if model.models.isEmpty {
                Text("Nada em ~/models/mlx nem em ~/models/gguf.").foregroundStyle(.secondary)
            }
            ForEach(model.models) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).lineLimit(1)
                        Text("\(item.engineID) · \(Format.bytes(item.sizeBytes)) · \(item.arch?.summary ?? "KV desconhecido")")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button("Apagar") { model.deleteModel(item.id) }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.18), lineWidth: 1))
    }
}

private struct ServerPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Servidor").font(.title2.weight(.semibold))
                Spacer()
                Text(phaseLabel).font(.caption.weight(.semibold))
            }
            Picker("Modelo", selection: $model.selectedModelID) {
                if model.models.isEmpty {
                    Text("Nenhum modelo").tag("")
                }
                ForEach(model.models) { item in
                    Text("\(item.name)  \(item.engineID)  \(Format.bytes(item.sizeBytes))").tag(item.id)
                }
            }
            .disabled(model.phase == .starting || model.phase == .ready)
            .onChange(of: model.selectedModelID) { _, _ in model.persist() }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Contexto")
                    Spacer()
                    Text("\(Format.tokens(model.contextLength)) tokens").font(.caption.monospacedDigit())
                }
                Picker("Contexto", selection: $model.contextLength) {
                    ForEach(model.contextOptions, id: \.self) { value in
                        Text(Format.tokens(value)).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(model.phase == .starting || model.phase == .ready)
                .onChange(of: model.contextLength) { _, _ in model.persist() }
            }
            HStack {
                Text("Porta")
                TextField("Porta", value: $model.port, format: .number)
                    .frame(width: 80)
                    .disabled(model.phase == .starting || model.phase == .ready)
                    .onChange(of: model.port) { _, _ in model.persist() }
                Spacer()
            }
            if model.phase == .ready || model.phase == .starting {
                Button("Parar") { model.stopServer() }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
            } else {
                Button("Subir") { model.startServer() }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                    .disabled(model.models.isEmpty)
            }
            Text("llama.cpp sobe com flash attention, todas as camadas na GPU e threads dos núcleos de desempenho. O MLX limita o KV ao contexto escolhido.").font(.caption).foregroundStyle(.secondary)
            if model.phase == .ready || model.phase == .starting {
                HStack {
                    Text("http://127.0.0.1:\(model.port)/v1").font(.body.monospaced())
                    Spacer()
                    Button(model.copied ? "Copiado" : "Copiar") { model.copyEndpoint() }
                }
            }
            logBox(model.logText, empty: "O log do servidor aparece aqui.")
        }
    }

    private var phaseLabel: String {
        switch model.phase {
        case .stopped: return "parado"
        case .starting: return "subindo"
        case .ready: return "no ar"
        case .failed: return "falhou"
        }
    }
}

private struct SpeedPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let memory = model.memory
        VStack(alignment: .leading, spacing: 14) {
            Text("Desempenho").font(.title2.weight(.semibold))
            if model.phase == .ready {
                Text(Format.rate(memory.predictRate)).font(.system(size: 42, weight: .semibold, design: .rounded))
                Text("tokens por segundo na geração").font(.caption).foregroundStyle(.secondary)
            } else {
                Text(Format.bytes(memory.available)).font(.system(size: 42, weight: .semibold, design: .rounded))
                Text("memória disponível").font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                tile("Prompt", Format.rate(memory.promptRate) + " tok/s")
                tile("Processo", Format.bytes(memory.footprint))
                tile("Pesos", Format.bytes(memory.weights))
                tile("KV reservado", Format.bytes(memory.kvReserved))
                tile("KV em uso", Format.bytes(memory.kvUsed))
                tile("Contexto", contextLine(memory))
                tile("Total", Format.bytes(memory.total))
                tile("Disponível", Format.bytes(memory.available))
                tile("Wired", Format.bytes(memory.wired))
                tile("Comprimida", Format.bytes(memory.compressed))
                tile("Ativa", Format.bytes(memory.active))
                tile("Liberável", Format.bytes(memory.purgeable))
            }
            Meter(footprint: fraction(memory.footprint, memory.total), other: fraction(otherUsed(memory), memory.total))
            Text(memory.kvSummary).font(.caption).foregroundStyle(.secondary)
            Text("No llama.cpp o KV reservado entra na memória ao subir. O pico de contexto vem do contador do servidor. No MLX, em uso é o que o processo cresceu depois dos pesos.").font(.caption).foregroundStyle(.secondary)
            Button("Purge de memória") { model.confirmPurge = true }
                .buttonStyle(.borderedProminent)
                .tint(.primary)
        }
    }

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
                Rectangle().fill(Color.primary).frame(width: width * footprint)
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
        Text(title).font(.caption).foregroundStyle(.secondary)
        Text(value).font(.body.monospacedDigit().weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(8)
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.15), lineWidth: 1))
}

private func logBox(_ text: String, empty: String) -> some View {
    ScrollView {
        Text(text.isEmpty ? empty : text)
            .font(.system(size: 11, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .textSelection(.enabled)
    }
    .frame(height: 120)
    .background(Color.primary.opacity(0.04))
    .clipShape(RoundedRectangle(cornerRadius: 8))
}
