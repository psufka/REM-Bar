import Foundation
import Sparkle

@MainActor
protocol UpdaterProviding: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    var automaticallyDownloadsUpdates: Bool { get set }
    var isAvailable: Bool { get }
    var unavailableReason: String? { get }
    func checkForUpdates(_ sender: Any?)
}

@MainActor
final class DisabledUpdaterController: UpdaterProviding {
    var automaticallyChecksForUpdates = false
    var automaticallyDownloadsUpdates = false
    let isAvailable = false
    let unavailableReason: String?

    init(unavailableReason: String = "Updates unavailable in this build.") {
        self.unavailableReason = unavailableReason
    }

    func checkForUpdates(_: Any?) {}
}

@MainActor
final class SparkleUpdaterController: NSObject, UpdaterProviding {
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil)

    let isAvailable = true
    let unavailableReason: String? = nil

    init(savedAutoUpdate: Bool) {
        super.init()
        controller.updater.automaticallyChecksForUpdates = savedAutoUpdate
        controller.updater.automaticallyDownloadsUpdates = savedAutoUpdate
        controller.startUpdater()
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { controller.updater.automaticallyDownloadsUpdates }
        set { controller.updater.automaticallyDownloadsUpdates = newValue }
    }

    func checkForUpdates(_ sender: Any?) {
        controller.checkForUpdates(sender)
    }
}

@MainActor
func makeUpdaterController() -> UpdaterProviding {
    let bundle = Bundle.main
    guard bundle.bundleURL.pathExtension == "app" else {
        return DisabledUpdaterController()
    }
    guard bundle.url(forResource: "Sparkle", withExtension: "framework", subdirectory: "Frameworks") != nil ||
        FileManager.default.fileExists(atPath: bundle.bundleURL.appendingPathComponent("Contents/Frameworks/Sparkle.framework").path)
    else {
        return DisabledUpdaterController(unavailableReason: "Updates unavailable because Sparkle.framework is not bundled.")
    }
    guard let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String, !feedURL.isEmpty,
          let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String, !publicKey.isEmpty
    else {
        return DisabledUpdaterController(unavailableReason: "Updates unavailable because the Sparkle feed is not configured.")
    }

    let defaults = UserDefaults.standard
    let autoUpdateKey = "autoUpdateEnabled"
    let savedAutoUpdate = (defaults.object(forKey: autoUpdateKey) as? Bool) ?? true
    return SparkleUpdaterController(savedAutoUpdate: savedAutoUpdate)
}
