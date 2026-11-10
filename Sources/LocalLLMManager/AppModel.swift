import AppKit
import Foundation
import Darwin

enum Pane: String, CaseIterable, Hashable {
    case overview, engines, models, server, speed
}

enum ServerPhase: String {
    case stopped, starting, ready, failed
}

struct MemorySnapshot: Equatable {
    var total: UInt64 = 0
    var available: UInt64 = 0
    var active: UInt64 = 0
    var inactive: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var purgeable: UInt64 = 0
    var footprint: UInt64 = 0
    var resident: UInt64 = 0
    var processWired: UInt64 = 0
    var weights: UInt64 = 0
    var kvReserved: UInt64 = 0
    var kvUsed: UInt64 = 0
    var contextTokens: Int = 0
    var contextPeak: Int?
    var trainedContext: Int?
    var kvSummary: String = ""
    var promptRate: Double?
    var predictRate: Double?
}

@MainActor
final class AppModel: ObservableObject {
    @Published var pane: Pane = .overview {
        didSet { if pane != oldValue { tick() } }
    }
    @Published var engines: [EngineStatus] = []
    @Published var models: [ModelItem] = []
    @Published var jobs: [DownloadJob] = []
    @Published var hubHits: [HubHit] = []
    @Published var listedFiles: [ListedFile] = []
    @Published var listedRepo = ""
    @Published var repoQuery = ""
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
    @Published var searching = false
    @Published var selectedModelID = "" {
        didSet { normalizeContext() }
    }
    @Published var contextLength = 8192
    @Published var port = 8000
    @Published var phase: ServerPhase = .stopped {
        didSet { if phase != oldValue { configureMonitor() } }
    }
    @Published var runningModel: ModelItem?
    @Published var memory = MemorySnapshot()
    @Published var logText = ""
    @Published var operationText = ""
    @Published var banner: String?
    @Published var configuredNotice: ClientNotice?
    @Published var busyEngineID: String?
    @Published var downloadSpeed: Double = 0
    @Published var confirmRemoveEngine: String?
    @Published var confirmDeleteModel: String?
    @Published var confirmPurge = false
    @Published var copied = false
    @Published var updateVersion: String?
    @Published var updateURL: URL?
    @Published var checkingUpdate = false

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
    private var tickCount = 0
    private var sizing = false
    private var speedMark: (time: CFAbsoluteTime, bytes: Int64)?
    private var activeJob: UUID?
    private var timer: Timer?

    init() {
        let defaults = UserDefaults.standard
        selectedModelID = defaults.string(forKey: "lulu.model") ?? ""
        let storedContext = defaults.integer(forKey: "lulu.context")
        if storedContext > 0 { contextLength = storedContext }
        let storedPort = defaults.integer(forKey: "lulu.port")
        if storedPort > 0 { port = storedPort }
        jobs = DownloadStore.load()
        refreshTokenNote()
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
        let serving = phase == .starting || phase == .ready
        let interval: TimeInterval = monitoringActive ? (serving ? 1 : 5) : 10
        guard timer == nil || interval != monitorInterval else { return }
        timer?.invalidate()
        monitorInterval = interval
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
        Task.detached { [weak self] in
            let sized = EngineCatalog.measured()
            await MainActor.run {
                self?.engines = sized
                self?.sizing = false
            }
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
        let found = await Task.detached(priority: .utility) { ModelScan.all() }.value
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

    func loadFiles(_ repo: String) {
        let requestID = UUID()
        hubRequestID = requestID
        listedRepo = ""
        listedFiles = []
        searching = true
        banner = nil
        let token = TokenStore.effective()
        Task {
            do {
                async let metadata = try? Hub.metadata(repo: repo, token: token)
                let files = try await Hub.files(repo: repo, token: token)
                guard hubRequestID == requestID else { return }
                let details = await metadata
                guard hubRequestID == requestID else { return }
                selectedHubHit = details ?? selectedHubHit
                listedFiles = files
                listedRepo = repo
                searching = false
                if listedFiles.isEmpty { banner = "This repository returned no files." }
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
        let chosen = listedFiles.filter(\.selected)
        guard !listedRepo.isEmpty, !chosen.isEmpty else {
            banner = "Select at least one file."
            return
        }
        let destination = Hub.destination(repo: listedRepo, files: chosen)
        let job = DownloadJob(
            id: UUID(),
            repo: listedRepo,
            destination: destination.path,
            files: chosen.map { DownloadPart(path: $0.path, size: $0.size, received: 0, done: false) },
            state: .queued,
            error: nil
        )
        jobs.append(job)
        persistDownloads()
        pump()
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
        guard phase == .stopped || phase == .failed else { return }
        guard let model = models.first(where: { $0.id == selectedModelID }) else {
            banner = "Choose a model."
            return
        }
        #if arch(x86_64)
        guard model.engineID == "llama.cpp" else {
            banner = "MLX models require Apple Silicon. On Intel Macs, use GGUF with llama.cpp."
            return
        }
        #endif
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
            arguments = ["-m", model.path, "--host", "127.0.0.1", "--port", String(port), "-ngl", "99", "-c", String(contextLength), "-t", String(cores), "-tb", String(cores), "--flash-attn", "on", "--metrics"]
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
        let pid = releaseServer()
        guard pid > 0 else { return }
        Task.detached {
            MemoryMonitor.terminate(pid)
        }
    }

    func purge() {
        let before = memory.available
        let pid = releaseServer()
        Task.detached { [weak self] in
            if pid > 0 { MemoryMonitor.terminate(pid) }
            let code = Shell.run(
                executable: "/usr/bin/osascript",
                arguments: ["-e", "do shell script \"/usr/sbin/purge\" with administrator privileges"]
            ) { _ in }
            let after = MemoryMonitor.system().available
            await MainActor.run {
                self?.tick()
                if code == 0 {
                    self?.banner = "Purge complete. Available memory changed from \(Format.bytes(before)) to \(Format.bytes(after))."
                } else if pid > 0 {
                    self?.banner = "Server stopped. System purge was canceled."
                } else {
                    self?.banner = "System purge was canceled."
                }
            }
        }
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

    func configure(_ client: ClientID) {
        guard let item = runningModel ?? models.first(where: { $0.id == selectedModelID }) else {
            banner = "Choose a model before configuring \(client.title)."
            return
        }
        let currentPort = port
        let context = contextLength
        let vision = item.engineID == "mlx-vlm" || item.mmproj != nil
        let name = item.name
        let engineID = item.engineID
        let path = item.path
        Task {
            let live = await Probe.servedModelID(port: currentPort, path: path)
            let modelID = live ?? OpenCodeClient.fallbackID(engineID: engineID, path: path)
            let request = ClientRequest(
                port: currentPort, modelID: modelID, displayName: name,
                context: context, vision: vision, engineID: engineID, liveID: live != nil
            )
            do {
                configuredNotice = ClientNotice(client: client, detail: try ClientConfig.apply(client, request))
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
            guard major >= 26 else {
                banner = "Nativ requires macOS 26 or later."
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

    private func tick() {
        if serverPID > 0, kill(serverPID, 0) != 0, !expectExit {
            serverPID = 0
            phase = .failed
            banner = "The engine stopped."
        }
        if monitoringActive && (pane == .overview || pane == .speed) {
            let next = makeSnapshot()
            if next != memory { memory = next }
        }
        tickCount += 1
        if monitoringActive && pane == .server && tickCount.isMultiple(of: 2) {
            let tail = Format.tail(LuluPaths.log)
            if tail != logText { logText = tail }
        }
        guard (phase == .starting || phase == .ready), !probeInFlight else { return }
        probeInFlight = true
        let currentPort = port
        let currentPID = serverPID
        let llama = runningModel?.engineID == "llama.cpp"
        Task {
            let health = await Probe.classify(port: currentPort)
            let speed = llama ? await Probe.speed(port: currentPort) : nil
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

    private func apply(_ health: ServerPhase?, _ speed: (prompt: Double, predict: Double, peak: Int)?) {
        if health == .ready, phase == .starting {
            phase = .ready
            if baseline == nil { baseline = serverPID > 0 ? MemoryMonitor.tree(of: serverPID).footprint : 0 }
        }
        guard var copy = Optional(memory) else { return }
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

private enum Probe {
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.4
        config.timeoutIntervalForResource = 0.6
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    static func classify(port: Int) async -> ServerPhase? {
        if let (code, data) = await get(port, "/health") {
            if code == 503 { return .starting }
            if code == 200 {
                if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = object["status"] as? String, status != "ok" {
                    return .starting
                }
                return .ready
            }
        }
        if let (code, _) = await get(port, "/v1/models"), code == 200 {
            return .ready
        }
        return nil
    }

    static func servedModelID(port: Int, path: String) async -> String? {
        guard let (code, data) = await get(port, "/v1/models"), code == 200,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = object["data"] as? [[String: Any]] else { return nil }
        let ids = rows.compactMap { $0["id"] as? String }
        let file = URL(fileURLWithPath: path)
        let resolved = file.resolvingSymlinksInPath().path
        let filename = file.lastPathComponent
        let stem = file.deletingPathExtension().lastPathComponent
        if let exact = ids.first(where: { $0 == resolved || $0 == path || $0 == filename || $0 == stem }) {
            return exact
        }
        return ids.first { id in
            let url = URL(fileURLWithPath: id)
            return url.lastPathComponent == filename || url.deletingPathExtension().lastPathComponent == stem
        }
    }

    static func speed(port: Int) async -> (prompt: Double, predict: Double, peak: Int)? {
        guard let (code, data) = await get(port, "/metrics"), code == 200,
              let text = String(data: data, encoding: .utf8) else { return nil }
        var prompt = 0.0
        var predict = 0.0
        var peak = 0
        var saw = false
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let parts = line.split(separator: " ")
            guard parts.count >= 2, let value = Double(parts[1]) else { continue }
            switch parts[0] {
            case "llamacpp:prompt_tokens_seconds":
                prompt = value
                saw = true
            case "llamacpp:predicted_tokens_seconds":
                predict = value
                saw = true
            case "llamacpp:n_tokens_max":
                peak = Int(value)
                saw = true
            default:
                break
            }
        }
        return saw ? (prompt, predict, peak) : nil
    }

    private static func get(_ port: Int, _ path: String) async -> (Int, Data)? {
        guard let url = URL(string: "http://127.0.0.1:\(port)\(path)") else { return nil }
        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse else { return nil }
        return (http.statusCode, data)
    }
}
