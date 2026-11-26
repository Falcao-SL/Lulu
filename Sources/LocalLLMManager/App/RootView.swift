import SwiftUI
import AppKit

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var model: AppModel
    @Binding var appearance: LuluAppearance

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: LuluTheme.Space.lg) {
                HStack(spacing: LuluTheme.Space.md) {
                    LuluEmblem(side: 40)
                    Text("Lulu")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .tracking(-1)
                }
                .padding(.horizontal, LuluTheme.Space.lg)
                .padding(.top, LuluTheme.Space.md)
                VStack(spacing: LuluTheme.Space.xs) {
                    navigationItem("Overview", "square.grid.2x2", .overview)
                    navigationItem("Models", "square.stack.3d.up", .models)
                    navigationItem("Server", "server.rack", .server)
                    navigationItem("Engines", "cpu", .engines)
                    navigationItem("Performance", "gauge.with.dots.needle.67percent", .speed)
                }.padding(.horizontal, LuluTheme.Space.sm)
                Spacer()
                appearanceControl
                    .padding([.horizontal, .bottom], LuluTheme.Space.md)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
                if let banner = model.banner {
                    HStack {
                        LuluGlyph("info.circle").foregroundStyle(LuluTheme.accent)
                            .accessibilityHidden(true)
                        Text(banner).font(LuluTheme.TypeStyle.body)
                        Spacer()
                        Button("Close") { model.banner = nil }.buttonStyle(.borderless)
                    }
                    .padding(LuluTheme.Space.md)
                    .luluCard()
                }
                switch model.pane {
                case .overview: OverviewPane(model: model)
                case .engines: ScrollView { EnginesPane(model: model) }
                case .models: ModelsPane(model: model)
                case .server: ScrollView { ServerPane(model: model) }
                case .speed: ScrollView { SpeedPane(model: model) }
                }
                Spacer(minLength: 0)
            }
            .padding(LuluTheme.Space.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(LuluTheme.canvas)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in model.setMonitoringActive(phase == .active) }
        .tint(LuluTheme.accent)
        .accentColor(LuluTheme.accent)
        .confirmationDialog("Remove this engine?", isPresented: removeShown, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { model.confirmEngineRemoval() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The engine will be removed. Models in ~/models will remain.")
        }
        .confirmationDialog("Delete this model?", isPresented: deleteShown, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { model.confirmModelDeletion() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The files will be removed from ~/models. A partial download can also be removed from the queue.")
        }
        .sheet(item: $model.configuredNotice) { notice in
            ConfiguredSheet(notice: notice)
        }
        .confirmationDialog("Purge memory?", isPresented: $model.confirmPurge, titleVisibility: .visible) {
            Button("Purge", role: .destructive) { model.purge() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Stops the server, releases model weights and KV cache, and asks macOS to purge inactive memory.")
        }
    }

    private var appearanceControl: some View {
        VStack(alignment: .leading, spacing: LuluTheme.Space.sm) {
            Divider()
            Text("Appearance")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Menu {
                Picker("Appearance", selection: $appearance) {
                    ForEach(LuluAppearance.allCases, id: \.self) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label(appearance.title, systemImage: appearance.symbol)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityLabel("Appearance")
            .accessibilityValue(Text(appearance.title))
        }
    }

    private func navigationItem(_ title: String, _ symbol: String, _ pane: Pane) -> some View {
        let selected = model.pane == pane
        return Button { model.pane = pane } label: {
            HStack(spacing: LuluTheme.Space.md) {
                LuluGlyph(symbol).foregroundStyle(selected ? LuluTheme.accent : Color.secondary)
                Text(title).font(LuluTheme.TypeStyle.body.weight(selected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .padding(LuluTheme.Space.md)
            .foregroundStyle(Color.primary)
            .background(selected ? LuluTheme.subtle : Color.clear,
                        in: RoundedRectangle(cornerRadius: LuluTheme.Radius.control))
            .overlay(alignment: .leading) {
                if selected {
                    Capsule().fill(LuluTheme.accent)
                        .frame(width: 3, height: 14)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var removeShown: Binding<Bool> {
        Binding(get: { model.confirmRemoveEngine != nil }, set: { if !$0 { model.confirmRemoveEngine = nil } })
    }

    private var deleteShown: Binding<Bool> {
        Binding(get: { model.confirmDeleteModel != nil }, set: { if !$0 { model.confirmDeleteModel = nil } })
    }
}
