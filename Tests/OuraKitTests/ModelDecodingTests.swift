import Foundation
import Testing
@testable import OuraKit

struct ModelDecodingTests {
    @Test func personalInfoFixtureDecodes() throws {
        let personalInfo = try decode(PersonalInfo.self, fixture: "personal_info")
        #expect(personalInfo.email == "paul@example.com")
        #expect(personalInfo.biologicalSex == "male")
    }

    @Test func dailySleepFixtureDecodes() throws {
        let response = try decode(OuraCollection<DailySleep>.self, fixture: "daily_sleep")
        #expect(response.data.first?.score == 87)
        #expect(response.data.first?.contributors?.remSleep == 94)
    }

    @Test func sleepFixtureDecodes() throws {
        let response = try decode(OuraCollection<Sleep>.self, fixture: "sleep")
        #expect(response.data.first?.remSleepDuration == 5640)
        #expect(response.data.first?.averageHrv == 63)
    }

    @Test func dailyReadinessFixtureDecodes() throws {
        let response = try decode(OuraCollection<DailyReadiness>.self, fixture: "daily_readiness")
        #expect(response.data.first?.score == 84)
        #expect(response.data.first?.contributors?.hrvBalance == 79)
    }

    @Test func dailyActivityFixtureDecodes() throws {
        let response = try decode(OuraCollection<DailyActivity>.self, fixture: "daily_activity")
        #expect(response.data.first?.steps == 10340)
        #expect(response.data.first?.activeCalories == 520)
    }

    private func decode<T: Decodable>(_ type: T.Type, fixture: String) throws -> T {
        let url = try #require(Bundle.module.url(forResource: fixture, withExtension: "json", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }
}
