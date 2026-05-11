import Foundation
import XCTest
@testable import REMBar

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testDefaultsEnableFirstSixMetrics() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(store.enabledMetrics, SettingsStore.defaultEnabledMetrics)
        XCTAssertEqual(store.metricOrder, Array(BarMetric.allCases))
        XCTAssertEqual(store.orderedEnabledMetrics, [.sleepScore, .rem, .hrv, .rhr, .readiness, .activity])
        XCTAssertEqual(store.selectedMetric, .sleepScore)
    }

    func testRoundTripsCadenceSelectedMetricAndEnabledMetrics() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.refreshCadence = .fifteen
        store.temperatureUnit = .fahrenheit
        store.setMetric(.dailyStress, enabled: true)
        store.selectedMetric = .dailyStress
        store.setMetric(.activity, enabled: false)

        let reloaded = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(reloaded.refreshCadence, .fifteen)
        XCTAssertEqual(reloaded.temperatureUnit, .fahrenheit)
        XCTAssertEqual(reloaded.selectedMetric, .dailyStress)
        XCTAssertTrue(reloaded.enabledMetrics.contains(.dailyStress))
        XCTAssertFalse(reloaded.enabledMetrics.contains(.activity))
    }

    func testTemperatureFormattingConvertsDeviationUnits() {
        XCTAssertEqual(BarMetric.bodyTemperatureDeviation.formattedValue(0.5, temperatureUnit: .celsius), "+0.5C")
        XCTAssertEqual(BarMetric.bodyTemperatureDeviation.formattedValue(0.5, temperatureUnit: .fahrenheit), "+0.9F")
        XCTAssertEqual(BarMetric.bodyTemperatureDeviation.formattedDelta(-0.5, temperatureUnit: .fahrenheit), "-0.9F")
        XCTAssertEqual(BarMetric.sleepScore.formattedValue(87, temperatureUnit: .fahrenheit), "87")
    }

    func testSleepDurationsFormatAsHoursAndMinutes() {
        XCTAssertEqual(BarMetric.totalSleep.formattedValue(411), "6:51")
        XCTAssertEqual(BarMetric.deepSleep.formattedValue(92), "1:32")
        XCTAssertEqual(BarMetric.lightSleep.formattedValue(185), "3:05")
        XCTAssertEqual(BarMetric.rem.formattedValue(94), "1:34")
        XCTAssertEqual(BarMetric.sleepLatency.formattedValue(9), "0:09")
        XCTAssertEqual(BarMetric.totalSleep.formattedDelta(-32), "-0:32")
    }

    func testRoundTripsMetricOrder() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.moveMetric(.activity, to: .sleepScore)

        let reloaded = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(reloaded.metricOrder.first, .activity)
        XCTAssertEqual(reloaded.orderedEnabledMetrics.first, .activity)
    }

    func testMovingInactiveMetricToActiveEnablesAndOrdersIt() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.moveMetric(.dailyStress, before: .rem, enabled: true)

        XCTAssertTrue(store.enabledMetrics.contains(.dailyStress))
        XCTAssertEqual(Array(store.orderedEnabledMetrics.prefix(3)), [.sleepScore, .dailyStress, .rem])
        XCTAssertFalse(store.orderedInactiveMetrics.contains(.dailyStress))
    }

    func testMovingActiveMetricToInactiveDisablesAndOrdersIt() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.moveMetric(.activity, before: .deepSleep, enabled: false)

        XCTAssertFalse(store.enabledMetrics.contains(.activity))
        XCTAssertEqual(store.orderedEnabledMetrics, [.sleepScore, .rem, .hrv, .rhr, .readiness])
        XCTAssertEqual(Array(store.orderedInactiveMetrics.prefix(2)), [.activity, .deepSleep])
    }

    func testCannotMoveOnlyActiveMetricToInactive() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        for metric in SettingsStore.defaultEnabledMetrics where metric != .sleepScore {
            store.setMetric(metric, enabled: false)
        }
        store.moveMetric(.sleepScore, before: nil, enabled: false)

        XCTAssertEqual(store.enabledMetrics, [.sleepScore])
        XCTAssertEqual(store.orderedEnabledMetrics, [.sleepScore])
    }

    func testRepairsStoredMetricOrder() throws {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        let data = try JSONEncoder().encode(["dailyStress", "dailyStress", "not-a-metric", "sleepScore"])
        defaults.set(data, forKey: "metricOrder")

        let store = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(Array(store.metricOrder.prefix(2)), [.dailyStress, .sleepScore])
        XCTAssertEqual(Set(store.metricOrder), Set(BarMetric.allCases))
        XCTAssertEqual(store.metricOrder.count, BarMetric.allCases.count)
    }

    func testDisablingSelectedMetricSwapsToFirstEnabledMetric() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.selectedMetric = .activity
        store.setMetric(.activity, enabled: false)

        XCTAssertEqual(store.selectedMetric, .sleepScore)
        XCTAssertFalse(store.enabledMetrics.contains(.activity))
    }

    func testDisablingSelectedMetricUsesCustomOrderFallback() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.setMetric(.dailyStress, enabled: true)
        store.moveMetric(.dailyStress, to: .sleepScore)
        store.selectedMetric = .activity
        store.setMetric(.activity, enabled: false)

        XCTAssertEqual(store.selectedMetric, .dailyStress)
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
