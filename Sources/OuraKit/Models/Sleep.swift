import Foundation

public struct Sleep: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let day: String
    public let type: String?
    public let bedtimeStart: String?
    public let bedtimeEnd: String?
    public let awakeTime: Int?
    public let deepSleepDuration: Int?
    public let lightSleepDuration: Int?
    public let remSleepDuration: Int?
    public let totalSleepDuration: Int?
    public let timeInBed: Int?
    public let efficiency: Int?
    public let latency: Int?
    public let restlessPeriods: Int?
    public let averageBreath: Double?
    public let averageHeartRate: Double?
    public let averageHrv: Int?
    public let lowestHeartRate: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case day
        case type
        case bedtimeStart = "bedtime_start"
        case bedtimeEnd = "bedtime_end"
        case awakeTime = "awake_time"
        case deepSleepDuration = "deep_sleep_duration"
        case lightSleepDuration = "light_sleep_duration"
        case remSleepDuration = "rem_sleep_duration"
        case totalSleepDuration = "total_sleep_duration"
        case timeInBed = "time_in_bed"
        case efficiency
        case latency
        case restlessPeriods = "restless_periods"
        case averageBreath = "average_breath"
        case averageHeartRate = "average_heart_rate"
        case averageHrv = "average_hrv"
        case lowestHeartRate = "lowest_heart_rate"
    }
}
