import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSWindowDelegate {
    private let statusItem: NSStatusItem
    private let settings: SettingsStore
    private let refreshCoordinator: RefreshCoordinator
    private let updater: UpdaterProviding
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?

    init(
        settings: SettingsStore,
        refreshCoordinator: RefreshCoordinator,
        updater: UpdaterProviding,
        statusBar: NSStatusBar = .system)
    {
        self.settings = settings
        self.refreshCoordinator = refreshCoordinator
        self.updater = updater
        self.statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configure()
        update(snapshot: refreshCoordinator.snapshot)
    }

    private func configure() {
        guard let button = statusItem.button else { return }
        button.action = #selector(handleClick)
        button.target = self
        popover.behavior = .transient
    }

    func update(snapshot: DashboardSnapshot) {
        guard let button = statusItem.button else { return }
        guard let metric = settings.selectedMetric else {
            button.image = IconRenderer.image(for: .sleepScore, color: .systemOrange, style: settings.iconStyle)
            button.contentTintColor = nil
            button.imagePosition = .imageOnly
            button.title = ""
            return
        }
        let series = snapshot.series(for: metric)
        let value = series.currentValue
        button.image = IconRenderer.image(for: metric, color: ColorThresholds.color(
            for: value,
            metric: metric,
            baseline: series.baselineValue,
            category: series.categoryValue),
            style: settings.iconStyle)
        button.contentTintColor = nil
        button.imagePosition = .imageLeft
        if series.availabilityMessage != nil {
            button.title = " N/A"
        } else if let value {
            button.title = " \(metric.formattedValue(value, temperatureUnit: settings.temperatureUnit))\(trendText(for: series))"
        } else if let categoryValue = series.categoryValue {
            button.title = " \(metric.formattedCategory(categoryValue))"
        } else {
            button.title = " ?"
        }
    }

    @objc private func handleClick() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        let layout = popoverLayout(for: settings.orderedEnabledMetrics.count, relativeTo: button)
        popover.contentSize = layout.contentSize
        popover.contentViewController = NSHostingController(rootView: PopoverView(
            snapshot: refreshCoordinator.snapshot,
            enabledMetrics: settings.enabledMetrics,
            metricOrder: settings.metricOrder,
            temperatureUnit: settings.temperatureUnit,
            averageWindow: settings.averageWindow,
            iconStyle: settings.iconStyle,
            gridViewportHeight: layout.gridViewportHeight,
            lastError: refreshCoordinator.lastError,
            tokenNeedsUpdate: refreshCoordinator.tokenNeedsUpdate,
            lastRefresh: refreshCoordinator.lastRefresh,
            refresh: { [weak self] in self?.refreshNow() },
            openSettings: { [weak self] in self?.openSettings() },
            quit: { [weak self] in self?.quit() }))
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func refreshNow() {
        refreshCoordinator.refresh()
    }

    private func popoverLayout(for visibleMetricCount: Int, relativeTo button: NSStatusBarButton) -> PopoverLayout {
        let columns = PopoverLayoutMetrics.columnCount(for: visibleMetricCount)
        let rows = PopoverLayoutMetrics.rowCount(for: visibleMetricCount, columns: columns)
        let desiredGridHeight = PopoverLayoutMetrics.gridHeight(for: rows)
        let screenFrame = button.window?.screen?.frame
        let buttonFrame = button.window.flatMap { window in
            Optional(window.convertToScreen(button.convert(button.bounds, to: nil)))
        }
        let availableBelowButton = buttonFrame.map { frame in
            frame.minY - (screenFrame?.minY ?? 0) - PopoverLayoutMetrics.screenBottomMargin
        } ?? ((screenFrame?.height ?? 760) - 32)
        let maxHeight = max(PopoverLayoutMetrics.minimumPopoverHeight, availableBelowButton)
        let maxGridHeight = max(PopoverLayoutMetrics.cardHeight, maxHeight - PopoverLayoutMetrics.footerReservedHeight)
        let gridHeight = min(desiredGridHeight, maxGridHeight)
        return PopoverLayout(
            contentSize: NSSize(
                width: PopoverLayoutMetrics.popoverWidth,
                height: gridHeight + PopoverLayoutMetrics.footerReservedHeight),
            gridViewportHeight: gridHeight)
    }

    @objc private func openSettings() {
        popover.performClose(nil)
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeSettingsWindow() -> NSWindow {
        let hostingController = NSHostingController(rootView: SettingsView(settings: settings, updater: updater))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "REM-Bar Settings"
        window.identifier = NSUserInterfaceItemIdentifier("com.psufka.REM-Bar.settings")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(NSSize(width: 1120, height: 700))
        window.center()
        return window
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === settingsWindow else { return }
        window.delegate = nil
        settingsWindow = nil
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func trendText(for series: MetricSeries) -> String {
        guard !series.metric.isCategorical,
              series.availabilityMessage == nil,
              let delta = series.delta
        else {
            return ""
        }
        let magnitude = abs(delta)
        guard magnitude >= minimumTrendMagnitude(for: series.metric) else { return "" }
        let arrow = delta > 0 ? "↑" : "↓"
        let formatted = series.metric.formattedDelta(magnitude, temperatureUnit: settings.temperatureUnit)
        guard !isZeroTrend(formatted) else { return "" }
        return " \(arrow)\(formatted)"
    }

    private func minimumTrendMagnitude(for metric: BarMetric) -> Double {
        switch metric {
        case .averageBreath, .averageSpO2, .bodyTemperatureDeviation, .vo2Max:
            return 0.05
        case .rem, .deepSleep, .totalSleep, .sleepDebt, .lightSleep, .awakeTime, .timeInBed, .sleepLatency:
            return 0.5
        case .sleepScore, .hrv, .rhr, .readiness, .activity, .hrvBalance, .sleepBalance, .sleepRegularity, .sleepEfficiency, .cardiovascularAge, .breathingDisturbance:
            return 0.5
        case .dailyStress, .resilience, .optimalBedtime, .sleepTimeRecommendation:
            return .infinity
        }
    }

    private func isZeroTrend(_ text: String) -> Bool {
        ["0", "0ms", "0bpm", "0y", "0%", "0:00", "0.0", "0.0C", "0.0F", "0.0%", "0.0rpm"].contains(text)
    }
}

private struct PopoverLayout {
    let contentSize: NSSize
    let gridViewportHeight: CGFloat
}
