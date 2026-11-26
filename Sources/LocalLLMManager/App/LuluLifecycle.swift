import AppKit
import SwiftUI

@MainActor
final class LuluLifecycle: NSObject, NSApplicationDelegate {
    private let workspaceWindows = NSHashTable<NSWindow>.weakObjects()
    var openWorkspace: ((String) -> Void)?

    func applicationWillFinishLaunching(_ notification: Notification) {
        LuluAppearance.stored.apply()
        NotificationCenter.default.addObserver(self, selector: #selector(workspaceWillClose(_:)),
                                               name: NSWindow.willCloseNotification, object: nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !workspaceWindows.allObjects.contains(where: { $0.isVisible || $0.isMiniaturized }) {
            openWorkspace?("main")
        }
        return true
    }

    func registerWorkspaceWindow(_ window: NSWindow) {
        workspaceWindows.add(window)
    }

    @objc private func workspaceWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, workspaceWindows.contains(window) else { return }
        // Check after AppKit has ordered the closing window out.
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  !workspaceWindows.allObjects.contains(where: { $0.isVisible || $0.isMiniaturized }) else { return }
            NSApp.setActivationPolicy(.accessory)
        }
    }

    static func showWorkspace(_ id: String, using openWindow: OpenWindowAction) {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        openWindow(id: id)
        NSApp.activate()
    }
}

struct LuluWorkspaceWindow: NSViewRepresentable {
    let lifecycle: LuluLifecycle
    @Environment(\.openWindow) private var openWindow

    func makeNSView(context: Context) -> Anchor {
        registerOpenAction()
        return Anchor(lifecycle: lifecycle)
    }

    func updateNSView(_ view: Anchor, context: Context) {
        registerOpenAction()
    }

    private func registerOpenAction() {
        let open = openWindow
        lifecycle.openWorkspace = { id in
            LuluLifecycle.showWorkspace(id, using: open)
        }
    }

    final class Anchor: NSView {
        private weak var lifecycle: LuluLifecycle?

        init(lifecycle: LuluLifecycle) {
            self.lifecycle = lifecycle
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { lifecycle?.registerWorkspaceWindow(window) }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
