import Foundation

enum ModelScan {
    static func all() -> [ModelItem] {
        mlx() + gguf()
    }

    private static func mlx() -> [ModelItem] {
        let root = LuluPaths.models.appendingPathComponent("mlx", isDirectory: true)
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return items.compactMap { url -> ModelItem? in
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return nil }
            let configURL = url.appendingPathComponent("config.json")
            let config = (try? Data(contentsOf: configURL)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            guard let config, let files = try? FileManager.default.contentsOfDirectory(atPath: url.path),
                  files.contains(where: { $0.lowercased().hasSuffix(".safetensors") }) else { return nil }
            let vision = isVision(config, name: url.lastPathComponent)
            return ModelItem(
                id: url.path,
                name: url.lastPathComponent,
                engineID: vision ? "mlx-vlm" : "mlx-lm",
                path: url.path,
                mmproj: nil,
                sizeBytes: directorySize(url),
                arch: arch(fromConfig: config)
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func gguf() -> [ModelItem] {
        let root = LuluPaths.models.appendingPathComponent("gguf", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [(url: URL, size: UInt64, parent: String, name: String)] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "gguf" else { continue }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { UInt64($0) } ?? 0
            files.append((url, size, url.deletingLastPathComponent().path, url.lastPathComponent))
        }

        let grouped = Dictionary(grouping: files, by: \.parent)
        var models: [ModelItem] = []
        for (_, group) in grouped {
            let projector = group.first { Hub.isProjector($0.name) }
            for file in group where !Hub.isAuxiliaryGGUF(file.name) {
                var size = file.size
                if let split = Hub.shard(file.url.path) {
                    guard split.index == 1 else { continue }
                    let parts = group.filter {
                        guard let part = Hub.shard($0.url.path) else { return false }
                        return part.prefix == split.prefix && part.count == split.count
                    }
                    guard parts.count == split.count else { continue }
                    size = parts.reduce(0) { $0 + $1.size }
                }
                let name = file.url.deletingPathExtension().lastPathComponent
                models.append(ModelItem(
                    id: file.url.path,
                    name: name,
                    engineID: "llama.cpp",
                    path: file.url.path,
                    mmproj: projector?.url.path,
                    sizeBytes: size,
                    arch: GGUF.architecture(at: file.url.path)
                ))
            }
        }
        return models.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func arch(fromConfig root: [String: Any]) -> ModelArch? {
        let source = languageConfig(root)
        let layers = kvLayerCount(source)
        let heads = integer(source["num_key_value_heads"]) ?? integer(source["num_attention_heads"]) ?? 0
        let headDim = integer(source["head_dim"])
            ?? quotient(integer(source["hidden_size"]), integer(source["num_attention_heads"]))
            ?? 0
        guard layers > 0, heads > 0, headDim > 0 else { return nil }
        let trained = integer(source["max_position_embeddings"]) ?? integer(root["max_position_embeddings"])
        let total = integer(source["num_hidden_layers"]) ?? layers
        let summary = layers == total
            ? "\(layers) layers, float16"
            : "\(layers) of \(total) layers with KV, float16"
        return ModelArch(
            kvLayers: layers,
            kvHeads: heads,
            headDim: headDim,
            trainedContext: trained,
            elementBytes: 2,
            summary: summary
        )
    }

    private static func languageConfig(_ root: [String: Any]) -> [String: Any] {
        for key in ["text_config", "language_config", "llm_config"] {
            if let nested = root[key] as? [String: Any],
               nested["num_hidden_layers"] != nil || nested["num_key_value_heads"] != nil {
                return nested
            }
        }
        return root
    }

    private static func kvLayerCount(_ source: [String: Any]) -> Int {
        if let kinds = source["layer_types"] as? [String] {
            let full = kinds.reduce(into: 0) { count, kind in
                let name = kind.lowercased()
                if name.contains("linear") { return }
                if name.contains("full") || name.contains("global") || name.contains("attention") {
                    count += 1
                }
            }
            if full > 0 { return full }
        }
        return integer(source["num_hidden_layers"]) ?? 0
    }

    private static func isVision(_ root: [String: Any], name: String) -> Bool {
        if root["vision_config"] != nil || root["image_token_id"] != nil { return true }
        let type = (root["model_type"] as? String ?? "").lowercased()
        if type.contains("vl") || type.contains("minicpm") || type.contains("llava") || type.contains("qwen3_5") || type.contains("gemma3") {
            return true
        }
        return nameLooksVision(name)
    }

    private static func nameLooksVision(_ name: String) -> Bool {
        let folded = name.lowercased()
        return folded.contains("minicpm") || folded.contains("-vl") || folded.contains("vision") || folded.contains("vlm")
    }

    private static func integer(_ value: Any?) -> Int? {
        switch value {
        case let number as Int: return number
        case let number as Double: return Int(number)
        case let number as NSNumber: return number.intValue
        default: return nil
        }
    }

    private static func quotient(_ numerator: Int?, _ denominator: Int?) -> Int? {
        guard let numerator, let denominator, denominator > 0 else { return nil }
        return numerator / denominator
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
