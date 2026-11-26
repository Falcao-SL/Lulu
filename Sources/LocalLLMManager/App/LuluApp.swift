import SwiftUI
import AppKit

@main
struct LuluApp: App {
    @NSApplicationDelegateAdaptor(LuluLifecycle.self) private var lifecycle
    @StateObject private var model = AppModel()
    @AppStorage(LuluAppearance.preferenceKey) private var appearance = LuluAppearance.system
    @Environment(\.openWindow) private var openWindow

    private var appearanceSelection: Binding<LuluAppearance> {
        Binding(get: { appearance }, set: { selection in
            appearance = selection
            selection.apply()
        })
    }

    var body: some Scene {
        Window("Lulu", id: "main") {
            RootView(model: model, appearance: appearanceSelection)
                .frame(minWidth: 920, minHeight: 640)
                .background(LuluWorkspaceWindow(lifecycle: lifecycle))
                .preferredColorScheme(appearance.scheme)
                .onAppear { lifecycle.installTray(model: model) }
        }
        .defaultSize(width: 1120, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .sidebar) {
                Menu("Appearance") {
                    Picker("Appearance", selection: appearanceSelection) {
                        ForEach(LuluAppearance.allCases, id: \.self) { mode in
                            Label(mode.title, systemImage: mode.symbol).tag(mode)
                        }
                    }
                }
            }
            CommandGroup(after: .help) {
                Button("Open Chat") { model.openWebChat() }
                Button("Lulu design guide") { LuluLifecycle.showWorkspace("design-guide", using: openWindow) }
            }
        }

        Window("Lulu design guide", id: "design-guide") {
            LuluDesignGuide()
                .background(LuluWorkspaceWindow(lifecycle: lifecycle))
        }
        .defaultSize(width: 850, height: 740)
    }
}
