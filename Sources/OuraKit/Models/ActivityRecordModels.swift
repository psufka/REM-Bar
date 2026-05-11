import Foundation

public struct Workout: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let activity: String?
    public let calories: Double?
    public let day: String
    public let distance: Double?
    public let endDatetime: String?
    public let intensity: String?
    public let label: String?
    public let source: String?
    public let startDatetime: String?

    enum CodingKeys: String, CodingKey {
        case id
        case activity
        case calories
        case day
        case distance
        case endDatetime = "end_datetime"
        case intensity
        case label
        case source
        case startDatetime = "start_datetime"
    }
}

public struct Session: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let day: String
    public let startDatetime: String?
    public let endDatetime: String?
    public let type: String?

    enum CodingKeys: String, CodingKey {
        case id
        case day
        case startDatetime = "start_datetime"
        case endDatetime = "end_datetime"
        case type
    }
}

public struct RestModePeriod: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let startDay: String?
    public let endDay: String?
    public let startTime: String?
    public let endTime: String?

    enum CodingKeys: String, CodingKey {
        case id
        case startDay = "start_day"
        case endDay = "end_day"
        case startTime = "start_time"
        case endTime = "end_time"
    }
}

public struct OuraTag: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let day: String?
    public let text: String?
    public let timestamp: String?
    public let tags: [String]?
}

public struct EnhancedTag: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let tagTypeCode: String?
    public let startTime: String?
    public let endTime: String?
    public let startDay: String?
    public let endDay: String?
    public let comment: String?
    public let customName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case tagTypeCode = "tag_type_code"
        case startTime = "start_time"
        case endTime = "end_time"
        case startDay = "start_day"
        case endDay = "end_day"
        case comment
        case customName = "custom_name"
    }
}
