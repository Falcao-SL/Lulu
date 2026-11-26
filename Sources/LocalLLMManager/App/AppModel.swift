import AppKit
import Foundation
import Darwin

enum Pane: String, CaseIterable, Hashable {
    case overview, engines, models, server, speed
}

@MainActor
final class AppModel: ObservableObject {
    @Published var pane: Pane = .overview {
        didSet {
            if pane != oldValue {
                configureMonitor()
                tick()
            }
        }
    }
    @Published var engines: [EngineStatus] = []
    @Published var models: [ModelItem] = []
    @Published var jobs: [DownloadJob] = []
    @Published var hubHits: [HubHit] = []
    @Published var listedFiles: [ListedFile] = []
    @Published var listedRepo = ""
    @Published var repoQuery = ""
    @Published var modelSection: ModelSection = .discover
    @Published private(set) var recommendationsRequest: UUID?
    @Published var tokenDraft = ""
    @Published var tokenNote = ""
    @Published var copiedEngineCommand: String?
    @Published var searchAuthor = ""
    @Published var searchFormat = ""
    @Published var searchSort = "downloads"
    @Published var searchFinished = false
    @Published var showAllHubResults = false
    @Published var selectedHubHit: HubHit?
    private var hubRequestID = UUID()
    private var scanRequestID = UUID()
    @Published var searching = false
    @Published var selectedModelID = "" {
        didSet { normalizeContext() }
    }
    @Published var contextLength = 8192
    @Published var port = 8000
    @Published var phase: ServerPhase = .stopped {
        didSet {
            guard phase != oldValue else { return }
            configureMonitor()
            if !serverActive && pane == .server && showServerLogs { refreshLog() }
        }
    }
    @Published var runningModel: ModelItem?
    @Published var memory = MemorySnapshot()
    @Published var logText = ""
    @Published var showServerLogs = false {
        didSet { if showServerLogs { refreshLog() } }
    }
    @Published var operationText = ""
    @Published var banner: String?
    @Published var configuredNotice: ClientNotice?
    @Published var busyEngineID: String?
    @Published var downloadSpeed: Double = 0
    @Published var confirmRemoveEngine: String?
    @Published var confirmDeleteModel: String?
    @Published var confirmPurge = false
    @Published var copied = false
    @Published var accessKey = ""
    @Published var accessKeyVisible = false
    @Published var accessKeyCopied = false
    @Published var updateVersion: String?
    @Published var updateURL: URL?
    @Published var checkingUpdate = false

    @Published private(set) var switchingModel = false
    @Published private(set) var purgingMemory = false
    @Published private(set) var configuringClient: ClientID?

    var serverActive: Bool { phase == .starting || phase == .ready }
    var modelVariants: [String] { Hub.variants(listedFiles) }
    var selectedVariant: String {
        let selected = Hub.variants(listedFiles.filter(\.selected))
        return selected.count == 1 ? selected[0] : ""
    }
    var hasDownloadableSelection: Bool { Hub.isDownloadable(listedFiles) }

    func selectVariant(_ variant: String) {
        guard !variant.isEmpty else { return }
        listedFiles = Hub.choosing(variant, in: listedFiles)
    }

    func downloadedModel(for job: DownloadJob) -> ModelItem? {
        guard job.state == .done else { return nil }
        let root = URL(fileURLWithPath: job.destination).standardizedFileURL
        let paths = Set(job.files.filter(\.done).map {
            root.appendingPathComponent($0.path).standardizedFileURL.path
        })
        return models.first { item in
            let path = URL(fileURLWithPath: item.path).standardizedFileURL.path
            return item.engineID == "llama.cpp" ? paths.contains(path) : path == root.path
        }
    }

    @discardableResult
    func useModel(_ item: ModelItem, context: Int? = nil) -> Bool {
        guard !purgingMemory else {
            banner = "Wait for memory purge to finish before loading a model."
            return false
        }
        guard !switchingModel, models.contains(where: { $0.id == item.id }) else { return false }
        guard engines.contains(where: { $0.id == item.engineID && $0.installed && !$0.binary.isEmpty }) else {
            banner = "Install \(item.engineID) to use \(item.name)."
            pane = .engines
            return false
        }
        let desiredContext = ContextPolicy.clamped(context ?? contextLength, declared: item.arch?.trainedContext)
        if serverActive && runningModel?.id == item.id && desiredContext == contextLength {
            pane = .server
            return true
        }

        pane = .server
        if serverActive {
            switchingModel = true
            let pid = releaseServer()
            Task {
                await Task.detached { MemoryMonitor.terminate(pid) }.value
                switchingModel = false
                launch(item, context: desiredContext)
            }
            return true
        }
        launch(item, context: desiredContext)
        return serverActive
    }

    private func launch(_ item: ModelItem, context: Int) {
        selectedModelID = item.id
        contextLength = context
        persist()
        startServer()
    }

    let contextOptions = [2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288, 1048576]
    var selectedContextLimit: Int? {
        ContextPolicy.limit(models.first { $0.id == selectedModelID }?.arch?.trainedContext)
    }

    var supportedContextOptions: [Int] {
        var options = ContextPolicy.options(presets: contextOptions, declared: selectedContextLimit)
        if phase == .ready || phase == .starting, !options.contains(contextLength) {
            options.append(contextLength)
            options.sort()
        }
        return options
    }

    private func normalizeContext() {
        guard phase == .stopped || phase == .failed else { return }
        let value = ContextPolicy.clamped(contextLength, declared: selectedContextLimit)
        if value != contextLength { contextLength = value }
    }

    private let transfers = HFTransfers()
    private var serverProcess: Process?
    private var serverPID: pid_t = 0
    private var expectExit = false
    private var baseline: UInt64?
    private var probeInFlight = false
    private var metricsVisible: Bool { monitoringActive && (pane == .overview || pane == .speed) }
    private var sizing = false
    private var speedMark: (time: CFAbsoluteTime, bytes: Int64)?
    private var activeJob: UUID?
    private var timer: Timer?
    private var webChatInputs = ChatInputCapabilities()
    private lazy var webChat = WebChatServer(status: { [weak self] in
        self?.webChatStatus() ?? WebChatStatus(model: nil, selection: nil, ready: false, message: "Open Lulu to connect.")
    }, endpoint: { [weak self] in
        guard let self else { throw LocalChatEndpoint.Failure(message: "Open Lulu to connect.") }
        return try await self.localChatEndpoint()
    })

    init() {
        let defaults = UserDefaults.standard
        selectedModelID = defaults.string(forKey: "lulu.model") ?? ""
        let storedContext = defaults.integer(forKey: "lulu.context")
        if storedContext > 0 { contextLength = storedContext }
        let storedPort = defaults.integer(forKey: "lulu.port")
        if storedPort > 0 { port = storedPort }
        jobs = DownloadStore.load()
        refreshTokenNote()
        accessKey = AccessKeyStore.ensure()
        transfers.onEvent = { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        refreshEngines()
        Task { await rescanModels() }
        configureMonitor()
        tick()
        #if canImport(Sparkle)
        _ = SparkleUpdates.shared
        #endif
        checkForUpdates()
    }

    func checkForUpdates(showFeedback: Bool = false) {
        guard !checkingUpdate else { return }
        checkingUpdate = true
        Task { [weak self] in
            do {
                let release = try await AppUpdates.latest()
                guard let self else { return }
                self.updateVersion = release?.version
                self.updateURL = release?.download
                self.checkingUpdate = false
                if showFeedback && release == nil { self.banner = "Lulu is up to date." }
            } catch {
                guard let self else { return }
                self.checkingUpdate = false
                if showFeedback { self.banner = "Could not check for updates. Please try again." }
            }
        }
    }

    func downloadUpdate() {
        guard let url = updateURL else { return }
        #if canImport(Sparkle)
        SparkleUpdates.shared.checkForUpdates()
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    private var monitoringActive = true
    private var monitorInterval: TimeInterval = 0

    func setMonitoringActive(_ active: Bool) {
        guard monitoringActive != active else { return }
        monitoringActive = active
        configureMonitor()
        if active { tick() }
    }

    private func configureMonitor() {
        let interval: TimeInterval
        switch phase {
        case .starting: interval = 1
        case .ready: interval = metricsVisible ? 1 : monitoringActive && pane == .server ? 2 : 10
        case .stopped, .failed: interval = metricsVisible ? 5 : 0
        }
        guard interval != monitorInterval else { return }
        timer?.invalidate()
        timer = nil
        monitorInterval = interval
        guard interval > 0 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer?.tolerance = interval * 0.15
    }

    deinit {
        timer?.invalidate()
    }

    func refreshTokenNote() {
        if !TokenStore.load().isEmpty {
            tokenNote = "Token saved in this Mac’s Keychain."
        } else if let env = ProcessInfo.processInfo.environment["HF_TOKEN"] ?? ProcessInfo.processInfo.environment["HUGGING_FACE_HUB_TOKEN"], !env.isEmpty {
            tokenNote = "No saved token. Requests use HF_TOKEN from the environment."
        } else {
            tokenNote = "No token saved. Public models can still be downloaded."
        }
    }

    func saveToken() {
        let trimmed = tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            banner = "Enter a token before saving."
            return
        }
        TokenStore.save(trimmed)
        tokenDraft = ""
        refreshTokenNote()
        banner = "Hugging Face token saved in Keychain."
    }

    func clearToken() {
        TokenStore.save("")
        tokenDraft = ""
        refreshTokenNote()
        banner = "Token removed from this Mac."
    }

    func refreshEngines() {
        engines = EngineCatalog.quick()
        guard !sizing else { return }
        sizing = true
        Task {
            let sized = await Task.detached(priority: .utility) { EngineCatalog.measured() }.value
            engines = sized
            sizing = false
        }
    }

    func installEngine(_ id: String) {
        runEngineCommand(id, installing: true)
    }

    func removeEngine(_ id: String) {
        confirmRemoveEngine = id
    }

    func confirmEngineRemoval() {
        guard let id = confirmRemoveEngine else { return }
        confirmRemoveEngine = nil
        runEngineCommand(id, installing: false)
    }

    func rescanModels() async {
        let requestID = UUID()
        scanRequestID = requestID
        let found = await Task.detached(priority: .utility) { ModelScan.all() }.value
        guard scanRequestID == requestID else { return }
        models = found
        if !models.contains(where: { $0.id == selectedModelID }) {
            selectedModelID = models.first?.id ?? ""
        }
        adoptSession()
        normalizeContext()
        persist()
    }

    func deleteModel(_ id: String) {
        confirmDeleteModel = id
    }

    func confirmModelDeletion() {
        guard let id = confirmDeleteModel, let model = models.first(where: { $0.id == id }) else {
            confirmDeleteModel = nil
            return
        }
        confirmDeleteModel = nil
        if runningModel?.path == model.path, phase != .stopped {
            banner = "Stop the server before deleting this model."
            return
        }
        let root = LuluPaths.models.resolvingSymlinksInPath().path
        let target = URL(fileURLWithPath: model.path).resolvingSymlinksInPath().path
        guard target.hasPrefix(root + "/") else { return }
        if jobs.contains(where: { $0.state == .running && target.hasPrefix($0.destination) }) {
            banner = "Pause this model’s download before deleting it."
            return
        }
        do {
            try FileManager.default.removeItem(atPath: target)
            if model.engineID == "llama.cpp", let projector = model.mmproj {
                let folder = URL(fileURLWithPath: model.path).deletingLastPathComponent()
                let others = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?.filter {
                    $0.pathExtension.lowercased() == "gguf" && !$0.lastPathComponent.lowercased().hasPrefix("mmproj")
                } ?? []
                if others.isEmpty {
                    try? FileManager.default.removeItem(atPath: projector)
                }
            }
        } catch {
            banner = error.localizedDescription
            return
        }
        Task { await rescanModels() }
    }

    func browseRecommendation(_ repo: String) {
        repoQuery = repo
        showModels(.discover)
        searchHub()
    }

    func showModels(_ section: ModelSection) {
        modelSection = section
        pane = .models
    }

    func showModelRecommendations() {
        showModels(.discover)
        recommendationsRequest = UUID()
    }

    func browseRecommendation(_ choice: TrayRecommendation) {
        repoQuery = choice.repo
        showModels(.discover)
        selectedHubHit = nil
        hubHits = []
        loadFiles(choice.repo, recommendation: choice)
    }

    func searchHub() {
        showAllHubResults = false
        let query = repoQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty || !searchAuthor.isEmpty || !searchFormat.isEmpty else { return }
        if let repo = Hub.parseRepo(query) {
            selectedHubHit = nil
            hubHits = []
            loadFiles(repo)
            return
        }
        let requestID = UUID()
        hubRequestID = requestID
        searching = true
        searchFinished = false
        listedRepo = ""
        listedFiles = []
        selectedHubHit = nil
        hubHits = []
        banner = nil
        let token = TokenStore.effective()
        let author = searchAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        let format = searchFormat
        let sort = searchSort
        Task {
            do {
                let hits = try await Hub.search(query, author: author, format: format, sort: sort, token: token)
                guard hubRequestID == requestID else { return }
                hubHits = hits
                searchFinished = true
                searching = false
                if hubHits.isEmpty { banner = "No models found." }
            } catch let error as HubError {
                guard hubRequestID == requestID else { return }
                searching = false
                banner = error.message
            } catch {
                guard hubRequestID == requestID else { return }
                searching = false
                banner = error.localizedDescription
            }
        }
    }

    func loadFiles(_ repo: String, recommendation: TrayRecommendation? = nil) {
        let requestID = UUID()
        hubRequestID = requestID
        listedRepo = ""
        listedFiles = []
        searchFinished = false
        searching = true
        banner = nil
        let token = TokenStore.effective()
        Task {
            do {
                async let metadata = try? Hub.metadata(repo: repo, token: token)
                let files = try await Hub.files(repo: repo, token: token)
                guard hubRequestID == requestID else { return }
                listedFiles = try recommendation?.selectFiles(files) ?? files
                listedRepo = repo
                searching = false
                if listedFiles.isEmpty { banner = "This repository returned no files." }
                let details = await metadata
                guard hubRequestID == requestID else { return }
                selectedHubHit = details ?? selectedHubHit
            } catch let error as HubError {
                guard hubRequestID == requestID else { return }
                searching = false
                banner = error.message
            } catch {
                guard hubRequestID == requestID else { return }
                searching = false
                banner = error.localizedDescription
            }
        }
    }

    func enqueueSelected() {
        guard !listedRepo.isEmpty, hasDownloadableSelection else {
            banner = "Choose a complete GGUF variant or MLX model."
            return
        }
        guard enqueueDownload(repo: listedRepo, files: listedFiles) else { return }
        modelSection = .downloads
        hubRequestID = UUID()
        listedRepo = ""
        listedFiles = []
        selectedHubHit = nil
        hubHits = []
        searchFinished = false
        banner = nil
    }

    @discardableResult
    func enqueueDownload(repo: String, files: [ListedFile]) -> Bool {
        guard Hub.parseRepo(repo) == repo, Hub.isDownloadable(files) else {
            banner = "Choose a complete model before downloading."
            return false
        }
        let chosen = files.filter(\.selected)
        let destination = Hub.destination(repo: repo, files: chosen)
        if jobs.contains(where: { $0.destination == destination.path && $0.state != .done }) {
            banner = "A download already exists for this folder. Resume it or remove it before starting another."
            return false
        }
        jobs.append(DownloadJob(
            id: UUID(), repo: repo, destination: destination.path,
            files: chosen.map { DownloadPart(path: $0.path, size: $0.size, received: 0, done: false) },
            state: .queued, error: nil
        ))
        persistDownloads()
        pump()
        return true
    }

    func repository(for item: ModelItem) -> String? {
        let path = URL(fileURLWithPath: item.path).standardizedFileURL.path
        return jobs.last { job in
            guard job.state == .done, Hub.parseRepo(job.repo) == job.repo else { return false }
            let folder = URL(fileURLWithPath: job.destination).standardizedFileURL
            if item.engineID != "llama.cpp" { return path == folder.path }
            return job.files.contains {
                $0.done && folder.appendingPathComponent($0.path).standardizedFileURL.path == path
            }
        }?.repo
    }

    func pauseDownload(_ id: UUID) {
        if activeJob == id, transfers.busy {
            transfers.pause()
            return
        }
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].state = .paused
        persistDownloads()
    }

    func resumeDownload(_ id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].state = .queued
        jobs[index].error = nil
        persistDownloads()
        pump()
    }

    func removeDownload(_ id: UUID) {
        guard let job = jobs.first(where: { $0.id == id }) else { return }
        if activeJob == id { transfers.pause() }
        let root = URL(fileURLWithPath: job.destination)
        for file in job.files where !file.done {
            try? FileManager.default.removeItem(at: root.appendingPathComponent(file.path).appendingPathExtension("incomplete"))
        }
        jobs.removeAll { $0.id == id }
        if activeJob == id { activeJob = nil }
        persistDownloads()
    }

    func startServer() {
        guard !purgingMemory else {
            banner = "Wait for memory purge to finish before starting the server."
            return
        }
        guard !switchingModel, phase == .stopped || phase == .failed else { return }
        guard let model = models.first(where: { $0.id == selectedModelID }) else {
            banner = "Choose a model."
            return
        }
        guard Machine.supportsMLX || model.engineID == "llama.cpp" else {
            banner = "MLX models require Apple silicon. On Intel Macs, use GGUF with llama.cpp."
            return
        }
        guard contextLength > 0 else {
            banner = "Choose a context greater than zero."
            return
        }
        if let limit = selectedContextLimit, contextLength > limit {
            banner = "This model reports a maximum of \(Format.tokens(limit)) tokens. Adjust the context before starting."
            return
        }
        guard let engine = engines.first(where: { $0.id == model.engineID }), engine.installed, !engine.binary.isEmpty else {
            banner = "The \(model.engineID) engine is not installed."
            pane = .engines
            return
        }
        port = min(max(port, 1), 65535)
        let cores = Machine.performanceCores
        var arguments: [String]
        switch model.engineID {
        case "mlx-lm":
            arguments = ["--model", model.path, "--host", "127.0.0.1", "--port", String(port)]
            if let bytes = model.arch?.kvBytes(tokens: contextLength), bytes > 0 {
                arguments += ["--prompt-cache-bytes", String(bytes)]
            }
        case "mlx-vlm":
            arguments = ["--model", model.path, "--host", "127.0.0.1", "--port", String(port), "--max-kv-size", String(contextLength)]
        default:
            arguments = ["-m", model.path, "--host", "127.0.0.1", "--port", String(port), "-ngl", "99", "-c", String(contextLength), "-t", String(cores), "-tb", String(cores), "--flash-attn", "on", "--metrics", "--api-key", AccessKeyStore.ensure()]
            if let projector = model.mmproj {
                arguments += ["--mmproj", projector]
            }
        }
        FileManager.default.createFile(atPath: LuluPaths.log.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: LuluPaths.log) else { return }
        let header = "# \(engine.binary) \(arguments.joined(separator: " "))\n"
        try? handle.write(contentsOf: Data(header.utf8))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: engine.binary)
        process.arguments = arguments
        process.qualityOfService = .userInitiated
        process.standardOutput = handle
        process.standardError = handle
        do {
            try process.run()
        } catch {
            banner = error.localizedDescription
            phase = .failed
            return
        }
        serverProcess = process
        serverPID = process.processIdentifier
        expectExit = false
        runningModel = model
        phase = .starting
        baseline = nil
        banner = nil
        let session = Session(pid: serverPID, port: port, modelPath: model.path, engineID: model.engineID, context: contextLength)
        if let data = try? JSONEncoder().encode(session) {
            try? data.write(to: LuluPaths.session)
        }
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard let self else { return }
                if self.expectExit || self.serverPID != process.processIdentifier { return }
                self.serverPID = 0
                self.phase = .failed
                self.banner = "The engine exited with code \(process.terminationStatus)."
            }
        }
        persist()
    }

    func stopServer() {
        guard !switchingModel else { return }
        let pid = releaseServer()
        guard pid > 0 else { return }
        switchingModel = true
        Task {
            await Task.detached { MemoryMonitor.terminate(pid) }.value
            switchingModel = false
        }
    }

    func purge(onFinish: ((String) -> Void)? = nil) {
        guard !switchingModel, !purgingMemory else { return }
        purgingMemory = true
        let before = MemoryMonitor.system().available
        let pid = releaseServer()
        Task {
            let (code, after) = await Task.detached {
                if pid > 0 { MemoryMonitor.terminate(pid) }
                let code = Shell.run(
                    executable: "/usr/bin/osascript",
                    arguments: ["-e", "do shell script \"/usr/sbin/purge\" with administrator privileges"]
                ) { _ in }
                return (code, MemoryMonitor.system().available)
            }.value
            purgingMemory = false
            tick()
            let message: String
            if code == 0 {
                message = "Purge complete. Available memory changed from \(Format.bytes(before)) to \(Format.bytes(after))."
            } else if pid > 0 {
                message = "Server stopped. System purge was canceled."
            } else {
                message = "System purge was canceled."
            }
            banner = message
            onFinish?(message)
        }
    }

    func openWebChat(startSelected: Bool = true, onError: ((String) -> Void)? = nil) {
        if startSelected, !serverActive, !switchingModel, !purgingMemory,
           let selected = models.first(where: { $0.id == selectedModelID }) {
            useModel(selected)
        }
        webChat.start { [weak self] result in
            let message: String
            switch result {
            case .success(let url):
                if NSWorkspace.shared.open(url) { return }
                message = "The default browser could not open Lulu Chat."
            case .failure(let error):
                message = error.localizedDescription
            }
            self?.banner = message
            onError?(message)
        }
    }

    private func webChatStatus() -> WebChatStatus {
        let item = serverActive ? runningModel : models.first { $0.id == selectedModelID }
        let ready = phase == .ready && item != nil && !switchingModel
        let message: String
        if purgingMemory { message = "Lulu is freeing memory…" }
        else if switchingModel || phase == .starting { message = "Loading the local model…" }
        else if ready { message = "Ready on this Mac" }
        else if phase == .failed || (pane == .engines && banner != nil) {
            message = banner ?? "Start the model again in Lulu."
        } else if item == nil { message = "Download and load a model in Lulu to start chatting." }
        else { message = "Load a model in Lulu to start chatting." }
        return WebChatStatus(model: item?.name, selection: item?.id, ready: ready, message: message,
                             inputs: ready ? webChatInputs : ChatInputCapabilities(), appearance: .stored)
    }

    func localChatEndpoint() async throws -> LocalChatEndpoint {
        guard phase == .ready, let item = runningModel else {
            throw LocalChatEndpoint.Failure(message: "Start the local server before sending a message.")
        }
        let currentPort = port
        let currentPID = serverPID
        let modelID = await Probe.servedModelID(port: currentPort, path: item.path)
        guard phase == .ready, currentPID == serverPID, currentPort == port, let modelID else {
            throw LocalChatEndpoint.Failure(message: "The local server model is unavailable. Try again once it is ready.")
        }
        let key = item.engineID == "llama.cpp" ? AccessKeyStore.load() : ""
        return LocalChatEndpoint(port: currentPort, modelID: modelID, key: key)
    }

    func copyEndpoint() {
        let value = "http://127.0.0.1:\(port)/v1"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            copied = false
        }
    }

    func copyAccessKey() {
        let key = AccessKeyStore.ensure()
        accessKey = key
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(key, forType: .string)
        accessKeyCopied = true
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            accessKeyCopied = false
        }
    }

    func regenerateAccessKey() {
        accessKey = AccessKeyStore.regenerate()
        accessKeyVisible = true
        if phase == .ready || phase == .starting {
            banner = "New access key saved. Restart the server so llama.cpp picks it up, then reconfigure clients."
        } else {
            banner = "New access key saved. Configure clients again after starting the server."
        }
    }

    func configure(_ client: ClientID) {
        guard configuringClient == nil, phase == .ready, let item = runningModel,
              client.supports(engine: item.engineID) else { return }
        let currentPort = port
        let currentPID = serverPID
        let context = contextLength
        let keyless = client == .openbot || (client == .pi && item.engineID != "llama.cpp")
        let apiKey = keyless ? "" : AccessKeyStore.ensure()
        configuringClient = client
        Task {
            defer { configuringClient = nil }
            let modelID = await Probe.servedModelID(port: currentPort, path: item.path)
            let reachable = await Probe.supports(port: currentPort, path: client.route, key: apiKey)
            let vision = client == .pi
                ? await Probe.chatInputs(for: item, port: currentPort).image
                : item.engineID == "mlx-vlm" || item.mmproj != nil
            guard phase == .ready, port == currentPort, serverPID == currentPID else { return }
            guard let modelID, reachable else {
                banner = "\(client.title) requires \(client.route). The current server could not verify that endpoint and its model."
                return
            }
            let request = ClientRequest(port: currentPort, modelID: modelID, displayName: item.name,
                                        context: context, vision: vision, apiKey: apiKey)
            do {
                let openBot: URL?
                if client == .openbot {
                    guard let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "app.openbot.desktop") else {
                        throw ClientConfig.Failure(message: "Install OpenBot Desktop to connect it to Lulu.")
                    }
                    guard NSRunningApplication.runningApplications(withBundleIdentifier: "app.openbot.desktop").isEmpty else {
                        throw ClientConfig.Failure(message: "Quit OpenBot, then click OpenBot in Lulu to apply the provider settings.")
                    }
                    openBot = installed
                } else {
                    openBot = nil
                }
                configuredNotice = ClientNotice(client: client, detail: try ClientConfig.apply(client, request))
                if let openBot {
                    _ = try await NSWorkspace.shared.openApplication(at: openBot, configuration: NSWorkspace.OpenConfiguration())
                }
            } catch {
                banner = error.localizedDescription
            }
        }
    }

    func persist() {
        let defaults = UserDefaults.standard
        defaults.set(selectedModelID, forKey: "lulu.model")
        defaults.set(contextLength, forKey: "lulu.context")
        defaults.set(port, forKey: "lulu.port")
    }

    func installAdditionalEngine(_ id: String) {
        guard busyEngineID == nil else { return }
        guard let brew = Machine.executable(["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]) else {
            banner = "Install Homebrew or use the engine’s official download."
            return
        }
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let steps: [[String]]
        switch id {
        case "nativ":
            guard Machine.supportsMLX, major >= 26 else {
                banner = "Nativ requires a Mac with Apple silicon and macOS 26 or later."
                return
            }
            steps = [["install", "--cask", "nativ"]]
        case "ollama": steps = [["install", "ollama"]]
        case "lmstudio": steps = [["install", "--cask", "lm-studio"]]
        case "jan": steps = [["install", "--cask", "jan"]]
        case "llama":
            guard major >= 15 else {
                banner = "Llama requires macOS 15 or later."
                return
            }
            steps = [["install", "--cask", "llama-app"]]
        case "gpt4all": steps = [["install", "--cask", "gpt4all"]]
        case "vllm":
            guard major >= 15 else {
                banner = "vLLM Metal requires macOS 15 or later."
                return
            }
            steps = [["tap", "vllm-project/vllm-metal", "https://github.com/vllm-project/vllm-metal"],
                     ["install", "vllm-project/vllm-metal/vllm-metal"]]
        default: return
        }
        busyEngineID = id
        operationText = "Installing \(id) via Homebrew…\n"
        Task { [weak self] in
            for arguments in steps {
                self?.appendOperation("$ brew " + arguments.joined(separator: " ") + "\n")
                let code = await Task.detached {
                    Shell.run(executable: brew, arguments: arguments,
                              extraEnv: ["HOMEBREW_NO_AUTO_UPDATE": "1", "HOMEBREW_NO_ENV_HINTS": "1"]) { chunk in
                        Task { @MainActor [weak self] in self?.appendOperation(chunk) }
                    }
                }.value
                guard code == 0 else {
                    self?.busyEngineID = nil
                    self?.banner = "Installation of \(id) failed (code \(code)). See installation activity."
                    return
                }
            }
            self?.busyEngineID = nil
            self?.banner = id == "gpt4all"
                ? "The GPT4All installer was downloaded. Finish installation in the Homebrew window."
                : "Installation of \(id) is complete. Configure models and execution in the engine."
        }
    }

    private func runEngineCommand(_ id: String, installing: Bool) {
        guard busyEngineID == nil, let spec = EngineCatalog.spec(id) else { return }
        if let message = EngineCatalog.missingInstallerMessage(for: spec) {
            banner = message
            return
        }
        let command = installing ? EngineCatalog.installCommand(for: spec) : EngineCatalog.removeCommand(for: spec)
        guard let command else { return }
        let pid = runningModel?.engineID == id ? releaseServer() : 0
        busyEngineID = id
        operationText = "$ \(URL(fileURLWithPath: command.executable).lastPathComponent) \(command.arguments.joined(separator: " "))\n"
        Task.detached { [weak self] in
            if pid > 0 { MemoryMonitor.terminate(pid) }
            let code = Shell.run(executable: command.executable, arguments: command.arguments, extraEnv: command.env) { chunk in
                Task { @MainActor in self?.appendOperation(chunk) }
            }
            if code == 0 && !installing {
                EngineCatalog.sweepLeftovers(for: spec)
            }
            await MainActor.run {
                self?.busyEngineID = nil
                self?.refreshEngines()
                if code != 0 {
                    self?.banner = "\(spec.name) exited with code \(code)."
                }
            }
        }
    }

    private func appendOperation(_ chunk: String) {
        operationText.append(chunk)
        if operationText.count > 12_000 {
            operationText = String(operationText.suffix(12_000))
        }
    }

    private func releaseServer() -> pid_t {
        let pid = serverPID
        expectExit = true
        serverPID = 0
        serverProcess = nil
        webChatInputs = ChatInputCapabilities()
        phase = .stopped
        baseline = nil
        memory.predictRate = nil
        memory.promptRate = nil
        memory.contextPeak = nil
        memory.footprint = 0
        try? FileManager.default.removeItem(at: LuluPaths.session)
        return pid
    }

    private func adoptSession() {
        guard serverPID == 0,
              let data = try? Data(contentsOf: LuluPaths.session),
              let session = try? JSONDecoder().decode(Session.self, from: data) else { return }
        if kill(session.pid, 0) != 0 {
            try? FileManager.default.removeItem(at: LuluPaths.session)
            return
        }
        serverPID = session.pid
        phase = .starting
        port = session.port
        if session.context > 0 { contextLength = session.context }
        if let match = models.first(where: { $0.path == session.modelPath }) {
            selectedModelID = match.id
            runningModel = match
        }
        phase = .starting
        expectExit = false
    }

    private func refreshLog() {
        let tail = Format.tail(LuluPaths.log)
        if tail != logText { logText = tail }
    }

    private func tick() {
        if serverPID > 0, kill(serverPID, 0) != 0, !expectExit {
            serverPID = 0
            phase = .failed
            banner = "The engine stopped."
        }
        if metricsVisible {
            let next = makeSnapshot()
            if next != memory { memory = next }
        }
        if monitoringActive && pane == .server && showServerLogs { refreshLog() }
        guard (phase == .starting || phase == .ready), !probeInFlight else { return }
        probeInFlight = true
        let currentPort = port
        let currentPID = serverPID
        let engineID = runningModel?.engineID
        let measuresSpeed = metricsVisible && phase == .ready
        Task {
            let health = await Probe.classify(port: currentPort)
            let speed = measuresSpeed ? await Probe.speed(port: currentPort, engineID: engineID) : nil
            probeInFlight = false
            guard currentPID == serverPID, currentPort == port else { return }
            apply(health, speed)
        }
    }

    private func makeSnapshot() -> MemorySnapshot {
        let system = MemoryMonitor.system()
        var usage = ProcessUsage()
        if serverPID > 0 { usage = MemoryMonitor.tree(of: serverPID) }
        let model = runningModel ?? models.first { $0.id == selectedModelID }
        let arch = model?.arch
        let reserved = arch?.kvBytes(tokens: contextLength) ?? 0
        var used: UInt64 = 0
        if phase == .ready || phase == .starting {
            if model?.engineID == "llama.cpp" {
                let peak = memory.contextPeak ?? 0
                used = arch?.kvBytes(tokens: min(peak, contextLength)) ?? 0
            } else if let baseline, usage.footprint > baseline {
                used = usage.footprint - baseline
            }
        }
        return MemorySnapshot(
            total: system.total,
            available: system.available,
            active: system.active,
            inactive: system.inactive,
            wired: system.wired,
            compressed: system.compressed,
            purgeable: system.purgeable,
            footprint: usage.footprint,
            resident: usage.resident,
            processWired: usage.wired,
            weights: model?.sizeBytes ?? 0,
            kvReserved: reserved,
            kvUsed: used,
            contextTokens: contextLength,
            contextPeak: memory.contextPeak,
            trainedContext: arch?.trainedContext,
            kvSummary: arch?.summary ?? "KV metadata unavailable",
            promptRate: memory.promptRate,
            predictRate: memory.predictRate
        )
    }

    private func apply(_ health: ServerPhase?, _ speed: EngineSpeed?) {
        if health == .ready, phase == .starting {
            phase = .ready
            if baseline == nil { baseline = serverPID > 0 ? MemoryMonitor.tree(of: serverPID).footprint : 0 }
            if let item = runningModel {
                let currentPort = port
                let currentPID = serverPID
                Task {
                    let inputs = await Probe.chatInputs(for: item, port: currentPort)
                    guard phase == .ready, serverPID == currentPID, item.id == runningModel?.id else { return }
                    webChatInputs = inputs
                }
            }
        }
        var copy = memory
        if let speed {
            copy.promptRate = speed.prompt
            copy.predictRate = speed.predict
            copy.contextPeak = speed.peak
        }
        if monitoringActive, pane == .overview || pane == .speed, phase == .ready, runningModel?.engineID != "llama.cpp", let baseline, copy.footprint + 8_000_000 < baseline {
            self.baseline = copy.footprint
        }
        if copy != memory { memory = copy }
    }

    private func handle(_ event: TransferEvent) {
        switch event {
        case let .progress(id, path, received, expected):
            guard let index = jobs.firstIndex(where: { $0.id == id }),
                  let file = jobs[index].files.firstIndex(where: { $0.path == path }) else { return }
            jobs[index].files[file].received = received
            if expected > jobs[index].files[file].size {
                jobs[index].files[file].size = expected
            }
            noteSpeed(jobs[index].received)
        case let .finished(id, path):
            guard let index = jobs.firstIndex(where: { $0.id == id }),
                  let file = jobs[index].files.firstIndex(where: { $0.path == path }) else { return }
            jobs[index].files[file].done = true
            jobs[index].files[file].received = jobs[index].files[file].size
            activeJob = nil
            persistDownloads()
            pump()
        case let .failed(id, message):
            guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
            jobs[index].state = .failed
            jobs[index].error = message
            activeJob = nil
            downloadSpeed = 0
            banner = message
            persistDownloads()
            pump()
        case let .paused(id):
            if let index = jobs.firstIndex(where: { $0.id == id }), jobs[index].state == .running {
                jobs[index].state = .paused
            }
            activeJob = nil
            downloadSpeed = 0
            persistDownloads()
            pump()
        }
    }

    private func pump() {
        guard !transfers.busy else { return }
        while true {
            guard let index = jobs.firstIndex(where: { $0.state == .running || $0.state == .queued }) else {
                downloadSpeed = 0
                activeJob = nil
                return
            }
            if jobs[index].state == .queued { jobs[index].state = .running }
            guard let fileIndex = jobs[index].files.firstIndex(where: { !$0.done }) else {
                jobs[index].state = .done
                jobs[index].error = nil
                persistDownloads()
                Task { await rescanModels() }
                continue
            }
            let part = jobs[index].files[fileIndex]
            let final = URL(fileURLWithPath: jobs[index].destination).appendingPathComponent(part.path)
            if let size = fileSize(final), part.size == 0 || size >= part.size {
                jobs[index].files[fileIndex].done = true
                jobs[index].files[fileIndex].received = size
                continue
            }
            if let partial = fileSize(final.appendingPathExtension("incomplete")) {
                jobs[index].files[fileIndex].received = partial
            }
            do {
                try transfers.start(
                    job: jobs[index].id,
                    repo: jobs[index].repo,
                    path: part.path,
                    destination: URL(fileURLWithPath: jobs[index].destination),
                    token: TokenStore.effective()
                )
                activeJob = jobs[index].id
                speedMark = (CFAbsoluteTimeGetCurrent(), jobs[index].received)
                persistDownloads()
                return
            } catch {
                jobs[index].state = .failed
                jobs[index].error = error.localizedDescription
                banner = error.localizedDescription
                persistDownloads()
                continue
            }
        }
    }

    private func noteSpeed(_ total: Int64) {
        let now = CFAbsoluteTimeGetCurrent()
        if let mark = speedMark, now - mark.time >= 0.4 {
            let delta = total - mark.bytes
            if delta >= 0 { downloadSpeed = Double(delta) / (now - mark.time) }
            speedMark = (now, total)
        } else if speedMark == nil {
            speedMark = (now, total)
        }
    }

    private func persistDownloads() {
        DownloadStore.save(jobs)
    }

    private func fileSize(_ url: URL) -> Int64? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return nil }
        return Int64(size)
    }
}
