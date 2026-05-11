import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let settings: SettingsStore
    private let refreshCoordinator: RefreshCoordinator
    private let popover = NSPopover()

    init(settings: SettingsStore, refreshCoordinator: RefreshCoordinator, statusBar: NSStatusBar = .system) {
        self.settings = settings
        self.refreshCoordinator = refreshCoordinator
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
        let metric = settings.selectedMetric
        let series = snapshot.series(for: metric)
        let value = series.currentValue
        button.image = IconRenderer.image(for: metric, color: ColorThresholds.color(for: value, metric: metric))
        button.contentTintColor = ColorThresholds.color(for: value, metric: metric)
        if let value {
            button.title = " \(metric.formattedValue(value))"
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
        popover.contentSize = NSSize(width: 430, height: 380)
        popover.contentViewController = NSHostingController(rootView: PopoverView(
            snapshot: refreshCoordinator.snapshot,
            lastError: refreshCoordinator.lastError,
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

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
