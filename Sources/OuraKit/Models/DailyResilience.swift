import Foundation

public struct DailyResilience: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let day: String
    public let contributors: Contributors?
    public let level: Level?

    public enum Level: String, Codable, Equatable, Sendable {
        case limited
        case adequate
        case solid
        case strong
        case exceptional
    }

    public struct Contributors: Codable, Equatable, Sendable {
        public let sleepRecovery: Double?
        public let daytimeRecovery: Double?
        public let stress: Double?

        enum CodingKeys: String, CodingKey {
            case sleepRecovery = "sleep_recovery"
            case daytimeRecovery = "daytime_recovery"
            case stress
        }
    }
}
