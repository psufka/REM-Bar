import Foundation
import OuraKit
import XCTest
@testable import REMBar

final class SleepDebtTrendTests: XCTestCase {
    func testSleepDebtTrendUsesRunningBalanceAndShortSleepSessions() throws {
        let sleep = try decodeSleep("""
        {
          "data": [
            {
              "id": "rest-2026-05-01",
              "day": "2026-05-01",
              "type": "rest",
              "total_sleep_duration": 36000
            },
            {
              "id": "long-2026-05-01",
              "day": "2026-05-01",
              "type": "long_sleep",
              "total_sleep_duration": 25200
            },
            {
              "id": "short-2026-05-01",
              "day": "2026-05-01",
              "type": "sleep",
              "total_sleep_duration": 1800
            },
            {
              "id": "long-2026-05-02",
              "day": "2026-05-02",
              "type": "long_sleep",
              "total_sleep_duration": 30000
            },
            {
              "id": "missing-2026-05-03",
              "day": "2026-05-03",
              "type": "long_sleep"
            }
          ]
        }
        """)

        let points = SleepDebtTrendCalculator.points(from: sleep, sleepTargetMinutes: 480)

        XCTAssertEqual(points.map(\.id), ["2026-05-01", "2026-05-02"])
        XCTAssertEqual(points[0].minutes, 30, accuracy: 0.1)
        XCTAssertEqual(points[1].minutes, 7.0, accuracy: 0.1)
    }

    func testSleepDebtTrendFiltersRangeAndStats() throws {
        let sleep = try decodeSleep("""
        {
          "data": [
            {
              "id": "long-2026-05-01",
              "day": "2026-05-01",
              "type": "long_sleep",
              "total_sleep_duration": 24000
            },
            {
              "id": "long-2026-05-14",
              "day": "2026-05-14",
              "type": "long_sleep",
              "total_sleep_duration": 25200
            },
            {
              "id": "long-2026-05-15",
              "day": "2026-05-15",
              "type": "long_sleep",
              "total_sleep_duration": 30000
            }
          ]
        }
        """)
        let now = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 5, day: 15))!

        let points = SleepDebtTrendCalculator.points(from: sleep, sleepTargetMinutes: 480)
        let displayed = SleepDebtTrendCalculator.points(points, in: .seven, now: now)
        let stats = SleepDebtTrendCalculator.stats(for: displayed)

        XCTAssertEqual(displayed.map(\.id), ["2026-05-14", "2026-05-15"])
        XCTAssertEqual(displayed[0].minutes, 80, accuracy: 0.1)
        XCTAssertEqual(displayed[1].minutes, 33.9, accuracy: 0.1)
        XCTAssertEqual(stats.currentMinutes, 33.9, accuracy: 0.1)
        XCTAssertEqual(stats.averageMinutes, 57.0, accuracy: 0.1)
        XCTAssertEqual(stats.debtFreeDays, 0)
        XCTAssertEqual(stats.dataDays, 2)
    }

    func testSnapshotSleepDebtCardUsesRunningDebtAndDisplayWindow() throws {
        let sleep = try decodeSleep("""
        {
          "data": [
            {
              "id": "long-2026-05-01",
              "day": "2026-05-01",
              "type": "long_sleep",
              "total_sleep_duration": 25200
            },
            {
              "id": "long-2026-05-02",
              "day": "2026-05-02",
              "type": "long_sleep",
              "total_sleep_duration": 30000
            },
            {
              "id": "long-2026-05-03",
              "day": "2026-05-03",
              "type": "long_sleep",
              "total_sleep_duration": 28800
            }
          ]
        }
        """)

        let snapshot = DashboardSnapshotBuilder.make(
            dailySleep: [],
            sleep: sleep,
            readiness: [],
            activity: [],
            sleepTargetMinutes: 480,
            enabledMetrics: [.sleepDebt],
            displayWindowDays: 2)
        let series = snapshot.series(for: .sleepDebt)

        XCTAssertEqual(series.points.map(\.id), ["2026-05-02", "2026-05-03"])
        XCTAssertEqual(series.points[0].value, 33.9, accuracy: 0.1)
        XCTAssertEqual(series.points[1].value, 30.5, accuracy: 0.1)
        XCTAssertEqual(series.currentValue ?? -1, 30.5, accuracy: 0.1)
    }

    private func decodeSleep(_ json: String) throws -> [Sleep] {
        try JSONDecoder().decode(OuraCollection<Sleep>.self, from: Data(json.utf8)).data
    }
}
