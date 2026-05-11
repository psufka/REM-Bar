import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore.shared
    private lazy var refreshCoordinator = RefreshCoordinator(settings: settings)
    private var statusController: StatusItemController?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let controller = StatusItemController(settings: settings, refreshCoordinator: refreshCoordinator)
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
        settings.$refreshCadence
            .receive(on: RunLoop.main)
            .sink { [weak refreshCoordinator] _ in
                Task { @MainActor in
                    refreshCoordinator?.scheduleTimer()
                }
            }
            .store(in: &cancellables)
        refreshCoordinator.start()
    }

    func applicationWillTerminate(_: Notification) {
        refreshCoordinator.stop()
    }
}
