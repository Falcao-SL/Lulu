import SwiftUI
import AppKit

enum ModelSection: String, CaseIterable {
    case discover = "Discover"
    case library = "Library"
    case downloads = "Downloads"
}

struct ModelsPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.lg) {
            LuluPageHeader("Models", symbol: "square.stack.3d.up")
            Picker("Models", selection: $model.modelSection) {
                ForEach(ModelSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: LuluTheme.Space.lg) {
                        switch model.modelSection {
                        case .discover:
                            RecommendedModelsView(model: model).id("recommendations")
                            downloadCard.id("search")
                            DisclosureGroup("Hugging Face access · optional") {
                                keyCard.padding(.top, 8)
                            }
                        case .library: libraryCard
                        case .downloads: downloadQueue
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .id(model.modelSection)
                .onChange(of: model.listedRepo) { _, repo in
                    if model.modelSection == .discover && !repo.isEmpty { scroll.scrollTo("selection", anchor: .top) }
                }
                .onChange(of: model.recommendationsRequest) { _, _ in
                    scroll.scrollTo("recommendations", anchor: .top)
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
            DisclosureGroup("Search filters") {
                HStack {
                    TextField("Publisher / organization", text: $model.searchAuthor)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { model.searchHub() }
                    Picker("Format", selection: $model.searchFormat) {
                        Text("All").tag("")
                        Text("MLX").tag("mlx")
                        Text("GGUF").tag("gguf")
                    }
                    .frame(maxWidth: 180)
                    Picker("Sort", selection: $model.searchSort) {
                        Text("Downloads").tag("downloads")
                        Text("Likes").tag("likes")
                        Text("Recently updated").tag("lastModified")
                    }
                    .frame(maxWidth: 200)
                }
                .padding(.top, LuluTheme.Space.xs)
            }
            if model.searching { ProgressView("Searching Hugging Face…").controlSize(.small) }
            if model.searchFinished && model.listedRepo.isEmpty && model.hubHits.isEmpty && !model.searching {
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
                Label(model.listedRepo, luluSymbol: "folder").font(.headline).textSelection(.enabled).id("selection")
                if let hit = model.selectedHubHit { HubMetadataView(hit: hit) }
                if model.modelVariants.count > 1 {
                    Picker("Variant", selection: Binding(
                        get: { model.selectedVariant },
                        set: { model.selectVariant($0) }
                    )) {
                        Text("Custom selection").tag("")
                        ForEach(model.modelVariants, id: \.self) { variant in
                            Text(URL(fileURLWithPath: variant).lastPathComponent).tag(variant)
                        }
                    }
                }
                HStack {
                    Text(selectedSummary).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Download model") { model.enqueueSelected() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.hasDownloadableSelection)
                }
                if !model.hasDownloadableSelection {
                    Text("Choose a complete GGUF variant or MLX model.")
                        .font(LuluTheme.TypeStyle.caption)
                        .foregroundStyle(.secondary)
                }
                DisclosureGroup("Choose files manually") {
                    LazyVStack(alignment: .leading, spacing: LuluTheme.Space.xs) {
                        ForEach($model.listedFiles) { $file in
                            Toggle(isOn: $file.selected) {
                                HStack {
                                    Text(file.path).lineLimit(1).truncationMode(.middle).help(file.path)
                                    Spacer()
                                    Text(Format.bytes(UInt64(max(file.size, 0))))
                                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    .padding(.top, LuluTheme.Space.xs)
                }
            }
        }
        .padding(LuluTheme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .luluCard()
    }

    private var downloadQueue: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
            LuluSectionHeader("Download queue", symbol: "arrow.down.circle")
            if model.jobs.isEmpty {
                Text("Downloads appear here when you choose a model.")
                    .foregroundStyle(.secondary)
                Button("Browse models") { model.showModelRecommendations() }
            } else {
                ForEach(model.jobs) { job in
                    jobRow(job)
                    if job.id != model.jobs.last?.id { Divider() }
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
            if job.state != .done {
                ProgressView(value: progress(job))
                    .tint(LuluTheme.accent)
            }
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
                if job.state == .done, let item = model.downloadedModel(for: job) {
                    useButton(item)
                }
                Menu {
                    Button(job.state == .done ? "Clear from history" : "Remove download") {
                        model.removeDownload(job.id)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").accessibilityLabel("Download options")
                }
                .menuIndicator(.hidden)
                .fixedSize()
            }
            if let error = job.error, !error.isEmpty {
                Text(error).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
            }
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

    private func useButton(_ item: ModelItem) -> some View {
        let running = model.serverActive && model.runningModel?.id == item.id
        return Button(running ? "In use" : "Use model") { model.useModel(item) }
            .buttonStyle(.borderedProminent)
            .disabled(running || model.switchingModel)
            .help(model.serverActive && !running ? "Switch the local server to this model" : "Start the local server with this model")
    }

    private var libraryCard: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.sm) {
            HStack {
                LuluSectionHeader("Local library", symbol: "externaldrive")
                Spacer()
                Button("Refresh") { Task { await model.rescanModels() } }
            }
            if model.models.isEmpty {
                Label("Add a model to ~/models/mlx or ~/models/gguf, or browse the catalog.", luluSymbol: "folder")
                    .font(LuluTheme.TypeStyle.body).foregroundStyle(.secondary)
                Button("Browse models") { model.showModelRecommendations() }
            }
            ForEach(model.models) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).lineLimit(1)
                        Text("\(item.engineID) · \(Format.bytes(item.sizeBytes)) · \(item.arch?.summary ?? "KV metadata unavailable")")
                            .font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    useButton(item)
                    Menu {
                        Button("Delete", role: .destructive) { model.deleteModel(item.id) }
                    } label: {
                        Image(systemName: "ellipsis.circle").accessibilityLabel("Model options")
                    }
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
        }
        .padding(LuluTheme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .luluCard()
    }
}
