import Foundation

struct RecommendedModel: Identifiable {
    let name: String
    let minimumMemoryGB: Int
    let gguf: [String]
    let mlx: [String]

    var id: String { name }

    var availableMLX: [String] {
        Machine.supportsMLX ? mlx : []
    }

    static let memoryGB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))

    static var familiesByMemory: [RecommendedModel] {
        catalog.sorted { ($0.minimumMemoryGB, $0.name) < ($1.minimumMemoryGB, $1.name) }
    }
}

struct MLXRecommendation: Identifiable {
    let name: String
    let repo: String
    let minimumMemoryGB: Int

    var id: String { repo }

    static func fitting(memoryGB: Int, supportsMLX: Bool) -> [Self] {
        guard supportsMLX else { return [] }
        let options: [Self] = [
            .init(name: "Qwen 3.8 · 27B · 4-bit", repo: "mlx-community/Qwen3.8-27B-4bit", minimumMemoryGB: 32),
            .init(name: "Gemma 4 · E4B · 4-bit", repo: "mlx-community/gemma-4-e4b-it-4bit", minimumMemoryGB: 16),
            .init(name: "LFM 3 Omni · 2B · 4-bit", repo: "LiquidAI/LFM3-Omni-2B-MLX-4bit", minimumMemoryGB: 8),
            .init(name: "LFM 3 · 1.7B · 4-bit", repo: "LiquidAI/LFM3-1.7B-MLX-4bit", minimumMemoryGB: 8),
        ]
        return options.filter { $0.minimumMemoryGB <= memoryGB }
    }
}
