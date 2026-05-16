import Foundation
import OuraKit
import XCTest
@testable import REMBar

final class SleepDebtTrendTests: XCTestCase {
    func testSleepDebtTrendPrefersLongSleepAndCalculatesDebt() throws {
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
        XCTAssertEqual(points.map(\.minutes), [60, 0])
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
        XCTAssertEqual(stats.totalMinutes, 60)
        XCTAssertEqual(stats.averageMinutes, 30)
        XCTAssertEqual(stats.goalMetDays, 1)
        XCTAssertEqual(stats.dataDays, 2)
    }

    private func decodeSleep(_ json: String) throws -> [Sleep] {
        try JSONDecoder().decode(OuraCollection<Sleep>.self, from: Data(json.utf8)).data
    }
}
