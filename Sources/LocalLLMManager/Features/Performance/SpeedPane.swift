import SwiftUI
import AppKit

struct SpeedPane: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let memory = model.memory
        VStack(alignment: .leading, spacing: LuluTheme.Space.lg) {
            LuluPageHeader("Performance", symbol: "gauge.with.dots.needle.67percent")
            VStack(alignment: .leading, spacing: LuluTheme.Space.xs) {
                if model.phase == .ready {
                    Text(Format.rate(memory.predictRate)).font(LuluTheme.TypeStyle.metric)
                    Text(model.runningModel?.engineID == "mlx-vlm"
                         ? "average tokens per second during generation"
                         : "tokens per second during generation")
                        .font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                } else {
                    Text(memory.total == 0 ? "—" : Format.bytes(memory.available)).font(LuluTheme.TypeStyle.metric)
                    Text("available memory").font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
                }
            }.accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
                LuluSectionHeader("Server process", symbol: "server.rack")
                LazyVGrid(columns: columns, alignment: .leading, spacing: LuluTheme.Space.lg) {
                    tile("Prompt", Format.rate(memory.promptRate) + " tok/s")
                    tile("Process", Format.bytes(memory.footprint))
                    tile("Weights", Format.bytes(memory.weights))
                    tile("KV reserved", Format.bytes(memory.kvReserved))
                    tile("KV used", Format.bytes(memory.kvUsed))
                    tile("Context", contextLine(memory))
                }
                Text(memory.kvSummary).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
            }
            .padding(LuluTheme.Space.lg).luluCard()

            VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
                LuluSectionHeader("Mac memory", symbol: "memorychip")
                LazyVGrid(columns: columns, alignment: .leading, spacing: LuluTheme.Space.lg) {
                    tile("Total", Format.bytes(memory.total))
                    tile("Available", Format.bytes(memory.available))
                    tile("Wired", Format.bytes(memory.wired))
                    tile("Compressed", Format.bytes(memory.compressed))
                    tile("Active", Format.bytes(memory.active))
                    tile("Purgeable", Format.bytes(memory.purgeable))
                }
                Meter(footprint: fraction(memory.footprint, memory.total), other: fraction(otherUsed(memory), memory.total))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), alignment: .leading)], alignment: .leading, spacing: LuluTheme.Space.md) {
                    memoryLegend("Server", value: memory.footprint, color: Meter.serverColor)
                    memoryLegend("Other processes", value: otherUsed(memory), color: Meter.otherColor)
                    memoryLegend("Available", value: memory.available, color: Meter.availableColor)
                }
                .font(LuluTheme.TypeStyle.caption)
                HStack {
                    Spacer(minLength: 0)
                    Button("Purge memory", luluSymbol: "sparkles") { model.confirmPurge = true }
                }
            }
            .padding(LuluTheme.Space.lg).luluCard()

            Text("llama.cpp reserves KV cache at startup. For MLX, used KV estimates process growth after loading weights.")
                .font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3)

    private func memoryLegend(_ title: String, value: UInt64, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.primary.opacity(0.18)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.secondary).lineLimit(1)
                Text(Format.bytes(value)).font(.body.monospacedDigit().weight(.semibold))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func contextLine(_ memory: MemorySnapshot) -> String {
        if let peak = memory.contextPeak {
            return "\(Format.tokens(peak)) / \(Format.tokens(memory.contextTokens))"
        }
        return Format.tokens(memory.contextTokens)
    }

    private func otherUsed(_ memory: MemorySnapshot) -> UInt64 {
        let used = memory.total > memory.available ? memory.total - memory.available : 0
        return used > memory.footprint ? used - memory.footprint : 0
    }

    private func fraction(_ part: UInt64, _ total: UInt64) -> Double {
        guard total > 0 else { return 0 }
        return min(1, Double(part) / Double(total))
    }
}

private struct Meter: View {
    static let serverColor = LuluTheme.accent
    static let otherColor = LuluTheme.accent.opacity(0.38)
    static let availableColor = LuluTheme.accent.opacity(0.10)
    var footprint: Double
    var other: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            HStack(spacing: 0) {
                Rectangle().fill(Self.serverColor).frame(width: width * footprint)
                Rectangle().fill(Self.otherColor).frame(width: width * min(other, max(0, 1 - footprint)))
                Rectangle().fill(Self.availableColor)
            }
        }
        .frame(height: 14)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private func tile(_ title: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(title).font(LuluTheme.TypeStyle.caption).foregroundStyle(.secondary)
        Text(value).font(.body.monospacedDigit().weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
}
