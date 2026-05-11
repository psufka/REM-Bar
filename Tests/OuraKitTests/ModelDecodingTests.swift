import Foundation
import XCTest
@testable import OuraKit

final class ModelDecodingTests: XCTestCase {
    func testPersonalInfoFixtureDecodes() throws {
        let personalInfo = try decode(PersonalInfo.self, fixture: "personal_info")
        XCTAssertEqual(personalInfo.email, "paul@example.com")
        XCTAssertEqual(personalInfo.biologicalSex, "male")
    }

    func testDailySleepFixtureDecodes() throws {
        let response = try decode(OuraCollection<DailySleep>.self, fixture: "daily_sleep")
        XCTAssertEqual(response.data.first?.score, 87)
        XCTAssertEqual(response.data.first?.contributors?.remSleep, 94)
    }

    func testSleepFixtureDecodes() throws {
        let response = try decode(OuraCollection<Sleep>.self, fixture: "sleep")
        XCTAssertEqual(response.data.first?.remSleepDuration, 5640)
        XCTAssertEqual(response.data.first?.averageHrv, 63)
    }

    func testDailyReadinessFixtureDecodes() throws {
        let response = try decode(OuraCollection<DailyReadiness>.self, fixture: "daily_readiness")
        XCTAssertEqual(response.data.first?.score, 84)
        XCTAssertEqual(response.data.first?.contributors?.hrvBalance, 79)
        XCTAssertEqual(response.data.first?.contributors?.sleepRegularity, 81)
    }

    func testDailyActivityFixtureDecodes() throws {
        let response = try decode(OuraCollection<DailyActivity>.self, fixture: "daily_activity")
        XCTAssertEqual(response.data.first?.steps, 10340)
        XCTAssertEqual(response.data.first?.activeCalories, 520)
    }

    func testDailyStressFixtureDecodes() throws {
        let response = try decode(OuraCollection<DailyStress>.self, fixture: "daily_stress")
        XCTAssertEqual(response.data.first?.daySummary, .normal)
        XCTAssertEqual(response.data.first?.stressHigh, 3600)
    }

    func testDailyResilienceFixtureDecodes() throws {
        let response = try decode(OuraCollection<DailyResilience>.self, fixture: "daily_resilience")
        XCTAssertEqual(response.data.first?.level, .solid)
        XCTAssertEqual(response.data.first?.contributors?.sleepRecovery, 72.5)
    }

    func testDailyCardiovascularAgeFixtureDecodes() throws {
        let response = try decode(OuraCollection<DailyCardiovascularAge>.self, fixture: "daily_cardiovascular_age")
        XCTAssertEqual(response.data.first?.vascularAge, 39)
        XCTAssertEqual(response.data.first?.day, "2026-05-08")
    }

    func testDailySpO2FixtureDecodes() throws {
        let response = try decode(OuraCollection<DailySpO2>.self, fixture: "daily_spo2")
        XCTAssertEqual(response.data.first?.spo2Percentage?.average, 97.2)
        XCTAssertEqual(response.data.first?.breathingDisturbanceIndex, 2)
    }

    func testVO2MaxFixtureDecodes() throws {
        let response = try decode(OuraCollection<VO2Max>.self, fixture: "vo2_max")
        XCTAssertEqual(response.data.first?.vo2Max, 42.6)
        XCTAssertEqual(response.data.first?.day, "2026-05-08")
    }

    func testSleepTimeFixtureDecodes() throws {
        let response = try decode(OuraCollection<SleepTime>.self, fixture: "sleep_time")
        XCTAssertEqual(response.data.first?.optimalBedtime?.startOffset, 81000)
        XCTAssertEqual(response.data.first?.recommendation, "follow_optimal_bedtime")
    }

    func testTimeSeriesFixturesDecode() throws {
        let heartRate = try decode(OuraCollection<HeartRateSample>.self, fixture: "heart_rate")
        XCTAssertEqual(heartRate.data.first?.bpm, 58)

        let battery = try decode(OuraCollection<RingBatteryLevel>.self, fixture: "ring_battery_level")
        XCTAssertEqual(battery.data.first?.level, 84)
    }

    func testActivityRecordFixturesDecode() throws {
        let workout = try decode(OuraCollection<Workout>.self, fixture: "workout")
        XCTAssertEqual(workout.data.first?.activity, "running")

        let session = try decode(OuraCollection<Session>.self, fixture: "session")
        XCTAssertEqual(session.data.first?.type, "breathing")

        let restMode = try decode(OuraCollection<RestModePeriod>.self, fixture: "rest_mode_period")
        XCTAssertEqual(restMode.data.first?.startDay, "2026-05-08")

        let tag = try decode(OuraCollection<OuraTag>.self, fixture: "tag")
        XCTAssertEqual(tag.data.first?.tags, ["caffeine"])

        let enhancedTag = try decode(OuraCollection<EnhancedTag>.self, fixture: "enhanced_tag")
        XCTAssertEqual(enhancedTag.data.first?.customName, "Caffeine")
    }

    func testNullableOuraFieldsDecode() throws {
        let dailySleep = try JSONDecoder().decode(OuraCollection<DailySleep>.self, from: Data("""
        {
          "data": [
            {
              "id": "sleep-summary-2026-05-09",
              "contributors": {
                "deep_sleep": null,
                "efficiency": null,
                "latency": null,
                "rem_sleep": null,
                "restfulness": null,
                "timing": null,
                "total_sleep": null
              },
              "day": "2026-05-09",
              "score": null,
              "timestamp": null
            }
          ],
          "next_token": null
        }
        """.utf8))
        XCTAssertNil(dailySleep.data.first?.score)
        XCTAssertNil(dailySleep.data.first?.contributors?.remSleep)

        let sleep = try JSONDecoder().decode(OuraCollection<Sleep>.self, from: Data("""
        {
          "data": [
            {
              "id": "sleep-detail-2026-05-09",
              "day": "2026-05-09",
              "type": "long_sleep",
              "average_heart_rate": null,
              "average_hrv": null,
              "lowest_heart_rate": null
            }
          ]
        }
        """.utf8))
        XCTAssertNil(sleep.data.first?.averageHrv)

        let readiness = try JSONDecoder().decode(OuraCollection<DailyReadiness>.self, from: Data("""
        {
          "data": [
            {
              "id": "readiness-2026-05-09",
              "contributors": {
                "activity_balance": null,
                "body_temperature": null,
                "hrv_balance": null,
                "previous_day_activity": null,
                "previous_night": null,
                "recovery_index": null,
                "resting_heart_rate": null,
                "sleep_balance": null,
                "sleep_regularity": null
              },
              "day": "2026-05-09",
              "score": null,
              "temperature_deviation": null,
              "temperature_trend_deviation": null,
              "timestamp": null
            }
          ]
        }
        """.utf8))
        XCTAssertNil(readiness.data.first?.contributors?.hrvBalance)

        let activity = try JSONDecoder().decode(OuraCollection<DailyActivity>.self, from: Data("""
        {
          "data": [
            {
              "id": "activity-2026-05-09",
              "day": "2026-05-09",
              "score": null,
              "active_calories": null,
              "steps": null,
              "timestamp": null
            }
          ]
        }
        """.utf8))
        XCTAssertNil(activity.data.first?.activeCalories)
    }

    private func decode<T: Decodable>(_ type: T.Type, fixture: String) throws -> T {
        let url = try XCTUnwrap(Bundle.module.url(forResource: fixture, withExtension: "json", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }
}
