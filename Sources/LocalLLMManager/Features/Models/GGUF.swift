import Foundation

enum GGUF {
    static func architecture(at path: String) -> ModelArch? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let reader = Reader(handle: handle)
        guard reader.bytes(4) == [0x47, 0x47, 0x55, 0x46] else { return nil }
        guard let version = reader.u32(), version >= 2 else { return nil }
        _ = reader.u64()
        guard let pairs = reader.u64(), pairs <= 100_000 else { return nil }

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
            guard let data = take(count), count > 0 else { return nil }
            return [UInt8](data)
        }

        func u32() -> UInt32? { fixed(UInt32.self) }
        func u64() -> UInt64? { fixed(UInt64.self) }

        func string() -> String? {
            guard let length = u64(), length <= 1_000_000, let data = take(Int(length)) else { return nil }
            return String(data: data, encoding: .utf8)
        }

        func skip(_ type: UInt32) -> Bool {
            switch type {
            case 8:
                guard let length = u64(), advance(length) else { return false }
                return true
            case 9:
                guard let element = u32(), let count = u64(), count <= 1_000_000 else { return false }
                if element == 8 {
                    for _ in 0..<count where !skip(8) { return false }
                    return true
                }
                guard let stride = stride(element), advance(count * UInt64(stride)) else { return false }
                return true
            default:
                guard let stride = stride(type), advance(UInt64(stride)) else { return false }
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
                guard let value = fixed(UInt16.self) else { return nil }
                return .int(Int(value))
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

        private func fixed<T: FixedWidthInteger>(_ type: T.Type) -> T? {
            let count = MemoryLayout<T>.size
            guard let data = take(count) else { return nil }
            return data.withUnsafeBytes { raw in
                guard raw.count >= count else { return nil }
                return T(littleEndian: raw.loadUnaligned(as: T.self))
            }
        }

        private func take(_ count: Int) -> Data? {
            guard count >= 0, pull(count), position >= bufferStart else { return nil }
            let start = Int(position - bufferStart)
            let copied: Data? = buffer.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return count == 0 ? Data() : nil }
                guard start >= 0, start + count <= raw.count else { return nil }
                return Data(bytes: base + start, count: count)
            }
            guard let copied else { return nil }
            position += UInt64(count)
            return copied
        }

        private func advance(_ count: UInt64) -> Bool {
            guard position <= UInt64.max - count else { return false }
            position += count
            return true
        }

        private func pull(_ count: Int) -> Bool {
            guard count >= 0, position <= UInt64.max - UInt64(count) else { return false }
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
