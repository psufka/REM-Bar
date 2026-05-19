import Foundation
import OuraKit
import XCTest
@testable import REMBar

final class OuraDataCacheTests: XCTestCase {
    func testCacheFetchesOnlyMissingDaysAndFallsBackOffline() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let cache = OuraDataCache(rootURL: rootURL)
        var requestedRanges: [(String, String)] = []

        let first = try await cache.values(
            endpoint: "daily_sleep",
            startDate: "2026-05-01",
            endDate: "2026-05-03")
        { startDate, endDate in
            requestedRanges.append((startDate, endDate))
            return try dailySleepRecords(from: startDate, through: endDate)
        }

        XCTAssertEqual(first.map(\.day), ["2026-05-01", "2026-05-02", "2026-05-03"])
        XCTAssertEqual(requestedRanges.map { "\($0.0)...\($0.1)" }, ["2026-05-01...2026-05-03"])

        let second = try await cache.values(
            endpoint: "daily_sleep",
            startDate: "2026-05-02",
            endDate: "2026-05-04")
        { startDate, endDate in
            requestedRanges.append((startDate, endDate))
            return try dailySleepRecords(from: startDate, through: endDate)
        }

        XCTAssertEqual(second.map(\.day), ["2026-05-02", "2026-05-03", "2026-05-04"])
        XCTAssertEqual(requestedRanges.map { "\($0.0)...\($0.1)" }, [
            "2026-05-01...2026-05-03",
            "2026-05-04...2026-05-04",
        ])

        let offline: [DailySleep] = try await cache.values(
            endpoint: "daily_sleep",
            startDate: "2026-05-01",
            endDate: "2026-05-05")
        { _, _ in
            throw URLError(.notConnectedToInternet)
        }

        XCTAssertEqual(offline.map(\.day), ["2026-05-01", "2026-05-02", "2026-05-03", "2026-05-04"])
    }

    private func dailySleepRecords(from startDate: String, through endDate: String) throws -> [DailySleep] {
        let days = dayStrings(from: startDate, through: endDate)
        let records = days.enumerated().map { index, day in
            #"{"id":"sleep-\#(day)","day":"\#(day)","score":\#(80 + index)}"#
        }
        let json = #"{"data":[\#(records.joined(separator: ","))]}"#
        return try JSONDecoder().decode(OuraCollection<DailySleep>.self, from: Data(json.utf8)).data
    }

    private func dayStrings(from startDate: String, through endDate: String) -> [String] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: startDate),
              let end = formatter.date(from: endDate)
        else {
            return []
        }

        var days: [String] = []
        var date = start
        while date <= end {
            days.append(formatter.string(from: date))
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            date = next
        }
        return days
    }
}
