import SwiftUI
import AppKit

final class WindowManager: NSObject, NSWindowDelegate {
    static let shared = WindowManager()
    private var windows: [String: NSWindow] = [:]
    private var windowIdMap: [ObjectIdentifier: String] = [:]

    func open<Content: View>(id: String, title: String, width: CGFloat, height: CGFloat, @ViewBuilder content: () -> Content) {
        if let existing = windows[id], existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: content())
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = title
        w.contentView = hostingView
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        windows[id] = w
        windowIdMap[ObjectIdentifier(w)] = id
    }

    func close(id: String) {
        if let w = windows[id] {
            windowIdMap.removeValue(forKey: ObjectIdentifier(w))
            w.close()
        }
        windows[id] = nil
    }

    func windowWillClose(_ notification: Notification) {
        guard let w = notification.object as? NSWindow else { return }
        let oid = ObjectIdentifier(w)
        if let id = windowIdMap.removeValue(forKey: oid) {
            windows.removeValue(forKey: id)
        }
    }
}
