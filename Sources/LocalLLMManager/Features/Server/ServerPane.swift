import SwiftUI
import AppKit

struct ServerPane: View {
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

                HStack {
                    if model.models.isEmpty && !serverActive {
                        Button("Choose model") { model.showModelRecommendations() }
                            .buttonStyle(.borderedProminent)
                    } else if serverActive {
                        if model.phase == .ready {
                            Button("Open chat") { model.openWebChat(startSelected: false) }
                                .buttonStyle(.borderedProminent)
                        }
                        Button("Stop server", luluSymbol: "stop.fill") { model.stopServer() }
                            .buttonStyle(.bordered)
                    } else {
                        Button("Start server", luluSymbol: "play.fill") { model.startServer() }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.switchingModel || model.purgingMemory)
                    }
                }
                Divider()
                DisclosureGroup("Context and port") {
                    connectionSettings.padding(.top, LuluTheme.Space.sm)
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

            DisclosureGroup("API access key") {
                accessKeyControls.padding(.top, LuluTheme.Space.sm)
            }
            .padding(LuluTheme.Space.lg)
            .luluCard()

            ClientRack(model: model)

            DisclosureGroup("Server logs", isExpanded: $model.showServerLogs) {
                logBox(model.logText, empty: "Server logs appear here.")
            }
        }
    }

    private var accessKeyControls: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.sm) {
            Text("Send this key with requests to the local server. llama.cpp requires it.")
                .font(LuluTheme.TypeStyle.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: LuluTheme.Space.sm) {
                Group {
                    if model.accessKeyVisible {
                        Text(model.accessKey)
                            .font(LuluTheme.TypeStyle.body.monospaced())
                            .textSelection(.enabled)
                            .lineLimit(2)
                    } else {
                        Text(accessKeyMask(model.accessKey))
                            .font(LuluTheme.TypeStyle.body.monospaced())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(model.accessKeyVisible ? "Hide" : "Show") {
                    model.accessKeyVisible.toggle()
                }
                Button(model.accessKeyCopied ? "Copied" : "Copy", luluSymbol: model.accessKeyCopied ? "checkmark" : "doc.on.doc") {
                    model.copyAccessKey()
                }
                Button("Regenerate") { model.regenerateAccessKey() }
            }
        }
    }

    private var connectionSettings: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
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
            }
        }
    }

    private var selectedModel: ModelItem? {
        model.models.first { $0.id == model.selectedModelID }
    }

    private func accessKeyMask(_ key: String) -> String {
        guard key.count > 8 else { return String(repeating: "•", count: max(key.count, 4)) }
        return String(repeating: "•", count: key.count - 4) + String(key.suffix(4))
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
