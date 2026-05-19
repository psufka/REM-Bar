import Foundation
import OuraKit
import XCTest
@testable import REMBar

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testDefaultsEnableConfiguredMetrics() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(store.enabledMetrics, SettingsStore.defaultEnabledMetrics)
        XCTAssertEqual(Array(store.metricOrder.prefix(SettingsStore.defaultMetricOrder.count)), SettingsStore.defaultMetricOrder)
        XCTAssertEqual(store.orderedEnabledMetrics, SettingsStore.defaultMetricOrder)
        XCTAssertEqual(store.selectedMetric, .sleepScore)
        XCTAssertEqual(store.averageWindow, .seven)
        XCTAssertEqual(store.sleepAggregationMode, .includeNaps)
    }

    func testRoundTripsCadenceSelectedMetricAndEnabledMetrics() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.refreshCadence = .fifteen
        store.averageWindow = .fourteen
        store.temperatureUnit = .fahrenheit
        store.iconStyle = .monochrome
        store.sleepTarget = .eightThirty
        store.sleepAggregationMode = .mainSleepOnly
        store.setMetric(.dailyStress, enabled: true)
        store.selectedMetric = .dailyStress
        store.setMetric(.activity, enabled: false)

        let reloaded = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(reloaded.refreshCadence, .fifteen)
        XCTAssertEqual(reloaded.averageWindow, .fourteen)
        XCTAssertEqual(reloaded.temperatureUnit, .fahrenheit)
        XCTAssertEqual(reloaded.iconStyle, .monochrome)
        XCTAssertEqual(reloaded.sleepTarget, .eightThirty)
        XCTAssertEqual(reloaded.sleepAggregationMode, .mainSleepOnly)
        XCTAssertEqual(reloaded.selectedMetric, .dailyStress)
        XCTAssertTrue(reloaded.enabledMetrics.contains(.dailyStress))
        XCTAssertFalse(reloaded.enabledMetrics.contains(.activity))
    }

    func testRoundTripsIconOnlyMenuBarSelection() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.selectedMetric = nil

        let reloaded = SettingsStore(userDefaults: defaults)

        XCTAssertNil(reloaded.selectedMetric)
        XCTAssertEqual(defaults.string(forKey: "selectedMetric"), SettingsStore.iconOnlyMenuBarMetricRawValue)
    }

    func testFreshInstallNeedsOnboardingUntilCompleted() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)

        XCTAssertTrue(store.needsOnboarding)

        store.completeOnboarding()
        let reloaded = SettingsStore(userDefaults: defaults)

        XCTAssertFalse(reloaded.needsOnboarding)
    }

    func testExistingConfigurationSkipsOnboarding() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }
        defaults.set(SettingsStore.iconOnlyMenuBarMetricRawValue, forKey: "selectedMetric")

        let store = SettingsStore(userDefaults: defaults)

        XCTAssertFalse(store.needsOnboarding)
        XCTAssertNil(store.selectedMetric)
    }

    func testAverageWindowLabels() {
        XCTAssertEqual(SettingsStore.AverageWindow.three.averageLabel, "3-day avg")
        XCTAssertEqual(SettingsStore.AverageWindow.seven.averageLabel, "7-day avg")
        XCTAssertEqual(SettingsStore.AverageWindow.fourteen.averageLabel, "14-day avg")
        XCTAssertEqual(SettingsStore.AverageWindow.thirty.averageLabel, "30-day avg")
        XCTAssertEqual(SleepTarget.eight.label, "8:00")
        XCTAssertEqual(SleepTarget.eightFifteen.label, "8:15")
        XCTAssertEqual(SleepTarget.eightThirty.label, "8:30")
        XCTAssertEqual(SleepTarget.eightFortyFive.label, "8:45")
        XCTAssertEqual(SleepTarget.allCases.map(\.minutes), Array(stride(from: 360, through: 600, by: 15)))
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
        XCTAssertEqual(BarMetric.sleepDebt.formattedValue(73), "1:13")
        XCTAssertEqual(BarMetric.sleepLatency.formattedValue(9), "0:09")
        XCTAssertEqual(BarMetric.totalSleep.formattedDelta(-32), "-0:32")
    }

    func testSleepAggregationIncludesNapsByDefaultAndCanUseMainSleepOnly() throws {
        let sleep = try JSONDecoder().decode(OuraCollection<Sleep>.self, from: Data("""
        {
          "data": [
            {
              "id": "rest-2026-05-12",
              "day": "2026-05-12",
              "type": "rest",
              "total_sleep_duration": 36000,
              "rem_sleep_duration": 36000,
              "deep_sleep_duration": 36000,
              "light_sleep_duration": 36000,
              "time_in_bed": 36000,
              "efficiency": 100,
              "latency": 0
            },
            {
              "id": "sleep-detail-2026-05-12",
              "day": "2026-05-12",
              "type": "long_sleep",
              "total_sleep_duration": 21600,
              "rem_sleep_duration": 4200,
              "deep_sleep_duration": 3600,
              "light_sleep_duration": 13800,
              "time_in_bed": 25200,
              "efficiency": 86,
              "latency": 600
            },
            {
              "id": "nap-2026-05-12",
              "day": "2026-05-12",
              "type": "sleep",
              "total_sleep_duration": 1800,
              "rem_sleep_duration": 300,
              "deep_sleep_duration": 120,
              "light_sleep_duration": 1380,
              "time_in_bed": 2400,
              "efficiency": 75,
              "latency": 120
            }
          ]
        }
        """.utf8)).data

        let ouraLikeSnapshot = DashboardSnapshotBuilder.make(
            dailySleep: [],
            sleep: sleep,
            readiness: [],
            activity: [],
            enabledMetrics: [.totalSleep, .rem, .deepSleep, .lightSleep, .sleepEfficiency, .sleepLatency])
        let mainOnlySnapshot = DashboardSnapshotBuilder.make(
            dailySleep: [],
            sleep: sleep,
            readiness: [],
            activity: [],
            sleepAggregationMode: .mainSleepOnly,
            enabledMetrics: [.totalSleep, .rem, .deepSleep, .lightSleep, .sleepEfficiency, .sleepLatency])

        XCTAssertEqual(ouraLikeSnapshot.series(for: .totalSleep).currentValue, 390)
        XCTAssertEqual(ouraLikeSnapshot.series(for: .rem).currentValue, 75)
        XCTAssertEqual(ouraLikeSnapshot.series(for: .deepSleep).currentValue, 62)
        XCTAssertEqual(ouraLikeSnapshot.series(for: .lightSleep).currentValue, 253)
        XCTAssertEqual(ouraLikeSnapshot.series(for: .sleepEfficiency).currentValue ?? 0, 84.8, accuracy: 0.1)
        XCTAssertEqual(ouraLikeSnapshot.series(for: .sleepLatency).currentValue, 10)

        XCTAssertEqual(mainOnlySnapshot.series(for: .totalSleep).currentValue, 360)
        XCTAssertEqual(mainOnlySnapshot.series(for: .rem).currentValue, 70)
        XCTAssertEqual(mainOnlySnapshot.series(for: .deepSleep).currentValue, 60)
        XCTAssertEqual(mainOnlySnapshot.series(for: .lightSleep).currentValue, 230)
        XCTAssertEqual(mainOnlySnapshot.series(for: .sleepEfficiency).currentValue, 86)
        XCTAssertEqual(mainOnlySnapshot.series(for: .sleepLatency).currentValue, 10)
    }

    func testSnapshotCarriesLatestSleepSyncedSummary() throws {
        let sleep = try JSONDecoder().decode(OuraCollection<Sleep>.self, from: Data("""
        {
          "data": [
            {
              "id": "nap-2026-05-11",
              "day": "2026-05-11",
              "type": "rest",
              "bedtime_start": "2026-05-11T14:00:00-05:00",
              "bedtime_end": "2026-05-11T14:35:00-05:00",
              "total_sleep_duration": 1800
            },
            {
              "id": "sleep-detail-2026-05-12",
              "day": "2026-05-12",
              "type": "long_sleep",
              "bedtime_start": "2026-05-11T22:44:00-05:00",
              "bedtime_end": "2026-05-12T06:32:00-05:00",
              "total_sleep_duration": 24660
            }
          ]
        }
        """.utf8)).data

        let snapshot = DashboardSnapshotBuilder.make(
            dailySleep: [],
            sleep: sleep,
            readiness: [],
            activity: [],
            enabledMetrics: [.totalSleep])

        XCTAssertEqual(snapshot.latestSleep?.day, "2026-05-12")
        XCTAssertEqual(snapshot.latestSleep?.bedtimeStartRaw, "2026-05-11T22:44:00-05:00")
        XCTAssertEqual(snapshot.latestSleep?.bedtimeEndRaw, "2026-05-12T06:32:00-05:00")
        XCTAssertNotNil(snapshot.latestSleep?.bedtimeStart)
        XCTAssertNotNil(snapshot.latestSleep?.bedtimeEnd)
    }

    func testSnapshotLatestSleepSyncedSummaryUsesLatestMainSleepEnd() throws {
        let sleep = try JSONDecoder().decode(OuraCollection<Sleep>.self, from: Data("""
        {
          "data": [
            {
              "id": "nap-2026-05-18",
              "day": "2026-05-18",
              "type": "rest",
              "bedtime_start": "2026-05-18T14:00:00-05:00",
              "bedtime_end": "2026-05-18T14:28:00-05:00",
              "total_sleep_duration": 1200
            },
            {
              "id": "sleep-detail-2026-05-17",
              "day": "2026-05-17",
              "type": "long_sleep",
              "bedtime_start": "2026-05-16T22:26:00-05:00",
              "bedtime_end": "2026-05-17T06:11:00-05:00",
              "total_sleep_duration": 24660
            }
          ]
        }
        """.utf8)).data

        let snapshot = DashboardSnapshotBuilder.make(
            dailySleep: [],
            sleep: sleep,
            readiness: [],
            activity: [],
            enabledMetrics: [.totalSleep])

        XCTAssertEqual(snapshot.latestSleep?.day, "2026-05-17")
        XCTAssertEqual(snapshot.latestSleep?.bedtimeStartRaw, "2026-05-16T22:26:00-05:00")
        XCTAssertEqual(snapshot.latestSleep?.bedtimeEndRaw, "2026-05-17T06:11:00-05:00")
    }

    func testSnapshotParsesOuraSleepTimestampsWithFractionalSeconds() throws {
        let sleep = try JSONDecoder().decode(OuraCollection<Sleep>.self, from: Data("""
        {
          "data": [
            {
              "id": "sleep-detail-2026-05-14",
              "day": "2026-05-14",
              "type": "long_sleep",
              "bedtime_start": "2026-05-13T22:44:00.000-05:00",
              "bedtime_end": "2026-05-14T06:32:00.000-05:00",
              "total_sleep_duration": 24660
            }
          ]
        }
        """.utf8)).data

        let snapshot = DashboardSnapshotBuilder.make(
            dailySleep: [],
            sleep: sleep,
            readiness: [],
            activity: [],
            enabledMetrics: [.totalSleep])

        XCTAssertNotNil(snapshot.latestSleep?.bedtimeStart)
        XCTAssertNotNil(snapshot.latestSleep?.bedtimeEnd)
    }

    func testRoundTripsMetricOrder() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.moveMetric(.readiness, to: .sleepScore)

        let reloaded = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(reloaded.metricOrder.first, .readiness)
        XCTAssertEqual(reloaded.orderedEnabledMetrics.first, .readiness)
    }

    func testMovingInactiveMetricToActiveEnablesAndOrdersIt() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.moveMetric(.dailyStress, before: .readiness, enabled: true)

        XCTAssertTrue(store.enabledMetrics.contains(.dailyStress))
        XCTAssertEqual(Array(store.orderedEnabledMetrics.prefix(3)), [.sleepScore, .dailyStress, .readiness])
        XCTAssertFalse(store.orderedInactiveMetrics.contains(.dailyStress))
    }

    func testMovingActiveMetricToInactiveDisablesAndOrdersIt() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.moveMetric(.readiness, before: .lightSleep, enabled: false)

        XCTAssertFalse(store.enabledMetrics.contains(.readiness))
        XCTAssertEqual(store.orderedEnabledMetrics, SettingsStore.defaultMetricOrder.filter { $0 != .readiness })
        XCTAssertEqual(Array(store.orderedInactiveMetrics.prefix(3)), [.activity, .readiness, .lightSleep])
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

    func testIconOnlySelectionSurvivesCardDisableChanges() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.selectedMetric = nil
        store.setMetric(.readiness, enabled: false)

        XCTAssertNil(store.selectedMetric)
    }

    func testUnavailableMetricsPersistAndFilterCardSections() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.setMetric(.vo2Max, enabled: true)
        store.selectedMetric = .vo2Max
        store.noteMetricAvailability(from: DashboardSnapshot(metrics: [
            .vo2Max: MetricSeries(metric: .vo2Max, points: [], availabilityMessage: "Not available on your ring"),
        ]))

        XCTAssertTrue(store.knownUnavailableMetrics.contains(.vo2Max))
        XCTAssertFalse(store.orderedAvailableEnabledMetrics.contains(.vo2Max))
        XCTAssertTrue(store.orderedUnavailableMetrics.contains(.vo2Max))
        XCTAssertNotEqual(store.selectedMetric, .vo2Max)

        let reloaded = SettingsStore(userDefaults: defaults)
        XCTAssertTrue(reloaded.knownUnavailableMetrics.contains(.vo2Max))

        store.noteMetricAvailability(from: DashboardSnapshot(metrics: [
            .vo2Max: MetricSeries(metric: .vo2Max, points: [MetricPoint(id: "today", date: Date(), value: 42)]),
        ]))

        XCTAssertFalse(store.knownUnavailableMetrics.contains(.vo2Max))
        XCTAssertTrue(store.orderedAvailableEnabledMetrics.contains(.vo2Max))
    }

    func testApplyPresetSetsEnabledMetricsAndOrder() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.selectedMetric = .sleepDebt
        store.applyPreset(.cardio)

        XCTAssertEqual(store.enabledMetrics, Set(MetricPreset.cardio.metrics))
        XCTAssertEqual(Array(store.metricOrder.prefix(MetricPreset.cardio.metrics.count)), MetricPreset.cardio.metrics)
        XCTAssertEqual(store.selectedMetric, MetricPreset.cardio.metrics.first)
    }

    func testCustomPresetRoundTripsAndApplies() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.applyPreset(.minimal)
        store.saveCurrentAsCustomPreset()

        let reloaded = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(reloaded.customPresetMetrics, MetricPreset.minimal.metrics)
        XCTAssertTrue(reloaded.hasCustomPreset)

        reloaded.applyPreset(.cardio)
        reloaded.applyCustomPreset()

        XCTAssertEqual(reloaded.enabledMetrics, Set(MetricPreset.minimal.metrics))
        XCTAssertEqual(Array(reloaded.metricOrder.prefix(MetricPreset.minimal.metrics.count)), MetricPreset.minimal.metrics)
    }

    func testThresholdOverridesRoundTripAndSanitize() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName(defaults)) }

        let store = SettingsStore(userDefaults: defaults)
        store.setThreshold(
            MetricThresholdOverride(direction: .higherIsBetter, green: 60, orange: 90),
            for: .sleepScore)
        store.setThreshold(
            MetricThresholdOverride(direction: .lowerIsBetter, green: 80, orange: 30),
            for: .rhr)
        store.setThreshold(
            MetricThresholdOverride(direction: .higherIsBetter, green: 1, orange: 0),
            for: .dailyStress)

        let reloaded = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(reloaded.thresholdOverrides[.sleepScore], MetricThresholdOverride(direction: .higherIsBetter, green: 90, orange: 60))
        XCTAssertEqual(reloaded.thresholdOverrides[.rhr], MetricThresholdOverride(direction: .lowerIsBetter, green: 30, orange: 80))
        XCTAssertNil(reloaded.thresholdOverrides[.dailyStress])

        reloaded.resetThreshold(for: .sleepScore)

        XCTAssertNil(reloaded.thresholdOverrides[.sleepScore])
        XCTAssertEqual(reloaded.threshold(for: .sleepScore), BarMetric.sleepScore.defaultThresholdOverride)
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
