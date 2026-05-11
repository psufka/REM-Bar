import Foundation

public enum Endpoint: Sendable {
    case dailySleep
    case sleep
    case dailyReadiness
    case dailyActivity
    case dailyStress
    case dailyResilience
    case dailyCardiovascularAge
    case dailySpO2
    case vo2Max
    case sleepTime
    case heartRate
    case ringBatteryLevel
    case workout
    case session
    case restModePeriod
    case tag
    case enhancedTag
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
        case .dailyStress:
            return "/v2/usercollection/daily_stress"
        case .dailyResilience:
            return "/v2/usercollection/daily_resilience"
        case .dailyCardiovascularAge:
            return "/v2/usercollection/daily_cardiovascular_age"
        case .dailySpO2:
            return "/v2/usercollection/daily_spo2"
        case .vo2Max:
            return "/v2/usercollection/vO2_max"
        case .sleepTime:
            return "/v2/usercollection/sleep_time"
        case .heartRate:
            return "/v2/usercollection/heartrate"
        case .ringBatteryLevel:
            return "/v2/usercollection/ring_battery_level"
        case .workout:
            return "/v2/usercollection/workout"
        case .session:
            return "/v2/usercollection/session"
        case .restModePeriod:
            return "/v2/usercollection/rest_mode_period"
        case .tag:
            return "/v2/usercollection/tag"
        case .enhancedTag:
            return "/v2/usercollection/enhanced_tag"
        case .personalInfo:
            return "/v2/usercollection/personal_info"
        }
    }
}
