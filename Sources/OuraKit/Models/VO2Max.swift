import Foundation

public struct VO2Max: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let day: String
    public let timestamp: String?
    public let vo2Max: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case day
        case timestamp
        case vo2Max = "vo2_max"
    }
}
