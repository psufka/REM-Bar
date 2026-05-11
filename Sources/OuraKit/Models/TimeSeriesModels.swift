import Foundation

public struct HeartRateSample: Codable, Equatable, Sendable {
    public let timestamp: String
    public let timestampUnix: Int?
    public let bpm: Int?
    public let source: String?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case timestampUnix = "timestamp_unix"
        case bpm
        case source
    }
}

public struct RingBatteryLevel: Codable, Equatable, Sendable {
    public let timestamp: String
    public let timestampUnix: Int?
    public let level: Int?
    public let charging: Bool?
    public let inCharger: Bool?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case timestampUnix = "timestamp_unix"
        case level
        case charging
        case inCharger = "in_charger"
    }
}
