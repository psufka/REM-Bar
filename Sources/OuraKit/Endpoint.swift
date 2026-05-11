import Foundation

public enum Endpoint: Sendable {
    case dailySleep
    case sleep
    case dailyReadiness
    case dailyActivity
    case personalInfo

    public var path: String {
        switch self {
        case .dailySleep:
            return "/v2/usercollection/daily_sleep"
        case .sleep:
            return "/v2/usercollection/sleep"
        case .dailyReadiness:
            return "/v2/usercollection/daily_readiness"
        case .dailyActivity:
            return "/v2/usercollection/daily_activity"
        case .personalInfo:
            return "/v2/usercollection/personal_info"
        }
    }
}
