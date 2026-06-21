import SwiftUI
import AppKit

final class WindowManager {
    static let shared = WindowManager()
    private var windows: [String: NSWindow] = [:]

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
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        windows[id] = w
    }

    func close(id: String) {
        windows[id]?.close()
        windows[id] = nil
    }
}
