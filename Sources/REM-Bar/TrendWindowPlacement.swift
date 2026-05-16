import AppKit

enum TrendWindowPlacement {
    @MainActor
    static func currentSourceWindow(excluding excludedWindow: NSWindow? = nil) -> NSWindow? {
        if let keyWindow = NSApp.keyWindow, keyWindow !== excludedWindow {
            return keyWindow
        }
        return NSApp.windows.first { window in
            window.isVisible && window !== excludedWindow
        }
    }

    @MainActor
    static func place(_ window: NSWindow, beside sourceWindow: NSWindow?) {
        guard let sourceWindow,
              sourceWindow !== window,
              let screen = sourceWindow.screen ?? window.screen ?? NSScreen.main
        else {
            window.center()
            return
        }

        let gap: CGFloat = 14
        let visibleFrame = screen.visibleFrame
        let sourceFrame = sourceWindow.frame
        let windowSize = window.frame.size
        let rightX = sourceFrame.maxX + gap
        let leftX = sourceFrame.minX - windowSize.width - gap

        let x: CGFloat
        if rightX + windowSize.width <= visibleFrame.maxX {
            x = rightX
        } else if leftX >= visibleFrame.minX {
            x = leftX
        } else {
            x = min(max(rightX, visibleFrame.minX), visibleFrame.maxX - windowSize.width)
        }

        let preferredY = sourceFrame.maxY - windowSize.height
        let y = min(max(preferredY, visibleFrame.minY), visibleFrame.maxY - windowSize.height)
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
