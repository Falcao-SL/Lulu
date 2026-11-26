import AppKit
import SwiftUI

@MainActor
private final class TrayState: ObservableObject {
    @Published var selectedID: String?
    @Published var deleteID: String?
    @Published var confirmPurge = false
    @Published var apiExample: TrayAPIExample?
    @Published var preparingAPI = false
    @Published var feedback: String?
    @Published var checkingDownloads: Set<String> = []
}

struct LuluTray: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(LuluAppearance.preferenceKey) private var appearance = LuluAppearance.system
    @ObservedObject var model: AppModel
    let openWorkspace: (String) -> Void
    @AppStorage("lulu.trayContexts") private var storedContexts = Data()
    @StateObject private var state = TrayState()

    private typealias Space = LuluTheme.Space

    private var selectedItem: ModelItem? { model.models.first { $0.id == state.selectedID } }
    private var currentItem: ModelItem? {
        if model.serverActive { return model.runningModel }
        return model.models.first { $0.id == model.selectedModelID }
    }
    private var engine: EngineStatus? {
        model.engines.first { $0.id == currentItem?.engineID }
            ?? model.engines.first(where: \.installed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            if let example = state.apiExample {
                TrayRequestView(example: example, close: { self.state.apiExample = nil })
            } else if let item = selectedItem {
                details(item)
            } else {
                dashboard
            }
            if let feedback = state.feedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(TrayColors.secondaryText)
                    .textSelection(.enabled)
            }
            Divider()
            footer
        }
        .padding(Space.lg)
        .frame(width: 345)
        .background {
            if (appearance.scheme ?? colorScheme) == .dark {
                Color.black.opacity(0.88)
            }
        }
        .tint(LuluTheme.accent)
        .preferredColorScheme(appearance.scheme)
        .confirmationDialog("Delete this model?", isPresented: Binding(
            get: { state.deleteID != nil },
            set: { if !$0 { state.deleteID = nil } }
        ), titleVisibility: .visible) {
            if let id = state.deleteID {
                Button("Delete from disk", role: .destructive) {
                    model.banner = nil
                    model.deleteModel(id)
                    model.confirmModelDeletion()
                    if let error = model.banner { state.feedback = error }
                    else { backToModels() }
                    state.deleteID = nil
                }
            }
            Button("Cancel", role: .cancel) { state.deleteID = nil }
        } message: {
            Text("The local model files will be removed.")
        }
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            header
            Divider()
            ViewThatFits(in: .vertical) {
                modelList
                ScrollView { modelList }
            }
            .frame(maxHeight: 390)
            .fixedSize(horizontal: false, vertical: true)
            Divider()
            Button {
                model.showModelRecommendations()
                showWindow("main")
            } label: {
                trayRow("Browse models", subtitle: "Find models for this Mac", icon: "square.grid.2x2", trailing: "chevron.right")
            }
            .buttonStyle(TrayRowButtonStyle())
        }
    }

    private var modelList: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            library
            if !recommendations.isEmpty {
                Divider()
                recommendationList
            }
            activeDownloads
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.sm) {
                Text("Lulu").font(.system(.title3, design: .rounded, weight: .semibold))
                Circle()
                    .fill(statusTone.color)
                    .frame(width: 7, height: 7)
                    .accessibilityLabel("Server \(model.switchingModel ? "switching" : model.phase.rawValue)")
                    .help(model.switchingModel ? "Switching models" : "Server \(model.phase.rawValue)")
                Spacer()
                Button { state.confirmPurge = true } label: {
                    Label(model.purgingMemory ? "Purging…" : "Purge", systemImage: "memorychip")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.purgingMemory || model.switchingModel)
                .help("Stop the server and free memory")
                .confirmationDialog("Purge memory?", isPresented: $state.confirmPurge, titleVisibility: .visible) {
                    Button("Purge", role: .destructive) {
                        state.feedback = nil
                        model.purge { state.feedback = $0 }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This stops the local server and asks macOS to release inactive memory.")
                }
            }
            HStack(spacing: Space.sm) {
                Button { model.copyEndpoint() } label: {
                    Label {
                        if model.copied { Text("Copied") }
                        else { Text(verbatim: "127.0.0.1:\(model.port)") }
                    } icon: {
                        Image(systemName: model.copied ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(TrayColors.secondaryText)
                    }
                    .font(.callout.monospaced())
                }
                .buttonStyle(.plain)
                .help("Copy the local API address, including /v1")
                Spacer(minLength: 0)
                Button("Open chat") { openChat() }
                    .buttonStyle(.plain)
                    .foregroundStyle(LuluTheme.accent)
            }
        }
    }

    private var statusTone: LuluTone {
        if model.switchingModel || model.purgingMemory { return .info }
        switch model.phase {
        case .ready: return .success
        case .starting: return .info
        case .failed: return .danger
        case .stopped: return .neutral
        }
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Text("Installed").font(.headline)
                Button("models") { model.showModels(.library); showWindow("main") }
                    .buttonStyle(.plain)
                    .foregroundStyle(LuluTheme.accent)
                    .accessibilityLabel("Manage installed models")
                Spacer()
            }
            if model.models.isEmpty {
                Text("Your downloaded models will appear here.")
                    .font(.callout).foregroundStyle(TrayColors.secondaryText)
                    .padding(.vertical, Space.xs)
            }
            ForEach(model.models) { item in
                Button {
                    state.feedback = nil
                    state.selectedID = item.id
                } label: {
                    let loaded = model.serverActive && item.id == model.runningModel?.id
                    trayRow(
                        recommendation(for: item)?.name ?? item.name,
                        subtitle: "\(Format.bytes(item.sizeBytes)) · \(shortContext(context(for: item))) ctx",
                        icon: loaded ? "checkmark.circle" : "cube",
                        badges: modelBadges(item), trailing: "chevron.right"
                    )
                }
                .buttonStyle(TrayRowButtonStyle())
                .accessibilityHint("Show model controls")
            }
        }
    }

    private var recommendations: [TrayRecommendation] {
        TrayRecommendation.fitting(memoryGB: RecommendedModel.memoryGB).filter { entry in
            !model.models.contains { entry.matches($0) }
        }.prefix(6).map { $0 }
    }

    private var recommendationList: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Recommended for your Mac")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(recommendations) { entry in
                let job = model.jobs.last { entry.matches($0) && $0.state != .done }
                let busy = state.checkingDownloads.contains(entry.id) || job?.state == .queued || job?.state == .running
                Button {
                    if let job { model.resumeDownload(job.id) }
                    else { startDownload(entry) }
                } label: {
                    trayRow(entry.name,
                            subtitle: job.map(downloadDescription) ?? Format.bytes(entry.bytes),
                            icon: entry.projector == nil ? "cpu" : "eye",
                            badges: [entry.size, entry.quantization],
                            trailing: busy ? "clock" : "arrow.down.to.line")
                }
                .buttonStyle(TrayRowButtonStyle())
                .disabled(busy)
                .accessibilityHint("Download \(entry.name) \(entry.quantization)")
            }
        }
    }

    private var activeDownloads: some View {
        let suggestions = recommendations
        let listed = model.jobs.filter { job in
            job.state != .done && !suggestions.contains { $0.matches(job) }
        }
        return ForEach(listed) { job in
            Button { model.showModels(.downloads); showWindow("main") } label: {
                trayRow(job.repo, subtitle: downloadDescription(job), icon: "arrow.down.circle", trailing: "chevron.right")
            }
            .buttonStyle(TrayRowButtonStyle())
            .help("Manage download")
        }
    }

    private func downloadDescription(_ job: DownloadJob) -> String {
        switch job.state {
        case .queued: return "Queued"
        case .paused: return "Paused · Click to resume"
        case .failed: return "Failed · Click to retry"
        case .done: return "Completed"
        case .running:
            guard job.total > 0 else { return "Downloading…" }
            let fraction = min(1, Double(job.received) / Double(job.total))
            return fraction.formatted(.percent.precision(.fractionLength(0))) + " downloaded"
        }
    }

    private func startDownload(_ entry: TrayRecommendation) {
        state.feedback = nil
        state.checkingDownloads.insert(entry.id)
        Task {
            defer { state.checkingDownloads.remove(entry.id) }
            do {
                let files = try await Hub.files(repo: entry.repo, token: TokenStore.effective())
                let selected = try entry.selectFiles(files)
                if !model.enqueueDownload(repo: entry.repo, files: selected) {
                    state.feedback = model.banner
                }
            } catch {
                state.feedback = error.localizedDescription
            }
        }
    }

    private func details(_ item: ModelItem) -> some View {
        let active = model.serverActive && model.runningModel?.id == item.id
        let ready = active && model.phase == .ready
        let changedContext = active && context(for: item) != model.contextLength
        return VStack(alignment: .leading, spacing: Space.md) {
            Button(action: backToModels) { Label("Models", systemImage: "arrow.left") }
                .buttonStyle(.plain)
                .foregroundStyle(LuluTheme.accent)
            trayRow(recommendation(for: item)?.name ?? item.name,
                    subtitle: item.engineID, icon: active ? "checkmark.circle" : "cube", badges: modelBadges(item))
                .accessibilityAddTraits(.isHeader)
            contextPicker(item)
            Divider()
            VStack(alignment: .leading, spacing: Space.xs) {
                actionRow("Chat with model", icon: "bubble.left") {
                    load(item, openChat: true)
                }
                .disabled(model.switchingModel)
                actionRow("Copy model ID", icon: "doc.on.doc") {
                    resolveAPI(for: item, buildRequest: false)
                }
                .disabled(!ready || state.preparingAPI)
                .help(ready ? "Copy the ID reported by the local server" : "Load the model to get its server ID")
                actionRow("Build an API request", icon: "curlybraces") {
                    resolveAPI(for: item, buildRequest: true)
                }
                .disabled(!ready || state.preparingAPI)
                .help(ready ? "Create a cURL example for this model" : "Load the model to build an API request")
                if let repo = model.repository(for: item) ?? recommendation(for: item)?.repo,
                   let url = URL(string: "https://huggingface.co/\(repo)") {
                    Link(destination: url) {
                        trayRow("View on Hugging Face", icon: "arrow.up.right")
                    }
                    .buttonStyle(TrayRowButtonStyle())
                } else {
                    actionRow("Find on Hugging Face", icon: "magnifyingglass") {
                        var url = URLComponents(string: "https://huggingface.co/models")!
                        url.queryItems = [URLQueryItem(name: "search", value: item.name)]
                        if let address = url.url { NSWorkspace.shared.open(address) }
                    }
                }
                if !active || changedContext {
                    actionRow(changedContext ? "Reload with selected context" : "Load", icon: "play") {
                        load(item, openChat: false)
                    }
                    .disabled(model.switchingModel)
                }
                if active {
                    actionRow("Unload", icon: "stop") {
                        state.feedback = nil
                        model.stopServer()
                    }
                    .disabled(model.switchingModel)
                }
                actionRow("Delete", icon: "trash", note: Format.bytes(item.sizeBytes)) { state.deleteID = item.id }
                    .disabled(active || model.switchingModel)
                    .help(active ? "Unload the model before deleting it" : "Delete this model from disk")
            }
        }
    }

    private func contextPicker(_ item: ModelItem) -> some View {
        let all = ContextPolicy.options(presets: model.contextOptions, declared: item.arch?.trainedContext)
        let presets = all.filter { (4096...65536).contains($0) }
        let choices = presets.isEmpty ? Array(all.prefix(1)) : presets
        let value = context(for: item)
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack {
                Text("Context length").font(.headline)
                Text("· Memory estimate")
                    .font(.caption)
                    .foregroundStyle(TrayColors.secondaryText)
                    .help("Model file size plus estimated KV cache. Actual use can be higher.")
                Spacer()
                Menu {
                    ForEach(all, id: \.self) { tokens in
                        Button(shortContext(tokens)) { saveContext(tokens, for: item) }
                    }
                } label: {
                    Label(choices.contains(value) ? "More" : shortContext(value), systemImage: "ellipsis")
                        .labelStyle(.titleAndIcon)
                }
                .fixedSize()
                .accessibilityLabel("More context lengths")
            }
            HStack(spacing: Space.xs) {
                ForEach(choices, id: \.self) { tokens in
                    Button { saveContext(tokens, for: item) } label: {
                        VStack(spacing: Space.xs) {
                            Text(shortContext(tokens)).font(.caption.weight(.semibold))
                            Text(estimatedMemory(for: item, context: tokens))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(TrayColors.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.sm)
                        .background(tokens == value ? Color.primary.opacity(0.12) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: LuluTheme.Radius.control))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(tokens == value ? .isSelected : [])
                }
            }
            .padding(Space.xs)
            .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: LuluTheme.Radius.control))
        }
    }

    private func context(for item: ModelItem) -> Int {
        let saved = (try? JSONDecoder().decode([String: Int].self, from: storedContexts)) ?? [:]
        let value = saved[item.id] ?? model.contextLength
        return ContextPolicy.clamped(value, declared: item.arch?.trainedContext)
    }

    private func saveContext(_ tokens: Int, for item: ModelItem) {
        var saved = (try? JSONDecoder().decode([String: Int].self, from: storedContexts)) ?? [:]
        saved[item.id] = tokens
        if let data = try? JSONEncoder().encode(saved) { storedContexts = data }
    }

    private func estimatedMemory(for item: ModelItem, context: Int) -> String {
        guard let architecture = item.arch else { return "—" }
        let (total, overflow) = item.sizeBytes.addingReportingOverflow(architecture.kvBytes(tokens: context))
        return overflow ? "—" : Format.bytes(total)
    }

    private func shortContext(_ tokens: Int) -> String {
        tokens >= 1024 && tokens.isMultiple(of: 1024) ? "\(tokens / 1024)k" : String(tokens)
    }

    private func modelBadges(_ item: ModelItem) -> [String] {
        var badges: [String]
        if let entry = recommendation(for: item) {
            badges = [entry.size, entry.quantization]
        } else {
            badges = [item.engineID == "llama.cpp" ? "GGUF" : "MLX"]
            if let quantization = ModelMetadata.quantization(in: item.name) { badges.append(quantization) }
        }
        if item.mmproj != nil || item.engineID == "mlx-vlm" { badges.append("Vision") }
        return badges
    }

    private func recommendation(for item: ModelItem) -> TrayRecommendation? {
        TrayRecommendation.options.first { $0.matches(item) }
    }

    private func load(_ item: ModelItem, openChat: Bool) {
        state.feedback = nil
        guard model.useModel(item, context: context(for: item)) else {
            state.feedback = model.banner
            if model.pane == .engines { show(.engines) }
            return
        }
        if openChat { self.openChat(startSelected: false) }
    }

    private func openChat(startSelected: Bool = true) {
        state.feedback = nil
        model.openWebChat(startSelected: startSelected) { state.feedback = $0 }
    }

    private func resolveAPI(for item: ModelItem, buildRequest: Bool) {
        guard !state.preparingAPI else { return }
        state.preparingAPI = true
        state.feedback = nil
        Task {
            defer { state.preparingAPI = false }
            do {
                let endpoint = try await model.localChatEndpoint()
                guard state.selectedID == item.id, model.runningModel?.id == item.id else { return }
                if buildRequest {
                    state.apiExample = TrayAPIExample(modelID: endpoint.modelID, port: endpoint.port,
                                                      requiresKey: item.engineID == "llama.cpp")
                } else {
                    copyTrayText(endpoint.modelID)
                    state.feedback = "Model ID copied"
                }
            } catch {
                if state.selectedID == item.id { state.feedback = error.localizedDescription }
            }
        }
    }

    private func trayRow(_ title: String, subtitle: String? = nil, icon: String,
                         badges: [String] = [], trailing: String? = nil, note: String? = nil) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(LuluTheme.accent)
                .frame(width: 26, height: 26)
                .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: LuluTheme.Radius.control))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                    .lineLimit(subtitle == nil ? 1 : 2).truncationMode(.middle)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(TrayColors.secondaryText).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            ForEach(badges, id: \.self) { badge in
                Text(badge)
                    .font(.caption2.monospaced())
                    .foregroundStyle(TrayColors.secondaryText)
                    .padding(.horizontal, Space.xs)
                    .padding(.vertical, 2)
                    .background(.primary.opacity(0.08), in: Capsule())
                    .fixedSize()
            }
            if let note { Text(note).font(.caption).foregroundStyle(TrayColors.secondaryText) }
            if let trailing {
                Image(systemName: trailing)
                    .font(.caption)
                    .foregroundStyle(TrayColors.secondaryText)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Space.xs)
        .contentShape(Rectangle())
    }

    private func actionRow(_ title: String, icon: String, note: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            trayRow(title, icon: icon, note: note)
        }
        .buttonStyle(TrayRowButtonStyle())
    }

    private var footer: some View {
        HStack(spacing: Space.sm) {
            Text([AppUpdates.current, engine?.name, engine?.version].compactMap { $0 }
                .filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption.monospacedDigit())
                .foregroundStyle(TrayColors.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Menu {
                Picker("Appearance", selection: Binding(get: { appearance }, set: { selection in
                    appearance = selection
                    selection.apply()
                })) {
                    ForEach(LuluAppearance.allCases, id: \.self) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
            } label: {
                Image(systemName: appearance.symbol)
            }
            .accessibilityLabel("Appearance")
            .accessibilityValue(Text(appearance.title))
            .help("Appearance")
            Button("Settings") { show(.server) }
            Button("Quit") { NSApp.terminate(nil) }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func backToModels() {
        state.selectedID = nil
        state.apiExample = nil
        state.feedback = nil
    }

    private func show(_ pane: Pane) {
        model.pane = pane
        showWindow("main")
    }

    private func showWindow(_ id: String) {
        openWorkspace(id)
    }
}

private struct TrayRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration)
    }

    private final class HoverState: ObservableObject {
        @Published var isHovered = false
    }

    private struct Row: View {
        @Environment(\.isEnabled) private var isEnabled
        @StateObject private var hover = HoverState()
        let configuration: Configuration

        var body: some View {
            configuration.label
                .padding(.horizontal, LuluTheme.Space.xs)
                .background {
                    if isEnabled && (hover.isHovered || configuration.isPressed) {
                        RoundedRectangle(cornerRadius: LuluTheme.Radius.control)
                            .fill(Color.primary.opacity(configuration.isPressed ? 0.18 : 0.12))
                    }
                }
                .contentShape(Rectangle())
                .onHover { hover.isHovered = $0 }
        }
    }
}

private func copyTrayText(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

private struct TrayAPIExample {
    let modelID: String
    let port: Int
    let requiresKey: Bool

    func command(prompt: String, stream: Bool) -> String {
        let body: [String: Any] = [
            "model": modelID,
            "messages": [["role": "user", "content": prompt]],
            "stream": stream,
        ]
        guard let encoded = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
              let json = String(data: encoded, encoding: .utf8) else { return "" }
        let quoted = "'" + json.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let streamFlag = stream ? " -N" : ""
        var lines = [
            "curl\(streamFlag) http://127.0.0.1:\(port)/v1/chat/completions",
            "-H 'Content-Type: application/json'",
        ]
        if requiresKey { lines.append(#"-H "Authorization: Bearer ${LULU_API_KEY}""#) }
        lines.append("--data-raw \(quoted)")
        return lines.joined(separator: " " + "\\" + "\n  ")
    }
}

@MainActor
private final class TrayRequestForm: ObservableObject {
    @Published var prompt = "Hello from Lulu"
    @Published var stream = false
    @Published var copied = false
}

private struct TrayRequestView: View {
    let example: TrayAPIExample
    let close: () -> Void
    @StateObject private var form = TrayRequestForm()
    private var command: String { example.command(prompt: form.prompt, stream: form.stream) }

    var body: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
            Button(action: close) { Label("Back to model", systemImage: "arrow.left") }
                .buttonStyle(.plain)
                .foregroundStyle(LuluTheme.accent)
            Text("Build an API request")
                .font(.headline).accessibilityAddTraits(.isHeader)
            TextField("Prompt", text: $form.prompt)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("API example prompt")
            Toggle("Stream response", isOn: $form.stream)
            ScrollView([.horizontal, .vertical]) {
                Text(verbatim: command)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(LuluTheme.Space.sm)
            }
            .frame(height: 170)
            .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: LuluTheme.Radius.control))
            if example.requiresKey {
                Text("Set LULU_API_KEY to the access key shown in Server.")
                    .font(.caption)
                    .foregroundStyle(TrayColors.secondaryText)
            }
            Button(form.copied ? "Copied" : "Copy cURL", systemImage: form.copied ? "checkmark" : "doc.on.doc") {
                copyTrayText(command)
                form.copied = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(form.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .onChange(of: command) { _, _ in form.copied = false }
        }
    }
}
