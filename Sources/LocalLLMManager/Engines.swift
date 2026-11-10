import Foundation

struct EngineStatus: Identifiable, Equatable {
    var id: String
    var name: String
    var blurb: String
    var installed: Bool
    var managed: Bool
    var version: String
    var binary: String
    var sizeBytes: UInt64?
}

enum EngineCatalog {
    static let specs: [Spec] = {
        var items: [Spec] = []
        #if arch(arm64)
        items += [
        Spec(
            id: "mlx-lm",
            name: "mlx-lm",
            blurb: "Text in MLX with an OpenAI-compatible API.",
            install: .uv(package: "mlx-lm", directory: "mlx-lm", distPrefix: "mlx_lm-", binary: "mlx_lm.server")
        ),
        Spec(
            id: "mlx-vlm",
            name: "mlx-vlm",
            blurb: "Text and vision in MLX with an OpenAI-compatible API.",
            install: .uv(package: "mlx-vlm", directory: "mlx-vlm", distPrefix: "mlx_vlm-", binary: "mlx_vlm.server")
        ),
        ]
        #endif
        items += [Spec(
            id: "llama.cpp",
            name: "llama.cpp",
            blurb: "GGUF on llama-server with GPU flash attention.",
            install: .brew(formula: "llama.cpp", cellar: "llama.cpp", binary: "llama-server")
        )]
        return items
    }()

    struct Spec {
        var id: String
        var name: String
        var blurb: String
        var install: Install
    }

    enum Install {
        case uv(package: String, directory: String, distPrefix: String, binary: String)
        case brew(formula: String, cellar: String, binary: String)
    }

    static func quick() -> [EngineStatus] {
        specs.map { status(for: $0, measure: false) }
    }

    static func measured() -> [EngineStatus] {
        specs.map { status(for: $0, measure: true) }
    }

    static func spec(_ id: String) -> Spec? {
        specs.first { $0.id == id }
    }

    static func installCommand(for spec: Spec) -> (executable: String, arguments: [String], env: [String: String])? {
        switch spec.install {
        case let .uv(package, _, _, _):
            guard let uv = uvBinary() else { return nil }
            return (uv, ["tool", "install", package], [:])
        case let .brew(formula, _, _):
            guard let brew = brewBinary() else { return nil }
            return (brew, ["install", formula], brewEnv)
        }
    }

    static func removeCommand(for spec: Spec) -> (executable: String, arguments: [String], env: [String: String])? {
        switch spec.install {
        case let .uv(package, _, _, _):
            guard let uv = uvBinary() else { return nil }
            return (uv, ["tool", "uninstall", package], [:])
        case let .brew(formula, _, _):
            guard let brew = brewBinary() else { return nil }
            return (brew, ["uninstall", formula], brewEnv)
        }
    }

    /// Apaga só o que este instalador criou. Modelo em ~/models não entra aqui.
    static func sweepLeftovers(for spec: Spec) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch spec.install {
        case let .uv(_, directory, _, binary):
            let tools = home.appendingPathComponent(".local/share/uv/tools", isDirectory: true)
            removeIfInside(tools.appendingPathComponent(directory), root: tools)
            let shim = home.appendingPathComponent(".local/bin").appendingPathComponent(binary)
            if let text = try? String(contentsOf: shim, encoding: .utf8), text.contains("/uv/tools/\(directory)/") {
                try? FileManager.default.removeItem(at: shim)
            }
        case let .brew(_, cellar, binary):
            for prefix in ["/opt/homebrew", "/usr/local"] {
                let root = URL(fileURLWithPath: prefix).appendingPathComponent("Cellar", isDirectory: true)
                removeIfInside(root.appendingPathComponent(cellar), root: root)
                let link = URL(fileURLWithPath: prefix).appendingPathComponent("bin").appendingPathComponent(binary)
                let destination = link.resolvingSymlinksInPath().path
                let broken = !FileManager.default.fileExists(atPath: destination)
                let ours = destination.contains("/Cellar/\(cellar)/")
                if (try? link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true, broken || ours {
                    try? FileManager.default.removeItem(at: link)
                }
            }
        }
    }

    static func missingInstallerMessage(for spec: Spec) -> String? {
        switch spec.install {
        case .uv:
            return uvBinary() == nil ? "uv was not found in ~/.local/bin or Homebrew." : nil
        case .brew:
            return brewBinary() == nil ? "Homebrew was not found in /opt/homebrew or /usr/local." : nil
        }
    }

    private static let brewEnv = ["HOMEBREW_NO_AUTO_UPDATE": "1", "HOMEBREW_NO_ENV_HINTS": "1"]

    private static func status(for spec: Spec, measure: Bool) -> EngineStatus {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch spec.install {
        case let .uv(_, directory, distPrefix, binary):
            let tool = URL(fileURLWithPath: home).appendingPathComponent(".local/share/uv/tools/\(directory)")
            let managed = FileManager.default.fileExists(atPath: tool.path)
            let binaryPath = Machine.executable([
                "\(home)/.local/bin/\(binary)",
                "/opt/homebrew/bin/\(binary)",
                "/usr/local/bin/\(binary)",
            ]) ?? ""
            return EngineStatus(
                id: spec.id,
                name: spec.name,
                blurb: spec.blurb,
                installed: managed || !binaryPath.isEmpty,
                managed: managed,
                version: uvVersion(tool: tool, prefix: distPrefix),
                binary: binaryPath,
                sizeBytes: measure && managed ? directorySize(tool) : nil
            )
        case let .brew(_, cellar, binary):
            let cellarURL = cellarURL(named: cellar)
            let managed = cellarURL != nil
            let binaryPath = Machine.executable([
                "/opt/homebrew/bin/\(binary)",
                "/usr/local/bin/\(binary)",
                "\(home)/.local/bin/\(binary)",
            ]) ?? ""
            return EngineStatus(
                id: spec.id,
                name: spec.name,
                blurb: spec.blurb,
                installed: managed || !binaryPath.isEmpty,
                managed: managed,
                version: cellarURL?.lastPathComponent ?? "",
                binary: binaryPath,
                sizeBytes: measure ? cellarURL.map(directorySize) : nil
            )
        }
    }

    private static func uvVersion(tool: URL, prefix: String) -> String {
        let site = tool.appendingPathComponent("lib")
        guard let python = try? FileManager.default.contentsOfDirectory(at: site, includingPropertiesForKeys: nil)
            .first(where: { $0.lastPathComponent.hasPrefix("python") })?
            .appendingPathComponent("site-packages") else { return "" }
        guard let entries = try? FileManager.default.contentsOfDirectory(at: python, includingPropertiesForKeys: nil) else { return "" }
        guard let match = entries.first(where: { $0.lastPathComponent.hasPrefix(prefix) && $0.lastPathComponent.hasSuffix(".dist-info") }) else { return "" }
        let name = match.lastPathComponent
        return String(name.dropFirst(prefix.count).dropLast(".dist-info".count))
    }

    private static func cellarURL(named cellar: String) -> URL? {
        for prefix in ["/opt/homebrew/Cellar", "/usr/local/Cellar"] {
            let root = URL(fileURLWithPath: prefix).appendingPathComponent(cellar, isDirectory: true)
            guard let versions = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil),
                  let latest = versions.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).last else { continue }
            return latest
        }
        return nil
    }

    private static func uvBinary() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return Machine.executable(["\(home)/.local/bin/uv", "/opt/homebrew/bin/uv", "/usr/local/bin/uv"])
    }

    private static func brewBinary() -> String? {
        Machine.executable(["/opt/homebrew/bin/brew", "/usr/local/bin/brew"])
    }

    private static func removeIfInside(_ url: URL, root: URL) {
        let target = url.resolvingSymlinksInPath().path
        let base = root.resolvingSymlinksInPath().path
        guard target != base, target.hasPrefix(base + "/") else { return }
        guard FileManager.default.fileExists(atPath: target) else { return }
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: target))
    }

    private static func directorySize(_ url: URL) -> UInt64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: UInt64 = 0
        for case let file as URL in enumerator {
            guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            total += UInt64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }
}
