import Foundation
import Testing
@testable import REMBar

@MainActor
struct SettingsStoreTests {
    @Test func defaultsEnableFirstSixMetrics() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)

        #expect(store.enabledMetrics == SettingsStore.defaultEnabledMetrics)
        #expect(store.metricOrder == Array(BarMetric.allCases))
        #expect(store.orderedEnabledMetrics == [.sleepScore, .rem, .hrv, .rhr, .readiness, .activity])
        #expect(store.selectedMetric == .sleepScore)
    }

    @Test func roundTripsCadenceSelectedMetricAndEnabledMetrics() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.refreshCadence = .fifteen
        store.setMetric(.dailyStress, enabled: true)
        store.selectedMetric = .dailyStress
        store.setMetric(.activity, enabled: false)

        let reloaded = SettingsStore(userDefaults: defaults)

        #expect(reloaded.refreshCadence == .fifteen)
        #expect(reloaded.selectedMetric == .dailyStress)
        #expect(reloaded.enabledMetrics.contains(.dailyStress))
        #expect(!reloaded.enabledMetrics.contains(.activity))
    }

    @Test func roundTripsMetricOrder() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.moveMetric(.activity, to: .sleepScore)

        let reloaded = SettingsStore(userDefaults: defaults)

        #expect(reloaded.metricOrder.first == .activity)
        #expect(reloaded.orderedEnabledMetrics.first == .activity)
    }

    @Test func repairsStoredMetricOrder() throws {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        let data = try JSONEncoder().encode(["dailyStress", "dailyStress", "not-a-metric", "sleepScore"])
        defaults.set(data, forKey: "metricOrder")

        let store = SettingsStore(userDefaults: defaults)

        #expect(Array(store.metricOrder.prefix(2)) == [.dailyStress, .sleepScore])
        #expect(Set(store.metricOrder) == Set(BarMetric.allCases))
        #expect(store.metricOrder.count == BarMetric.allCases.count)
    }

    @Test func disablingSelectedMetricSwapsToFirstEnabledMetric() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.selectedMetric = .activity
        store.setMetric(.activity, enabled: false)

        #expect(store.selectedMetric == .sleepScore)
        #expect(!store.enabledMetrics.contains(.activity))
    }

    @Test func disablingSelectedMetricUsesCustomOrderFallback() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.setMetric(.dailyStress, enabled: true)
        store.moveMetric(.dailyStress, to: .sleepScore)
        store.selectedMetric = .activity
        store.setMetric(.activity, enabled: false)

        #expect(store.selectedMetric == .dailyStress)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "REMBarTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(suiteName, forKey: "__suiteName")
        return defaults
    }

    private func defaultsSuiteName(_ defaults: UserDefaults) -> String {
        defaults.string(forKey: "__suiteName")!
    }
}
