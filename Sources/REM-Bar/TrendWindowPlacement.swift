import AppKit

enum TrendWindowPlacement {
    @MainActor
    static func configure(_ window: NSWindow, autosaveName: String) {
        window.level = .floating
        window.collectionBehavior.insert(.moveToActiveSpace)

        if let savedFrame = savedFrame(for: autosaveName), isFrameUsable(savedFrame) {
            window.setFrame(visibleFrame(for: savedFrame), display: false)
        } else {
            center(window)
        }

        observeFrameChanges(for: window, autosaveName: autosaveName)
    }

    @MainActor
    static func bringToFront(_ window: NSWindow) {
        window.setFrame(visibleFrame(for: window.frame), display: false)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    private static func center(_ window: NSWindow) {
        guard let screen = NSScreen.main else {
            window.center()
            return
        }
        let visibleFrame = screen.visibleFrame
        let size = window.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2)
        window.setFrameOrigin(origin)
    }

    private static func savedFrame(for autosaveName: String) -> NSRect? {
        guard let frameString = UserDefaults.standard.string(forKey: defaultsKey(for: autosaveName)) else {
            return nil
        }
        let frame = NSRectFromString(frameString)
        return frame.isEmpty ? nil : frame
    }

    private static func isFrameUsable(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(frame)
        }
    }

    private static func visibleFrame(for frame: NSRect) -> NSRect {
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(frame) } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return frame }
        let width = min(frame.width, visibleFrame.width)
        let height = min(frame.height, visibleFrame.height)
        let x = min(max(frame.minX, visibleFrame.minX), visibleFrame.maxX - width)
        let y = min(max(frame.minY, visibleFrame.minY), visibleFrame.maxY - height)
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private static func observeFrameChanges(for window: NSWindow, autosaveName: String) {
        let key = defaultsKey(for: autosaveName)
        for notificationName in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            NotificationCenter.default.addObserver(
                forName: notificationName,
                object: window,
                queue: .main)
            { notification in
                guard let window = notification.object as? NSWindow else { return }
                UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: key)
            }
        }
    }

    private static func defaultsKey(for autosaveName: String) -> String {
        "com.psufka.REM-Bar.trendWindowFrame.\(autosaveName)"
    }
}
