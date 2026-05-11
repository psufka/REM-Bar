import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let settings: SettingsStore
    private let refreshCoordinator: RefreshCoordinator
    private var scoreObservation: NSKeyValueObservation?

    init(settings: SettingsStore, refreshCoordinator: RefreshCoordinator, statusBar: NSStatusBar = .system) {
        self.settings = settings
        self.refreshCoordinator = refreshCoordinator
        self.statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configure()
        update(score: refreshCoordinator.sleepScore)
    }

    private func configure() {
        guard let button = statusItem.button else { return }
        button.action = #selector(handleClick)
        button.target = self
    }

    func update(score: Int?) {
        guard let button = statusItem.button else { return }
        let metric = settings.selectedMetric
        button.image = IconRenderer.image(for: metric, color: ColorThresholds.color(for: Double(score ?? 0)))
        button.contentTintColor = ColorThresholds.color(for: score.map(Double.init))
        if let score {
            button.title = " \(score)"
        } else {
            button.title = " ?"
        }
    }

    @objc private func handleClick() {
        let menu = NSMenu()
        let scoreTitle = "Sleep Score: \(refreshCoordinator.sleepScore.map(String.init) ?? "?")"
        menu.addItem(NSMenuItem(title: scoreTitle, action: nil, keyEquivalent: ""))
        if let error = refreshCoordinator.lastError {
            menu.addItem(NSMenuItem(title: error, action: nil, keyEquivalent: ""))
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit REM-Bar", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items {
            item.target = self
        }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
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
