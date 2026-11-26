import AppKit
import SwiftUI

@MainActor
final class LuluStatusItem: NSObject, NSPopoverDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var outsideClickMonitor: Any?

    init(model: AppModel, openWorkspace: @escaping (String) -> Void) {
        super.init()

        popover.behavior = .transient
        popover.delegate = self
        let controller = NSHostingController(rootView: LuluTray(model: model) { [weak self] id in
            self?.popover.close()
            openWorkspace(id)
        })
        controller.sizingOptions = [.preferredContentSize]
        popover.contentViewController = controller

        item.button?.image = LuluTrayIcon.image
        item.button?.toolTip = "Lulu"
        item.button?.setAccessibilityLabel("Lulu")
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
    }

    @objc private func togglePopover() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.close()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            guard popover.isShown, outsideClickMonitor == nil else { return }
            // AppKit handles clicks in Lulu. Watch other apps while the panel is open.
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] _ in
                self?.popover.close()
            }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        guard !popover.isShown, let outsideClickMonitor else { return }
        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
    }
}
