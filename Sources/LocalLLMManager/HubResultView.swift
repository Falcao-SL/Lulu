import SwiftUI

struct HubMetadataView: View {
    let hit: HubHit

    var body: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.sm) {
            adaptiveRow {
                Label("Publisher · \(hit.publisher)", luluSymbol: "person.crop.square")
                Label("Source laboratory · \(hit.laboratory)", luluSymbol: "building.2")
            }

            adaptiveRow {
                Label(hit.format, luluSymbol: "cube")
                    .accessibilityLabel("Format · \(hit.format)")
                Text("Quantization · \(hit.quantization)")
                if hit.parameters > 0 {
                    let billions = Double(hit.parameters) / 1_000_000_000
                    Text("\(billions, format: .number.precision(.fractionLength(1)))B parameters")
                }
            }
            .foregroundStyle(.primary)

            if !hit.baseModel.isEmpty {
                Text("Base model · \(hit.baseModel)")
                    .textSelection(.enabled)
            }
            if !hit.task.isEmpty || !hit.license.isEmpty || !hit.modified.isEmpty {
                adaptiveRow {
                    if !hit.task.isEmpty { Label(hit.task, luluSymbol: "text.bubble") }
                    if !hit.license.isEmpty { Label(hit.license, luluSymbol: "doc.plaintext") }
                    if !hit.modified.isEmpty {
                        Text("Updated \(String(hit.modified.prefix(10)))")
                    }
                }
            }
        }
        .font(LuluTheme.TypeStyle.caption)
        .foregroundStyle(.secondary)
    }

    private func adaptiveRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: LuluTheme.Space.lg) { content() }
                .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: LuluTheme.Space.xs) { content() }
        }
    }
}

struct HubResultView: View {
    let hit: HubHit
    let selected: Bool
    let action: () -> Void

    private var repositoryName: String {
        hit.id.split(separator: "/").last.map(String.init) ?? hit.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
            HStack(alignment: .firstTextBaseline, spacing: LuluTheme.Space.md) {
                Text(repositoryName)
                    .font(LuluTheme.TypeStyle.section)
                    .lineLimit(2)
                    .help(hit.id)
                    .accessibilityLabel(hit.id)
                Spacer(minLength: 0)
                if selected {
                    LuluStatusBadge("Selected", tone: .success)
                } else {
                    Button(action: action) { Label("View files", luluSymbol: "folder") }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                        .accessibilityLabel("View files for \(hit.id)")
                }
            }

            HubMetadataView(hit: hit)
            Divider()
            HStack(spacing: LuluTheme.Space.lg) {
                Label("\(Format.tokens(hit.downloads)) downloads", luluSymbol: "arrow.down")
                Label("\(Format.tokens(hit.likes)) likes", luluSymbol: "heart")
                Spacer(minLength: 0)
                if let repositoryURL = URL(string: "https://huggingface.co/\(hit.id)") {
                    Link(destination: repositoryURL) {
                        Label("Hugging Face", luluSymbol: "arrow.up.right")
                    }
                    .foregroundStyle(LuluTheme.accent)
                }
            }
            .font(LuluTheme.TypeStyle.caption)
            .foregroundStyle(.secondary)
        }
        .padding(LuluTheme.Space.lg)
        .luluCard()
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: LuluTheme.Radius.card, style: .continuous)
                    .strokeBorder(LuluTheme.accent)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
