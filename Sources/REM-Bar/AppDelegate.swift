import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore.shared
    private lazy var refreshCoordinator = RefreshCoordinator(settings: settings)
    let updaterController: UpdaterProviding = makeUpdaterController()
    private var statusController: StatusItemController?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let iconURL = Bundle.module.url(forResource: "Icon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL)
        {
            NSApp.applicationIconImage = icon
        }
        let controller = StatusItemController(
            settings: settings,
            refreshCoordinator: refreshCoordinator,
            updater: updaterController)
        statusController = controller
        refreshCoordinator.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak controller] snapshot in
                Task { @MainActor in
                    controller?.update(snapshot: snapshot)
                }
            }
            .store(in: &cancellables)
        settings.$selectedMetric
            .receive(on: RunLoop.main)
            .sink { [weak controller, weak refreshCoordinator] _ in
                Task { @MainActor in
                    controller?.update(snapshot: refreshCoordinator?.snapshot ?? .empty)
                }
            }
            .store(in: &cancellables)
        settings.$temperatureUnit
            .receive(on: RunLoop.main)
            .sink { [weak controller, weak refreshCoordinator] _ in
                Task { @MainActor in
                    controller?.update(snapshot: refreshCoordinator?.snapshot ?? .empty)
                }
            }
            .store(in: &cancellables)
        settings.$iconStyle
            .receive(on: RunLoop.main)
            .sink { [weak controller, weak refreshCoordinator] _ in
                Task { @MainActor in
                    controller?.update(snapshot: refreshCoordinator?.snapshot ?? .empty)
                }
            }
            .store(in: &cancellables)
        settings.$refreshCadence
            .receive(on: RunLoop.main)
            .sink { [weak refreshCoordinator] _ in
                Task { @MainActor in
                    refreshCoordinator?.scheduleTimer()
                }
            }
            .store(in: &cancellables)
        settings.$averageWindow
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak refreshCoordinator] _ in
                Task { @MainActor in
                    refreshCoordinator?.refresh()
                }
            }
            .store(in: &cancellables)
        settings.$sleepTarget
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak refreshCoordinator] _ in
                Task { @MainActor in
                    refreshCoordinator?.refresh()
                }
            }
            .store(in: &cancellables)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(tokenDidChange),
            name: .remBarTokenDidChange,
            object: nil)
        refreshCoordinator.start()
    }

    func applicationWillTerminate(_: Notification) {
        NotificationCenter.default.removeObserver(self)
        refreshCoordinator.stop()
    }

    @objc private func tokenDidChange() {
        refreshCoordinator.tokenDidChange()
    }
}
