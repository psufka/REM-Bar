import Foundation

public struct DailyStress: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let day: String
    public let daySummary: StressSummary?
    public let recoveryHigh: Int?
    public let stressHigh: Int?

    public enum StressSummary: String, Codable, Equatable, Sendable {
        case restored
        case normal
        case stressful
    }

    enum CodingKeys: String, CodingKey {
        case id
        case day
        case daySummary = "day_summary"
        case recoveryHigh = "recovery_high"
        case stressHigh = "stress_high"
    }
}
