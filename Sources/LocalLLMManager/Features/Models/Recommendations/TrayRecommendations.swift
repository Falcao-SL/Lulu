import Foundation

struct TrayRecommendation: Identifiable {
    let name: String
    let size: String
    let quantization: String
    let repo: String
    let weight: String
    var projector: String?
    let bytes: UInt64
    let memoryGB: Int

    var id: String { repo }

    func matches(_ item: ModelItem) -> Bool {
        item.engineID == "llama.cpp"
            && URL(fileURLWithPath: item.path).lastPathComponent.caseInsensitiveCompare(weight) == .orderedSame
    }

    func matches(_ job: DownloadJob) -> Bool {
        job.repo == repo && job.files.contains { $0.path == weight }
    }

    func selectFiles(_ files: [ListedFile]) throws -> [ListedFile] {
        let paths = Set([weight, projector].compactMap { $0 })
        guard paths.isSubset(of: Set(files.map(\.path))) else {
            throw HubError(message: "This download changed on Hugging Face. Choose a variant in Models.")
        }
        return files.map { file in
            var result = file
            result.selected = paths.contains(file.path)
            return result
        }
    }

    static func fitting(memoryGB: Int) -> [Self] {
        options.filter { $0.memoryGB <= memoryGB }
    }

    // Exact artifacts from the llama.app catalog, including the matched projector when present.
    // RAM cutoffs are suggestions for modest context sizes, not limits on manual downloads.
    static let options: [Self] = [
        .init(name: "GPT-OSS", size: "20B", quantization: "MXFP4",
              repo: "ggml-org/gpt-oss-20b-GGUF", weight: "gpt-oss-20b-MXFP4.gguf",
              bytes: 12_109_566_624, memoryGB: 24),
        .init(name: "Gemma 4", size: "E2B", quantization: "Q8_0",
              repo: "ggml-org/gemma-4-E2B-it-GGUF", weight: "gemma-4-E2B-it-Q8_0.gguf",
              projector: "mmproj-gemma-4-E2B-it-Q8_0.gguf", bytes: 5_524_859_616, memoryGB: 16),
        .init(name: "Gemma 4", size: "E4B", quantization: "Q8_0",
              repo: "ggml-org/gemma-4-E4B-it-GGUF", weight: "gemma-4-E4B-it-Q8_0.gguf",
              projector: "mmproj-gemma-4-E4B-it-Q8_0.gguf", bytes: 8_591_112_192, memoryGB: 16),
        .init(name: "Gemma 4", size: "12B", quantization: "Q8_0",
              repo: "ggml-org/gemma-4-12B-it-GGUF", weight: "gemma-4-12B-it-Q8_0.gguf",
              projector: "mmproj-gemma-4-12B-it-Q8_0.gguf", bytes: 12_828_629_568, memoryGB: 24),
        .init(name: "Gemma 4", size: "26B-A4B", quantization: "Q4_0",
              repo: "ggml-org/gemma-4-26B-A4B-it-GGUF", weight: "gemma-4-26B-A4B-it-Q4_0.gguf",
              projector: "mmproj-gemma-4-26B-A4B-it-Q8_0.gguf", bytes: 15_424_554_592, memoryGB: 24),
        .init(name: "LFM 2.5", size: "24B-A2B", quantization: "Q4_K_M",
              repo: "ggml-org/LFM2.5-24B-A2B-GGUF", weight: "LFM2.5-24B-A2B-Q4_K_M.gguf",
              bytes: 14_526_259_296, memoryGB: 24),
        .init(name: "LFM 3 Omni", size: "2B", quantization: "Q8_0",
              repo: "ggml-org/LFM3-Omni-2B-GGUF", weight: "LFM3-Omni-2B-Q8_0.gguf",
              projector: "mmproj-LFM3-Omni-2B-Q8_0.gguf", bytes: 2_353_083_168, memoryGB: 8),
        .init(name: "LFM 3", size: "1.7B", quantization: "Q4_K_M",
              repo: "ggml-org/LFM3-1.7B-GGUF", weight: "LFM3-1.7B-Q4_K_M.gguf",
              bytes: 1_099_627_776, memoryGB: 8),
        .init(name: "Qwen 3.5", size: "0.8B", quantization: "Q8_0",
              repo: "ggml-org/Qwen3.5-0.8B-GGUF", weight: "Qwen3.5-0.8B-Q8_0.gguf",
              bytes: 833_592_096, memoryGB: 8),
    ]
}
