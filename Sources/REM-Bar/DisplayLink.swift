import AppKit
import CoreVideo
import QuartzCore

@MainActor
final class DisplayLinkDriver {
    private var displayLink: CADisplayLink?
    private var cvDisplayLink: CVDisplayLink?
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
        CVDisplayLinkSetOutputCallback(link, callback, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(link)
        cvDisplayLink = link
    }

    private nonisolated func scheduleTick() {
        Task { @MainActor [weak self] in
            self?.handleTick()
        }
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }
}
