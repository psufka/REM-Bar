import Foundation

public struct DailyActivity: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let day: String
    public let score: Int?
    public let activeCalories: Int?
    public let averageMetMinutes: Double?
    public let equivalentWalkingDistance: Int?
    public let highActivityMetMinutes: Int?
    public let highActivityTime: Int?
    public let inactivityAlerts: Int?
    public let lowActivityMetMinutes: Int?
    public let lowActivityTime: Int?
    public let mediumActivityMetMinutes: Int?
    public let mediumActivityTime: Int?
    public let steps: Int?
    public let totalCalories: Int?
    public let timestamp: String?

    enum CodingKeys: String, CodingKey {
        case id
        case day
        case score
        case activeCalories = "active_calories"
        case averageMetMinutes = "average_met_minutes"
        case equivalentWalkingDistance = "equivalent_walking_distance"
        case highActivityMetMinutes = "high_activity_met_minutes"
        case highActivityTime = "high_activity_time"
        case inactivityAlerts = "inactivity_alerts"
        case lowActivityMetMinutes = "low_activity_met_minutes"
        case lowActivityTime = "low_activity_time"
        case mediumActivityMetMinutes = "medium_activity_met_minutes"
        case mediumActivityTime = "medium_activity_time"
        case steps
        case totalCalories = "total_calories"
        case timestamp
    }
}
