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
                Button("Lulu design guide") { openWindow(id: "design-guide") }
            }
        }

        Window("Lulu design guide", id: "design-guide") {
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
                        Text("Your AI, on this Mac").font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                VStack(spacing: LuluTheme.Space.xs) {
                    navigationItem("Overview", "square.grid.2x2", .overview)
                    navigationItem("Engines", "cpu", .engines)
                    navigationItem("Models", "square.and.arrow.down", .models)
                    navigationItem("Server", "server.rack", .server)
                    navigationItem("Performance", "gauge.with.dots.needle.67percent", .speed)
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
                        Button("Close") { model.banner = nil }.buttonStyle(.borderless)
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
        .confirmationDialog("Remove this engine?", isPresented: removeShown, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { model.confirmEngineRemoval() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The engine will be removed. Models in ~/models will remain.")
        }
        .confirmationDialog("Delete this model?", isPresented: deleteShown, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { model.confirmModelDeletion() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The files will be removed from ~/models. A partial download can also be removed from the queue.")
        }
        .sheet(item: $model.configuredNotice) { notice in
            ConfiguredSheet(notice: notice)
        }
        .confirmationDialog("Purge memory?", isPresented: $model.confirmPurge, titleVisibility: .visible) {
            Button("Purge", role: .destructive) { model.purge() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Stops the server, releases model weights and KV cache, and asks macOS to purge inactive memory.")
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

private struct ModelsPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LuluTheme.Space.lg) {
                LuluPageHeader("Models", symbol: "square.stack.3d.up")
                libraryCard
                downloadCard
                DisclosureGroup("Hugging Face access · optional") {
                    keyCard.padding(.top, 8)
                }
            }
        }
        .onChange(of: model.repoQuery) { _, _ in model.showAllHubResults = false }
    }

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.sm) {
            LuluSectionHeader("Hugging Face token", symbol: "key")
            Text("Enter your hf_ token. It is stored in Keychain and sent only for search and downloads.").font(.callout).foregroundStyle(.secondary)
            HStack {
                SecureField("hf_…", text: $model.tokenDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Save token") { model.saveToken() }
                    .buttonStyle(.borderedProminent)
                    .tint(LuluTheme.accent)
                    .disabled(model.tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Delete token") { model.clearToken() }
            }
            Text(model.tokenNote).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
        }
        .padding(LuluTheme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .luluCard()
    }

    private var downloadCard: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.sm) {
            LuluSectionHeader("Explore models", symbol: "magnifyingglass")
            HStack {
                TextField("organization/model or part of a name", text: $model.repoQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.searchHub() }
                Button(model.searching ? "Searching…" : "Search") {
                    model.showAllHubResults = false
                    model.searchHub()
                }
                    .disabled(model.searching)
            }
            HStack {
                TextField("Publisher / organization", text: $model.searchAuthor)
                    .textFieldStyle(.roundedBorder).onSubmit { model.searchHub() }
                Picker("Format", selection: $model.searchFormat) {
                    Text("All").tag("")
                    Text("MLX").tag("mlx")
                    Text("GGUF").tag("gguf")
                }.frame(maxWidth: 180)
                Picker("Sort", selection: $model.searchSort) {
                    Text("Downloads").tag("downloads")
                    Text("Likes").tag("likes")
                    Text("Recently updated").tag("lastModified")
                }.frame(maxWidth: 200)
            }
            Text("Search applies the filters and returns up to 40 results. Quantization is inferred from the name and tags; the lab comes from the base model.")
                .font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
            if model.searching { ProgressView("Searching Hugging Face…").controlSize(.small) }
            if model.searchFinished && model.hubHits.isEmpty && !model.searching {
                Label("No results. Try another name, publisher or format.", luluSymbol: "magnifyingglass")
                    .foregroundStyle(.secondary).padding(.vertical, 12)
            }
            if !model.hubHits.isEmpty {
                Text("\(model.hubHits.count) results").font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(model.showAllHubResults ? model.hubHits : Array(model.hubHits.prefix(6))) { hit in
                        HubResultView(hit: hit, selected: model.selectedHubHit?.id == hit.id && model.listedRepo == hit.id) {
                            model.selectedHubHit = hit
                            model.loadFiles(hit.id)
                        }
                    }
                    if model.hubHits.count > 6 {
                        Button(model.showAllHubResults ? "Show fewer results" : "Show all \(model.hubHits.count) results") {
                            model.showAllHubResults.toggle()
                        }
                        .buttonStyle(.bordered)
                    }
                }.padding(2)
            }
            if !model.listedRepo.isEmpty {
                Divider().padding(.vertical, 8)
                Label(model.listedRepo, luluSymbol: "folder").font(.headline).textSelection(.enabled)
                if let hit = model.selectedHubHit { HubMetadataView(hit: hit) }
                Text("Select files · quantization is inferred from the file name when available.")
                    .font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                Text(Hub.destination(repo: model.listedRepo, files: model.listedFiles).path).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary).lineLimit(1)
                LazyVStack(alignment: .leading, spacing: LuluTheme.Space.xs) {
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
                HStack {
                    Text(selectedSummary).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Download selected") { model.enqueueSelected() }
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
        return "\(chosen.count) files · \(Format.bytes(UInt64(bytes)))"
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
                    Button("Pause") { model.pauseDownload(job.id) }
                }
                if job.state == .paused || job.state == .failed {
                    Button("Resume") { model.resumeDownload(job.id) }
                }
                Button("Remove") { model.removeDownload(job.id) }
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
        case .queued: LuluStatusBadge("Queued", tone: .neutral)
        case .running: LuluStatusBadge("Downloading", tone: .info)
        case .paused: LuluStatusBadge("Paused", tone: .warning)
        case .failed: LuluStatusBadge("Failed", tone: .danger)
        case .done: LuluStatusBadge("Completed", tone: .success)
        }
    }

    private func progress(_ job: DownloadJob) -> Double {
        guard job.total > 0 else { return job.state == .done ? 1 : 0 }
        return min(1, Double(job.received) / Double(job.total))
    }

    private var libraryCard: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.sm) {
            HStack {
                LuluSectionHeader("Local library", symbol: "externaldrive")
                Spacer()
                Button("Refresh") { Task { await model.rescanModels() } }
            }
            if model.models.isEmpty {
                Label("Add a model to ~/models/mlx or ~/models/gguf, or download one below.", luluSymbol: "folder")
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
                    Button("Delete", role: .destructive) { model.deleteModel(item.id) }
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
                LuluPageHeader("Server", symbol: "server.rack")
                Spacer()
                LuluStatusBadge(phaseLabel, tone: phaseTone)
            }
            VStack(alignment: .leading, spacing: LuluTheme.Space.lg) {
                Picker("Model", selection: $model.selectedModelID) {
                    if model.models.isEmpty { Text("No model").tag("") }
                    ForEach(model.models) { item in
                        Text("\(item.name) · \(item.engineID) · \(Format.bytes(item.sizeBytes))").tag(item.id)
                    }
                }
                .disabled(serverActive)
                .onChange(of: model.selectedModelID) { _, _ in model.persist() }

                VStack(alignment: .leading, spacing: LuluTheme.Space.sm) {
                    HStack {
                        Text("Context")
                        Spacer()
                        Text("\(Format.tokens(model.contextLength)) tokens")
                            .font(LuluTheme.TypeStyle.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Picker("Context", selection: $model.contextLength) {
                        ForEach(model.supportedContextOptions, id: \.self) { value in
                            Text(contextOption(value)).tag(value)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Context")
                    .pickerStyle(.menu)
                    .disabled(serverActive)
                    .onChange(of: model.contextLength) { _, _ in model.persist() }
                    HStack(spacing: LuluTheme.Space.md) {
                        LuluGlyph("memorychip").foregroundStyle(LuluTheme.accent)
                        VStack(alignment: .leading, spacing: LuluTheme.Space.xs) {
                            Text("Model maximum").font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                            Text(model.selectedContextLimit.map { Format.tokens($0) + " tokens" } ?? "Not provided in local files")
                                .font(LuluTheme.TypeStyle.section).monospacedDigit()
                        }
                        Spacer()
                        if let maximum = model.selectedContextLimit {
                            LuluStatusBadge(model.contextLength > maximum ? "Above limit" : "Within limit",
                                            tone: model.contextLength > maximum ? .warning : .success)
                        }
                    }
                    .padding(LuluTheme.Space.md)
                    .background(LuluTheme.subtle, in: RoundedRectangle(cornerRadius: LuluTheme.Radius.control))
                    Text(model.selectedContextLimit == nil
                         ? "Without context metadata, Lulu cannot validate this model’s maximum."
                         : "The limit comes from local metadata. The menu offers values within the model limit.")
                        .font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)

                }

                contextMemory

                HStack {
                    Text("Port")
                    TextField("Port", value: $model.port, format: .number.grouping(.never))
                        .frame(width: 74)
                        .disabled(serverActive)
                        .onChange(of: model.port) { _, _ in model.persist() }
                    Spacer()
                    if serverActive {
                        Button("Stop server", luluSymbol: "stop.fill") { model.stopServer() }
                            .buttonStyle(.bordered)
                    } else {
                        Button("Start server", luluSymbol: "play.fill") { model.startServer() }
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
                    Button(model.copied ? "Copied" : "Copy", luluSymbol: model.copied ? "checkmark" : "doc.on.doc") {
                        model.copyEndpoint()
                    }
                }
            }
            .padding(LuluTheme.Space.lg)
            .luluCard()

            ClientRack(model: model)

            if !serverActive && model.models.isEmpty {
                Button("Choose a model", luluSymbol: "square.stack.3d.up") { model.pane = .models }
            }
            DisclosureGroup("Server logs") {
                logBox(model.logText, empty: "Server logs appear here.")
            }
        }
    }

    private var selectedModel: ModelItem? {
        model.models.first { $0.id == model.selectedModelID }
    }

    private var kvEstimate: UInt64? {
        guard let bytes = selectedModel?.arch?.kvBytes(tokens: model.contextLength), bytes > 0 else { return nil }
        return bytes
    }

    private func contextOption(_ tokens: Int) -> String {
        let label = tokens == 1048576 ? "1M · 1.048.576 tokens" : "\(tokens / 1024)K · \(Format.tokens(tokens)) tokens"
        guard let bytes = selectedModel?.arch?.kvBytes(tokens: tokens), bytes > 0 else { return label }
        return label + " · KV ≈ " + Format.bytes(bytes)
    }

    private var contextMemory: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
            LuluSectionHeader("Memory for this context", symbol: "memorychip")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: LuluTheme.Space.md)], spacing: LuluTheme.Space.md) {
                LuluMetric("Weights · disk size", value: selectedModel.map { Format.bytes($0.sizeBytes) } ?? "—", symbol: "cube")
                LuluMetric("Estimated KV cache", value: kvEstimate.map(Format.bytes) ?? "—", symbol: "memorychip")
                LuluMetric("Weights + KV · estimate", value: subtotalEstimate, symbol: "layers")
            }
            Text(kvEstimate == nil
                 ? "KV metadata is unavailable for this model. Actual usage appears in Performance after starting the server."
                 : "The subtotal combines disk weights and estimated KV cache. Buffers, multimodal projectors and engine allocations may increase usage. See Performance for actual usage.")
                .font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
        }
    }

    private var subtotalEstimate: String {
        guard let selectedModel, let kvEstimate else { return "—" }
        let (total, overflow) = selectedModel.sizeBytes.addingReportingOverflow(kvEstimate)
        return overflow ? "—" : "≈ " + Format.bytes(total)
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
        case .stopped: return "Stopped"
        case .starting: return "Starting"
        case .ready: return "Available"
        case .failed: return "Failed"
        }
    }
}

private struct SpeedPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let memory = model.memory
        VStack(alignment: .leading, spacing: LuluTheme.Space.lg) {
            LuluPageHeader("Performance", symbol: "gauge.with.dots.needle.67percent")
            VStack(alignment: .leading, spacing: LuluTheme.Space.xs) {
                if model.phase == .ready {
                    Text(Format.rate(memory.predictRate)).font(LuluTheme.TypeStyle.metric)
                    Text("tokens per second during generation").font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                } else {
                    Text(memory.total == 0 ? "—" : Format.bytes(memory.available)).font(LuluTheme.TypeStyle.metric)
                    Text("available memory").font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                }
            }.accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
                LuluSectionHeader("Server process", symbol: "server.rack")
                LazyVGrid(columns: columns, alignment: .leading, spacing: LuluTheme.Space.lg) {
                    tile("Prompt", Format.rate(memory.promptRate) + " tok/s")
                    tile("Process", Format.bytes(memory.footprint))
                    tile("Weights", Format.bytes(memory.weights))
                    tile("KV reserved", Format.bytes(memory.kvReserved))
                    tile("KV used", Format.bytes(memory.kvUsed))
                    tile("Context", contextLine(memory))
                }
                Text(memory.kvSummary).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
            }
            .padding(LuluTheme.Space.lg).luluCard()

            VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
                LuluSectionHeader("Mac memory", symbol: "memorychip")
                LazyVGrid(columns: columns, alignment: .leading, spacing: LuluTheme.Space.lg) {
                    tile("Total", Format.bytes(memory.total))
                    tile("Available", Format.bytes(memory.available))
                    tile("Wired", Format.bytes(memory.wired))
                    tile("Compressed", Format.bytes(memory.compressed))
                    tile("Active", Format.bytes(memory.active))
                    tile("Purgeable", Format.bytes(memory.purgeable))
                }
                Meter(footprint: fraction(memory.footprint, memory.total), other: fraction(otherUsed(memory), memory.total))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), alignment: .leading)], alignment: .leading, spacing: LuluTheme.Space.md) {
                    memoryLegend("Server", value: memory.footprint, color: Meter.serverColor)
                    memoryLegend("Other processes", value: otherUsed(memory), color: Meter.otherColor)
                    memoryLegend("Available", value: memory.available, color: Meter.availableColor)
                }
                .font(LuluTheme.TypeStyle.caption)
                HStack {
                    Spacer(minLength: 0)
                    Button("Purge memory", luluSymbol: "sparkles") { model.confirmPurge = true }
                }
            }
            .padding(LuluTheme.Space.lg).luluCard()

            Text("llama.cpp reserves KV cache at startup. For MLX, used KV estimates process growth after loading weights.")
                .font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3)

    private func memoryLegend(_ title: String, value: UInt64, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.primary.opacity(0.18)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.secondary).lineLimit(1)
                Text(Format.bytes(value)).font(.body.monospacedDigit().weight(.semibold))
            }
        }
        .accessibilityElement(children: .combine)
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
    static let serverColor = LuluTheme.accent
    static let otherColor = LuluTheme.accent.opacity(0.38)
    static let availableColor = LuluTheme.accent.opacity(0.10)
    var footprint: Double
    var other: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            HStack(spacing: 0) {
                Rectangle().fill(Self.serverColor).frame(width: width * footprint)
                Rectangle().fill(Self.otherColor).frame(width: width * min(other, max(0, 1 - footprint)))
                Rectangle().fill(Self.availableColor)
            }
        }
        .frame(height: 14)
        .clipShape(RoundedRectangle(cornerRadius: 7))
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
