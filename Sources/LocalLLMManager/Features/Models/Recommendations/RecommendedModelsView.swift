import SwiftUI

struct RecommendedModelsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let memory = RecommendedModel.memoryGB
        let mlx = MLXRecommendation.fitting(memoryGB: memory, supportsMLX: Machine.supportsMLX)
        let gguf = TrayRecommendation.fitting(memoryGB: memory)
        VStack(alignment: .leading, spacing: LuluTheme.Space.sm) {
            LuluSectionHeader("Recommended for this Mac", symbol: "sparkles")
            Text("\(memory) GB RAM · \(Machine.supportsMLX ? "Apple silicon" : "Intel")")
                .font(.caption).foregroundStyle(.secondary)
            if mlx.isEmpty && gguf.isEmpty {
                Text("Browse the catalog below for smaller models.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), spacing: LuluTheme.Space.sm)],
                      alignment: .leading, spacing: LuluTheme.Space.sm) {
                ForEach(mlx.prefix(3)) { choice in
                    preset(choice.name, detail: "MLX") { model.browseRecommendation(choice.repo) }
                }
                ForEach(gguf.prefix(Machine.supportsMLX ? 3 : 5)) { choice in
                    preset("\(choice.name) · \(choice.size) · \(choice.quantization)", detail: "GGUF · \(Format.bytes(choice.bytes))") {
                        model.browseRecommendation(choice)
                    }
                }
            }
            DisclosureGroup("Browse all model families") {
                VStack(spacing: LuluTheme.Space.sm) {
                    ForEach(RecommendedModel.familiesByMemory) { recommendation in
                        row(recommendation)
                    }
                }
                .padding(.top, LuluTheme.Space.sm)
            }
        }
        .padding(LuluTheme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .luluCard()
    }

    private func preset(_ title: String, detail: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: LuluTheme.Space.sm) {
            VStack(alignment: .leading, spacing: LuluTheme.Space.xs) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: LuluTheme.Space.sm)
            Button("View files", action: action)
                .disabled(model.searching)
                .accessibilityLabel("View files for \(title)")
        }
        .padding(LuluTheme.Space.sm)
        .background(LuluTheme.subtle, in: RoundedRectangle(cornerRadius: LuluTheme.Radius.control))
    }

    private func row(_ recommendation: RecommendedModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: LuluTheme.Space.xs) {
                Text(recommendation.name).font(.callout.weight(.medium))
                Text("Catalog guide: \(recommendation.minimumMemoryGB) GB RAM or more")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: LuluTheme.Space.sm)
            Menu("Choose variant") {
                Section("GGUF · llama.cpp") {
                    ForEach(recommendation.gguf, id: \.self) { repo in
                        Button(recommendedRepoLabel(repo)) { model.browseRecommendation(repo) }
                    }
                }
                if !recommendation.availableMLX.isEmpty {
                    Section("MLX · Mac with Apple silicon") {
                        ForEach(recommendation.availableMLX, id: \.self) { repo in
                            Button(recommendedRepoLabel(repo)) { model.browseRecommendation(repo) }
                        }
                    }
                }
            }
            .fixedSize()
            .accessibilityLabel("Choose a variant of \(recommendation.name)")
        }
        .padding(LuluTheme.Space.sm)
        .background(LuluTheme.subtle, in: RoundedRectangle(cornerRadius: LuluTheme.Radius.control))
    }

    private func recommendedRepoLabel(_ repo: String) -> String {
        // Show the publisher in the variant menu when the conversions differ.
        let parts = repo.split(separator: "/", maxSplits: 1)
        guard parts.count == 2 else { return repo }
        return "\(parts[1]) · \(parts[0])"
    }
}
