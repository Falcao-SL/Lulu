import SwiftUI
import AppKit

struct EngineOption: Identifiable {
    let id: String
    let name: String
    let icon: String
    let purpose: String
    let requirement: String
    let url: String
    let command: String?

    var installed: Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch id {
        case "lmstudio": return appExists("LM Studio.app")
        case "ollama": return Machine.executable(["/opt/homebrew/bin/ollama", "/usr/local/bin/ollama", "/Applications/Ollama.app/Contents/Resources/ollama"]) != nil
        case "vllm": return Machine.executable(["/opt/homebrew/bin/vllm", "/usr/local/bin/vllm", "\(home)/.local/bin/vllm"]) != nil
        case "nativ": return appExists("Nativ.app")
        case "jan": return appExists("Jan.app")
        case "llama": return appExists("Llama.app")
        case "gpt4all": return appExists("GPT4All.app") || FileManager.default.fileExists(atPath: "/Applications/gpt4all")
        default: return false
        }
    }

    private func appExists(_ name: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["/Applications/\(name)", "\(home)/Applications/\(name)"].contains { FileManager.default.fileExists(atPath: $0) }
    }

    static let external: [EngineOption] = [
        .init(id: "nativ", name: "Nativ", icon: "macwindow", purpose: "Native MLX app for this Mac with an OpenAI-compatible server.", requirement: "Apple Silicon · macOS 26 or later · Homebrew", url: "https://github.com/Blaizzy/nativ/releases/latest", command: nil),
        .init(id: "ollama", name: "Ollama", icon: "shippingbox", purpose: "Local model library and API for applications.", requirement: "CLI via Homebrew or official app", url: "https://ollama.com/download/mac", command: nil),
        .init(id: "lmstudio", name: "LM Studio", icon: "desktopcomputer", purpose: "Chat, explore models and serve a local API.", requirement: "App via Homebrew or official download", url: "https://lmstudio.ai/download", command: nil),
        .init(id: "jan", name: "Jan", icon: "bubble.left.and.bubble.right", purpose: "Local chat and an OpenAI-compatible server.", requirement: "App via Homebrew", url: "https://jan.ai/", command: nil),
        .init(id: "llama", name: "Llama", icon: "menubar.rectangle", purpose: "ggml menu bar app powered by llama.cpp.", requirement: "Apple Silicon · macOS 15 or later · Homebrew", url: "https://github.com/ggml-org/Llama-macOS", command: nil),
        .init(id: "gpt4all", name: "GPT4All", icon: "circle.grid.2x2", purpose: "Nomic app for chatting with local models.", requirement: "Homebrew provides the installer · macOS 12 or later", url: "https://www.nomic.ai/gpt4all/", command: nil),
        .init(id: "vllm", name: "vLLM · Metal", icon: "bolt.horizontal", purpose: "Serve concurrent requests using the vLLM Metal plugin.", requirement: "Apple Silicon · macOS 15 or later · Homebrew", url: "https://docs.vllm.ai/projects/vllm-metal/en/latest/installation/", command: "brew tap vllm-project/vllm-metal https://github.com/vllm-project/vllm-metal\nbrew install vllm-project/vllm-metal/vllm-metal"),
        .init(id: "koboldcpp", name: "KoboldCpp", icon: "book", purpose: "GGUF application with a local interface and API.", requirement: "Official Apple Silicon binary", url: "https://github.com/LostRuins/koboldcpp/releases/latest", command: nil),
        .init(id: "strata", name: "Strata", icon: "square.3.layers.3d", purpose: "MoE inference using memory and SSD. Check model compatibility.", requirement: "Apple Silicon · macOS 15 or later · requirements vary by model", url: "https://github.com/Niko1221/Strata/releases/latest", command: nil),
        .init(id: "colibri", name: "Colibri", icon: "bird", purpose: "MoE models with experts distributed across GPU, RAM and disk.", requirement: "Release macOS · Python 3 · per-model configuration", url: "https://github.com/JustVugg/colibri/releases/latest", command: nil),
    ]
}

struct AdditionalEnginesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
            LuluSectionHeader("Other engines", symbol: "square.stack.3d.up")
            Text("Each application manages its own models and server.")
                .font(LuluTheme.TypeStyle.body)
                .foregroundStyle(.secondary)
            ForEach(EngineOption.external) { item in
                EngineOptionCard(item: item, model: model)
            }
        }
        .padding(.top, LuluTheme.Space.lg)
    }
}

private struct EngineOptionCard: View {
    let item: EngineOption
    @ObservedObject var model: AppModel

    private var offersHomebrew: Bool {
        ["nativ", "ollama", "lmstudio", "jan", "llama", "gpt4all", "vllm"].contains(item.id)
    }

    private var compatible: Bool {
        let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        switch item.id {
        case "vllm", "llama": return major >= 15
        case "nativ": return major >= 26
        default: return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
            HStack(alignment: .top, spacing: LuluTheme.Space.md) {
                LuluIcon(item.icon)
                VStack(alignment: .leading, spacing: LuluTheme.Space.xs) {
                    Text(item.name).font(LuluTheme.TypeStyle.section)
                    Text(item.purpose)
                        .font(LuluTheme.TypeStyle.body)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: LuluTheme.Space.sm)
                installAction
            }
            HStack(alignment: .firstTextBaseline, spacing: LuluTheme.Space.md) {
                Text(item.requirement)
                    .font(LuluTheme.TypeStyle.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if offersHomebrew { officialLink }
            }
            if let command = item.command { terminalInstructions(command) }
        }
        .padding(LuluTheme.Space.lg)
        .luluCard()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var installAction: some View {
        if !offersHomebrew {
            officialLink
        } else if model.busyEngineID == item.id {
            HStack(spacing: LuluTheme.Space.xs) {
                ProgressView().controlSize(.small).accessibilityHidden(true)
                Text("Installing…").font(LuluTheme.TypeStyle.caption)
            }
            .accessibilityLabel("Installing \(item.name)")
        } else if item.installed {
            LuluStatusBadge("Installed", tone: .success)
        } else {
            Button {
                model.installAdditionalEngine(item.id)
            } label: {
                Label("Install", luluSymbol: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
            .tint(LuluTheme.accent)
            .disabled(model.busyEngineID != nil || !compatible)
            .accessibilityLabel("Install \(item.name) via Homebrew")
            .help(compatible ? "Install via Homebrew" : item.requirement)
        }
    }

    private var officialLink: some View {
        Link(destination: URL(string: item.url)!) {
            Label(item.command == nil ? "Official download" : "Official guide", luluSymbol: "arrow.up.right")
        }
        .font(LuluTheme.TypeStyle.caption)
        .foregroundStyle(LuluTheme.accent)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityHint("Opens the official page for \(item.name)")
    }

    private func terminalInstructions(_ command: String) -> some View {
        DisclosureGroup("Install with Terminal") {
            VStack(alignment: .leading, spacing: LuluTheme.Space.sm) {
                Text(command)
                    .font(LuluTheme.TypeStyle.caption.monospaced())
                    .textSelection(.enabled)
                Button(model.copiedEngineCommand == item.id ? "Command copied" : "Copy command") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    model.copiedEngineCommand = item.id
                }
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(LuluTheme.Space.md)
            .background(LuluTheme.subtle, in: RoundedRectangle(cornerRadius: LuluTheme.Radius.control))
        }
        .font(LuluTheme.TypeStyle.caption)
    }
}
