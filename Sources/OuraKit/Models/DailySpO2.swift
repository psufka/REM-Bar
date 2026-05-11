import Foundation

public struct DailySpO2: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let day: String
    public let spo2Percentage: SpO2Percentage?
    public let breathingDisturbanceIndex: Int?

    public struct SpO2Percentage: Codable, Equatable, Sendable {
        public let average: Double?
    }

    enum CodingKeys: String, CodingKey {
        case id
        case day
        case spo2Percentage = "spo2_percentage"
        case breathingDisturbanceIndex = "breathing_disturbance_index"
    }
}
