import Foundation

public struct OuraCollection<Element: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public let data: [Element]
    public let nextToken: String?

    public init(data: [Element], nextToken: String? = nil) {
        self.data = data
        self.nextToken = nextToken
    }

    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

public struct DailySleep: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let contributors: SleepContributors?
    public let day: String
    public let score: Int?
    public let timestamp: String?

    public struct SleepContributors: Codable, Equatable, Sendable {
        public let deepSleep: Int?
        public let efficiency: Int?
        public let latency: Int?
        public let remSleep: Int?
        public let restfulness: Int?
        public let timing: Int?
        public let totalSleep: Int?

        enum CodingKeys: String, CodingKey {
            case deepSleep = "deep_sleep"
            case efficiency
            case latency
            case remSleep = "rem_sleep"
            case restfulness
            case timing
            case totalSleep = "total_sleep"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case contributors
        case day
        case score
        case timestamp
    }
}
