import AppKit
import CoreVideo
import QuartzCore

@MainActor
final class DisplayLinkDriver {
    private var displayLink: CADisplayLink?
    private var cvDisplayLink: CVDisplayLink?
    private var retainedCVDisplayLinkContext: UnsafeMutableRawPointer?
    private var targetInterval: CFTimeInterval = 1.0
    private var lastTickTimestamp: CFTimeInterval = 0
    private let onTick: () -> Void

    init(onTick: @escaping () -> Void) {
        self.onTick = onTick
    }

    func start(fps: Double = 1) {
        guard displayLink == nil, cvDisplayLink == nil else { return }
        let clampedFps = max(fps, 1)
        targetInterval = 1.0 / clampedFps
        lastTickTimestamp = 0

        if #available(macOS 15, *), let screen = NSScreen.main {
            let link = screen.displayLink(target: self, selector: #selector(step))
            let rate = Float(clampedFps)
            link.preferredFrameRateRange = CAFrameRateRange(minimum: rate, maximum: rate, preferred: rate)
            link.add(to: .main, forMode: .common)
            displayLink = link
        } else {
            startCVDisplayLink()
        }
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        if let cvDisplayLink {
            CVDisplayLinkStop(cvDisplayLink)
        }
        cvDisplayLink = nil
        if let retainedCVDisplayLinkContext {
            self.retainedCVDisplayLinkContext = nil
            Unmanaged<DisplayLinkDriver>.fromOpaque(retainedCVDisplayLinkContext).release()
        }
    }

    @objc private func step(_: AnyObject) {
        handleTick()
    }

    private func handleTick() {
        let now = CACurrentMediaTime()
        if lastTickTimestamp > 0, now - lastTickTimestamp < targetInterval {
            return
        }
        lastTickTimestamp = now
        onTick()
    }

    private func startCVDisplayLink() {
        var link: CVDisplayLink?
        guard CVDisplayLinkCreateWithActiveCGDisplays(&link) == kCVReturnSuccess, let link else {
            return
        }
        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo in
            guard let userInfo else { return kCVReturnSuccess }
            let driver = Unmanaged<DisplayLinkDriver>.fromOpaque(userInfo).takeUnretainedValue()
            driver.scheduleTick()
            return kCVReturnSuccess
        }
        let context = Unmanaged.passRetained(self).toOpaque()
        guard CVDisplayLinkSetOutputCallback(link, callback, context) == kCVReturnSuccess else {
            Unmanaged<DisplayLinkDriver>.fromOpaque(context).release()
            return
        }
        guard CVDisplayLinkStart(link) == kCVReturnSuccess else {
            Unmanaged<DisplayLinkDriver>.fromOpaque(context).release()
            return
        }
        retainedCVDisplayLinkContext = context
        cvDisplayLink = link
    }

    private nonisolated func scheduleTick() {
        Task { @MainActor [weak self] in
            self?.handleTick()
        }
    }

    deinit {
        displayLink?.invalidate()
        if let cvDisplayLink {
            CVDisplayLinkStop(cvDisplayLink)
        }
        if let retainedCVDisplayLinkContext {
            Unmanaged<DisplayLinkDriver>.fromOpaque(retainedCVDisplayLinkContext).release()
        }
    }
}
