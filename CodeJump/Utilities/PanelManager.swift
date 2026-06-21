import SwiftUI
import AppKit

final class PanelManager: ObservableObject {
    static let shared = PanelManager()
    @Published var isVisible = false
    private var panel: NSPanel?
    private var statusItem: NSStatusItem?
    private var monitor: Any?

    func setStatusItem(_ item: NSStatusItem) { statusItem = item }

    func toggle<Content: View>(@ViewBuilder content: () -> Content) {
        if let panel, panel.isVisible {
            hide()
        } else {
            show(content: content)
        }
    }

    func show<Content: View>(@ViewBuilder content: () -> Content) {
        if let existing = panel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let savedHeight = CGFloat(UserDefaults.standard.double(forKey: "panelHeight"))
        let height = savedHeight > 200 ? savedHeight : 420
        let width: CGFloat = 360

        let hostingView = NSHostingView(rootView: content())

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.title = "CodeJump"
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.isFloatingPanel = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .transient]
        p.isMovableByWindowBackground = true
        p.contentView = hostingView
        p.contentMinSize = NSSize(width: width, height: 200)
        p.contentMaxSize = NSSize(width: width, height: 1200)
        p.isReleasedWhenClosed = false
        p.delegate = PanelDelegate.shared

        positionPanel(p)
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.panel = p
        isVisible = true
        startMonitoringClicks()
    }

    func hide() {
        stopMonitoringClicks()
        if let panel {
            UserDefaults.standard.set(Double(panel.frame.height), forKey: "panelHeight")
            panel.orderOut(nil)
        }
        isVisible = false
    }

    private func startMonitoringClicks() {
        stopMonitoringClicks()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible else { return }
            if NSApp.modalWindow != nil { return }
            let clickLocation = event.locationInWindow
            if let eventWindow = event.window {
                let screenPoint = eventWindow.convertPoint(toScreen: clickLocation)
                if !panel.frame.contains(screenPoint) {
                    DispatchQueue.main.async { self.hide() }
                }
            } else {
                let screenPoint = NSEvent.mouseLocation
                if !panel.frame.contains(screenPoint) {
                    DispatchQueue.main.async { self.hide() }
                }
            }
        }
    }

    private func stopMonitoringClicks() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let button = statusItem?.button, let buttonWindow = button.window else {
            panel.center()
            return
        }

        let buttonFrame = buttonWindow.frame
        let panelFrame = panel.frame

        var x = buttonFrame.origin.x + buttonFrame.size.width / 2 - panelFrame.size.width / 2
        let y = buttonFrame.origin.y - panelFrame.size.height

        let screen = buttonWindow.screen ?? NSScreen.main
        if let screenFrame = screen?.frame {
            if x + panelFrame.size.width > screenFrame.maxX { x = screenFrame.maxX - panelFrame.size.width - 10 }
            if x < screenFrame.minX { x = screenFrame.minX + 10 }
        }

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private class PanelDelegate: NSObject, NSWindowDelegate {
    static let shared = PanelDelegate()

    func windowDidResignKey(_ notification: Notification) {
        if NSApp.modalWindow != nil { return }
        PanelManager.shared.hide()
    }

    func windowWillClose(_ notification: Notification) {
        if let panel = notification.object as? NSPanel {
            UserDefaults.standard.set(Double(panel.frame.height), forKey: "panelHeight")
        }
        PanelManager.shared.hide()
    }
}
