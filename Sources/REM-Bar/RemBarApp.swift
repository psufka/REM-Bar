import SwiftUI

@main
struct RemBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        Settings {
            SettingsView(settings: settings, updater: appDelegate.updaterController)
        }
    }
}
