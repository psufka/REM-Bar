import Foundation

public struct PersonalInfo: Codable, Equatable, Sendable {
    public let id: String?
    public let age: Int?
    public let weight: Double?
    public let height: Double?
    public let biologicalSex: String?
    public let email: String?

    enum CodingKeys: String, CodingKey {
        case id
        case age
        case weight
        case height
        case biologicalSex = "biological_sex"
        case email
    }
}
