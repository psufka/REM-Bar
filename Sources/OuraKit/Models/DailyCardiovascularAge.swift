import Foundation

public struct DailyCardiovascularAge: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let day: String
    public let vascularAge: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case day
        case vascularAge = "vascular_age"
    }
}
