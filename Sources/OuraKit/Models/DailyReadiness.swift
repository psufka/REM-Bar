import Foundation

public struct DailyReadiness: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let contributors: ReadinessContributors?
    public let day: String
    public let score: Int?
    public let temperatureDeviation: Double?
    public let temperatureTrendDeviation: Double?
    public let timestamp: String?

    public struct ReadinessContributors: Codable, Equatable, Sendable {
        public let activityBalance: Int?
        public let bodyTemperature: Int?
        public let hrvBalance: Int?
        public let previousDayActivity: Int?
        public let previousNight: Int?
        public let recoveryIndex: Int?
        public let restingHeartRate: Int?
        public let sleepBalance: Int?

        enum CodingKeys: String, CodingKey {
            case activityBalance = "activity_balance"
            case bodyTemperature = "body_temperature"
            case hrvBalance = "hrv_balance"
            case previousDayActivity = "previous_day_activity"
            case previousNight = "previous_night"
            case recoveryIndex = "recovery_index"
            case restingHeartRate = "resting_heart_rate"
            case sleepBalance = "sleep_balance"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case contributors
        case day
        case score
        case temperatureDeviation = "temperature_deviation"
        case temperatureTrendDeviation = "temperature_trend_deviation"
        case timestamp
    }
}
