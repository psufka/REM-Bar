import Foundation

public struct SleepTime: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let day: String
    public let optimalBedtime: OptimalBedtimeWindow?
    public let recommendation: String?
    public let status: String?

    public struct OptimalBedtimeWindow: Codable, Equatable, Sendable {
        public let dayTz: Int?
        public let startOffset: Int?
        public let endOffset: Int?

        enum CodingKeys: String, CodingKey {
            case dayTz = "day_tz"
            case startOffset = "start_offset"
            case endOffset = "end_offset"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case day
        case optimalBedtime = "optimal_bedtime"
        case recommendation
        case status
    }
}
