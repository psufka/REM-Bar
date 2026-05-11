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
        store.temperatureUnit = .fahrenheit
        store.setMetric(.dailyStress, enabled: true)
        store.selectedMetric = .dailyStress
        store.setMetric(.activity, enabled: false)

        let reloaded = SettingsStore(userDefaults: defaults)

        #expect(reloaded.refreshCadence == .fifteen)
        #expect(reloaded.temperatureUnit == .fahrenheit)
        #expect(reloaded.selectedMetric == .dailyStress)
        #expect(reloaded.enabledMetrics.contains(.dailyStress))
        #expect(!reloaded.enabledMetrics.contains(.activity))
    }

    @Test func temperatureFormattingConvertsDeviationUnits() {
        #expect(BarMetric.bodyTemperatureDeviation.formattedValue(0.5, temperatureUnit: .celsius) == "+0.5C")
        #expect(BarMetric.bodyTemperatureDeviation.formattedValue(0.5, temperatureUnit: .fahrenheit) == "+0.9F")
        #expect(BarMetric.bodyTemperatureDeviation.formattedDelta(-0.5, temperatureUnit: .fahrenheit) == "-0.9F")
        #expect(BarMetric.sleepScore.formattedValue(87, temperatureUnit: .fahrenheit) == "87")
    }

    @Test func sleepDurationsFormatAsHoursAndMinutes() {
        #expect(BarMetric.totalSleep.formattedValue(411) == "6:51")
        #expect(BarMetric.deepSleep.formattedValue(92) == "1:32")
        #expect(BarMetric.lightSleep.formattedValue(185) == "3:05")
        #expect(BarMetric.rem.formattedValue(94) == "1:34")
        #expect(BarMetric.sleepLatency.formattedValue(9) == "0:09")
        #expect(BarMetric.totalSleep.formattedDelta(-32) == "-0:32")
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

    @Test func movingInactiveMetricToActiveEnablesAndOrdersIt() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.moveMetric(.dailyStress, before: .rem, enabled: true)

        #expect(store.enabledMetrics.contains(.dailyStress))
        #expect(Array(store.orderedEnabledMetrics.prefix(3)) == [.sleepScore, .dailyStress, .rem])
        #expect(!store.orderedInactiveMetrics.contains(.dailyStress))
    }

    @Test func movingActiveMetricToInactiveDisablesAndOrdersIt() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.moveMetric(.activity, before: .deepSleep, enabled: false)

        #expect(!store.enabledMetrics.contains(.activity))
        #expect(store.orderedEnabledMetrics == [.sleepScore, .rem, .hrv, .rhr, .readiness])
        #expect(Array(store.orderedInactiveMetrics.prefix(2)) == [.activity, .deepSleep])
    }

    @Test func cannotMoveOnlyActiveMetricToInactive() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        for metric in SettingsStore.defaultEnabledMetrics where metric != .sleepScore {
            store.setMetric(metric, enabled: false)
        }
        store.moveMetric(.sleepScore, before: nil, enabled: false)

        #expect(store.enabledMetrics == [.sleepScore])
        #expect(store.orderedEnabledMetrics == [.sleepScore])
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
