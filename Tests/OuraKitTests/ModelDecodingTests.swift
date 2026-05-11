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
        #expect(response.data.first?.contributors?.sleepRegularity == 81)
    }

    @Test func dailyActivityFixtureDecodes() throws {
        let response = try decode(OuraCollection<DailyActivity>.self, fixture: "daily_activity")
        #expect(response.data.first?.steps == 10340)
        #expect(response.data.first?.activeCalories == 520)
    }

    @Test func dailyStressFixtureDecodes() throws {
        let response = try decode(OuraCollection<DailyStress>.self, fixture: "daily_stress")
        #expect(response.data.first?.daySummary == .normal)
        #expect(response.data.first?.stressHigh == 3600)
    }

    @Test func dailyResilienceFixtureDecodes() throws {
        let response = try decode(OuraCollection<DailyResilience>.self, fixture: "daily_resilience")
        #expect(response.data.first?.level == .solid)
        #expect(response.data.first?.contributors?.sleepRecovery == 72.5)
    }

    @Test func dailyCardiovascularAgeFixtureDecodes() throws {
        let response = try decode(OuraCollection<DailyCardiovascularAge>.self, fixture: "daily_cardiovascular_age")
        #expect(response.data.first?.vascularAge == 39)
        #expect(response.data.first?.day == "2026-05-08")
    }

    @Test func dailySpO2FixtureDecodes() throws {
        let response = try decode(OuraCollection<DailySpO2>.self, fixture: "daily_spo2")
        #expect(response.data.first?.spo2Percentage?.average == 97.2)
        #expect(response.data.first?.breathingDisturbanceIndex == 2)
    }

    @Test func vo2MaxFixtureDecodes() throws {
        let response = try decode(OuraCollection<VO2Max>.self, fixture: "vo2_max")
        #expect(response.data.first?.vo2Max == 42.6)
        #expect(response.data.first?.day == "2026-05-08")
    }

    @Test func sleepTimeFixtureDecodes() throws {
        let response = try decode(OuraCollection<SleepTime>.self, fixture: "sleep_time")
        #expect(response.data.first?.optimalBedtime?.startOffset == 81000)
        #expect(response.data.first?.recommendation == "follow_optimal_bedtime")
    }

    @Test func timeSeriesFixturesDecode() throws {
        let heartRate = try decode(OuraCollection<HeartRateSample>.self, fixture: "heart_rate")
        #expect(heartRate.data.first?.bpm == 58)

        let battery = try decode(OuraCollection<RingBatteryLevel>.self, fixture: "ring_battery_level")
        #expect(battery.data.first?.level == 84)
    }

    @Test func activityRecordFixturesDecode() throws {
        let workout = try decode(OuraCollection<Workout>.self, fixture: "workout")
        #expect(workout.data.first?.activity == "running")

        let session = try decode(OuraCollection<Session>.self, fixture: "session")
        #expect(session.data.first?.type == "breathing")

        let restMode = try decode(OuraCollection<RestModePeriod>.self, fixture: "rest_mode_period")
        #expect(restMode.data.first?.startDay == "2026-05-08")

        let tag = try decode(OuraCollection<OuraTag>.self, fixture: "tag")
        #expect(tag.data.first?.tags == ["caffeine"])

        let enhancedTag = try decode(OuraCollection<EnhancedTag>.self, fixture: "enhanced_tag")
        #expect(enhancedTag.data.first?.customName == "Caffeine")
    }

    @Test func nullableOuraFieldsDecode() throws {
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
        #expect(dailySleep.data.first?.score == nil)
        #expect(dailySleep.data.first?.contributors?.remSleep == nil)

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
        #expect(sleep.data.first?.averageHrv == nil)

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
        #expect(readiness.data.first?.contributors?.hrvBalance == nil)

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
        #expect(activity.data.first?.activeCalories == nil)
    }

    private func decode<T: Decodable>(_ type: T.Type, fixture: String) throws -> T {
        let url = try #require(Bundle.module.url(forResource: fixture, withExtension: "json", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }
}
