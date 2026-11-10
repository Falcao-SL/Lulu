import Foundation

struct ModelArch: Equatable, Hashable, Codable {
    var kvLayers: Int
    var kvHeads: Int
    var headDim: Int
    var trainedContext: Int?
    var elementBytes: Int
    var summary: String

    func kvBytes(tokens: Int) -> UInt64 {
        guard kvLayers > 0, kvHeads > 0, headDim > 0, tokens > 0, elementBytes > 0 else { return 0 }
        let perToken = UInt64(kvLayers) * UInt64(kvHeads) * UInt64(headDim) * UInt64(elementBytes)
        return perToken * 2 * UInt64(tokens)
    }
}

struct ModelItem: Identifiable, Equatable, Hashable {
    var id: String
    var name: String
    var engineID: String
    var path: String
    var mmproj: String?
    var sizeBytes: UInt64
    var arch: ModelArch?
}

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
            let vision = config.map { isVision($0, name: url.lastPathComponent) } ?? nameLooksVision(url.lastPathComponent)
            return ModelItem(
                id: url.path,
                name: url.lastPathComponent,
                engineID: vision ? "mlx-vlm" : "mlx-lm",
                path: url.path,
                mmproj: nil,
                sizeBytes: directorySize(url),
                arch: config.flatMap(arch(fromConfig:))
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
            let projector = group.first { $0.name.lowercased().hasPrefix("mmproj") }
            for file in group where !file.name.lowercased().hasPrefix("mmproj") {
                let name = file.url.deletingPathExtension().lastPathComponent
                models.append(ModelItem(
                    id: file.url.path,
                    name: name,
                    engineID: "llama.cpp",
                    path: file.url.path,
                    mmproj: projector?.url.path,
                    sizeBytes: file.size,
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

enum GGUF {
    static func architecture(at path: String) -> ModelArch? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let reader = Reader(handle: handle)
        guard reader.bytes(4) == [0x47, 0x47, 0x55, 0x46] else { return nil }
        guard let version = reader.u32(), version >= 2 else { return nil }
        _ = reader.u64()
        guard let pairs = reader.u64() else { return nil }

        var values: [String: Meta] = [:]
        for _ in 0..<pairs {
            guard let key = reader.string(), let type = reader.u32() else { return nil }
            if interesting(key) {
                guard let meta = reader.read(type) else { return nil }
                values[key] = meta
            } else if !reader.skip(type) {
                return nil
            }
        }

        guard case let .text(arch) = values["general.architecture"] else { return nil }
        let prefix = arch + "."
        let layers = values[prefix + "block_count"]?.int ?? 0
        let heads = values[prefix + "attention.head_count"]?.int ?? 0
        let kvHeads = values[prefix + "attention.head_count_kv"]?.int ?? heads
        let embedding = values[prefix + "embedding_length"]?.int ?? 0
        let keyLength = values[prefix + "attention.key_length"]?.int ?? 0
        let headDim = keyLength > 0 ? keyLength : (heads > 0 ? embedding / heads : 0)
        guard layers > 0, kvHeads > 0, headDim > 0 else { return nil }
        return ModelArch(
            kvLayers: layers,
            kvHeads: kvHeads,
            headDim: headDim,
            trainedContext: values[prefix + "context_length"]?.int,
            elementBytes: 2,
            summary: "\(layers) layers, float16"
        )
    }

    private static func interesting(_ key: String) -> Bool {
        key == "general.architecture"
            || key.hasSuffix(".block_count")
            || key.hasSuffix(".attention.head_count")
            || key.hasSuffix(".attention.head_count_kv")
            || key.hasSuffix(".embedding_length")
            || key.hasSuffix(".attention.key_length")
            || key.hasSuffix(".context_length")
    }

    private enum Meta {
        case text(String)
        case int(Int)

        var int: Int? {
            if case let .int(value) = self { return value }
            return nil
        }
    }

    private final class Reader {
        let handle: FileHandle
        private var buffer = Data()
        private var bufferStart: UInt64 = 0
        private var position: UInt64 = 0

        init(handle: FileHandle) {
            self.handle = handle
        }

        func bytes(_ count: Int) -> [UInt8]? {
            guard pull(count), count > 0 else { return nil }
            let start = Int(position - bufferStart)
            let slice = buffer[start..<(start + count)]
            position += UInt64(count)
            return Array(slice)
        }

        func u32() -> UInt32? {
            guard pull(4) else { return nil }
            let start = Int(position - bufferStart)
            let value = buffer[start..<(start + 4)].withUnsafeBytes { $0.load(as: UInt32.self) }
            position += 4
            return UInt32(littleEndian: value)
        }

        func u64() -> UInt64? {
            guard pull(8) else { return nil }
            let start = Int(position - bufferStart)
            let value = buffer[start..<(start + 8)].withUnsafeBytes { $0.load(as: UInt64.self) }
            position += 8
            return UInt64(littleEndian: value)
        }

        func string() -> String? {
            guard let length = u64() else { return nil }
            if length > 1_000_000 { return nil }
            guard pull(Int(length)) else { return nil }
            let start = Int(position - bufferStart)
            let slice = buffer[start..<(start + Int(length))]
            position += length
            return String(data: slice, encoding: .utf8)
        }

        func skip(_ type: UInt32) -> Bool {
            switch type {
            case 8:
                guard let length = u64() else { return false }
                position += length
                return true
            case 9:
                guard let element = u32(), let count = u64() else { return false }
                if element == 8 {
                    for _ in 0..<count where !skip(8) { return false }
                    return true
                }
                guard let stride = stride(element) else { return false }
                position += count * UInt64(stride)
                return true
            default:
                guard let stride = stride(type) else { return false }
                position += UInt64(stride)
                return true
            }
        }

        func read(_ type: UInt32) -> Meta? {
            switch type {
            case 8:
                guard let text = string() else { return nil }
                return .text(text)
            case 4, 5, 7:
                guard let value = u32() else { return nil }
                return .int(Int(value))
            case 10, 11:
                guard let value = u64(), value < UInt64(Int.max) else { return nil }
                return .int(Int(value))
            case 0, 1:
                guard let raw = bytes(1) else { return nil }
                return .int(Int(raw[0]))
            case 2, 3:
                guard pull(2) else { return nil }
                let start = Int(position - bufferStart)
                let value = buffer[start..<(start + 2)].withUnsafeBytes { $0.load(as: UInt16.self) }
                position += 2
                return .int(Int(UInt16(littleEndian: value)))
            default:
                return skip(type) ? .int(0) : nil
            }
        }

        private func stride(_ type: UInt32) -> Int? {
            switch type {
            case 0, 1, 7: return 1
            case 2, 3: return 2
            case 4, 5, 6: return 4
            case 10, 11, 12: return 8
            default: return nil
            }
        }

        private func pull(_ count: Int) -> Bool {
            let needed = position + UInt64(count)
            if needed <= bufferStart + UInt64(buffer.count) { return true }
            if count > 1_048_576 { return false }
            do {
                try handle.seek(toOffset: position)
            } catch {
                return false
            }
            let chunk = max(count, 262_144)
            let data = handle.readData(ofLength: chunk)
            guard data.count >= count else { return false }
            buffer = data
            bufferStart = position
            return true
        }
    }
}
