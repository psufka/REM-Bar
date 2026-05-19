import Foundation

enum MetricDisplayGroup: String, CaseIterable, Identifiable {
    case all
    case sleep
    case recovery
    case activity
    case cardiovascular
    case guidance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            return "All"
        case .sleep:
            return "Sleep"
        case .recovery:
            return "Recovery"
        case .activity:
            return "Activity"
        case .cardiovascular:
            return "Cardio"
        case .guidance:
            return "Guidance"
        }
    }
}

enum ThresholdDirection: String, Codable, Equatable {
    case higherIsBetter
    case lowerIsBetter
    case closerToZeroIsBetter

    var greenLabel: String {
        switch self {
        case .higherIsBetter:
            return "Green at/above"
        case .lowerIsBetter:
            return "Green at/below"
        case .closerToZeroIsBetter:
            return "Green within"
        }
    }

    var orangeLabel: String {
        switch self {
        case .higherIsBetter:
            return "Orange at/above"
        case .lowerIsBetter:
            return "Orange at/below"
        case .closerToZeroIsBetter:
            return "Orange within"
        }
    }
}

struct MetricThresholdOverride: Codable, Equatable {
    let direction: ThresholdDirection
    var green: Double
    var orange: Double
}

enum MetricPreset: String, CaseIterable, Identifiable {
    case sleepFocus
    case recovery
    case cardio
    case minimal
    case everything

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sleepFocus:
            return "Sleep Focus"
        case .recovery:
            return "Recovery"
        case .cardio:
            return "Cardio"
        case .minimal:
            return "Minimal"
        case .everything:
            return "Everything"
        }
    }

    var symbolName: String {
        switch self {
        case .sleepFocus:
            return "bed.double"
        case .recovery:
            return "heart.text.square"
        case .cardio:
            return "heart"
        case .minimal:
            return "moon.zzz"
        case .everything:
            return "square.grid.3x3"
        }
    }

    var metrics: [BarMetric] {
        switch self {
        case .sleepFocus:
            return [.sleepScore, .totalSleep, .sleepDebt, .deepSleep, .deepSleepPercentage, .rem, .remPercentage, .lightSleepPercentage, .sleepEfficiency, .sleepLatency, .averageBreath, .bestSleepWindow]
        case .recovery:
            return [.readiness, .hrv, .rhr, .hrvBalance, .sleepBalance, .bodyTemperatureDeviation, .resilience, .dailyStress]
        case .cardio:
            return [.cardiovascularAge, .vo2Max, .rhr, .hrv, .averageSpO2, .breathingDisturbance, .activity]
        case .minimal:
            return [.sleepScore, .readiness, .sleepDebt]
        case .everything:
            return BarMetric.allCases
        }
    }
}

struct MetricExplanation: Equatable {
    let summary: String
    let source: String
    let interpretation: String
    let learnMoreURL: URL?

    init(summary: String, source: String, interpretation: String, learnMoreURL: URL? = nil) {
        self.summary = summary
        self.source = source
        self.interpretation = interpretation
        self.learnMoreURL = learnMoreURL
    }
}

private enum OuraHelpLink {
    static let sleepScore = URL(string: "https://support.ouraring.com/hc/en-us/articles/360025445574-Sleep-Score")!
    static let sleepContributors = URL(string: "https://support.ouraring.com/hc/en-us/articles/360057792293-Sleep-Contributors")!
    static let bedtimeGuidance = URL(string: "https://support.ouraring.com/hc/en-us/articles/360025445154-Bedtime-Guidance")!
    static let readinessScore = URL(string: "https://support.ouraring.com/hc/en-us/articles/360025589793-Readiness-Score")!
    static let readinessContributors = URL(string: "https://support.ouraring.com/hc/en-us/articles/360057791533-Readiness-Contributors")!
    static let restingHeartRate = URL(string: "https://support.ouraring.com/hc/en-us/articles/360025588793-Resting-Heart-Rate")!
    static let hrv = URL(string: "https://support.ouraring.com/hc/en-us/articles/360025441974-Heart-Rate-Variability")!
    static let respiratoryRate = URL(string: "https://support.ouraring.com/hc/en-us/articles/360025443174-Respiratory-Rate")!
    static let bodyTemperature = URL(string: "https://support.ouraring.com/hc/en-us/articles/360025587493-Body-Temperature")!
    static let activityContributors = URL(string: "https://support.ouraring.com/hc/en-us/articles/360055901214-Activity-Contributors")!
    static let daytimeStress = URL(string: "https://support.ouraring.com/hc/en-us/articles/21205822135315-Daytime-Stress")!
    static let resilience = URL(string: "https://support.ouraring.com/hc/en-us/articles/25358829055251-Resilience")!
    static let cardiovascularAge = URL(string: "https://support.ouraring.com/hc/en-us/articles/28451491040019-Cardiovascular-Age")!
    static let cardioCapacity = URL(string: "https://support.ouraring.com/hc/en-us/articles/28336620578835-Cardio-Capacity-VO2-Max")!
    static let spo2 = URL(string: "https://support.ouraring.com/hc/en-us/articles/7328398760851-Blood-Oxygen-Sensing-SpO2")!
}

extension BarMetric {
    var displayGroup: MetricDisplayGroup {
        switch self {
        case .sleepScore, .rem, .remPercentage, .deepSleep, .deepSleepPercentage, .totalSleep, .sleepDebt, .lightSleep, .lightSleepPercentage, .awakeTime, .timeInBed, .sleepLatency, .averageBreath, .sleepEfficiency:
            return .sleep
        case .readiness, .hrv, .rhr, .hrvBalance, .sleepBalance, .sleepRegularity, .bodyTemperatureDeviation, .dailyStress, .resilience:
            return .recovery
        case .activity:
            return .activity
        case .cardiovascularAge, .averageSpO2, .breathingDisturbance, .vo2Max:
            return .cardiovascular
        case .optimalBedtime, .sleepTimeRecommendation, .bestSleepWindow:
            return .guidance
        }
    }

    var explanation: MetricExplanation {
        switch self {
        case .sleepScore:
            return MetricExplanation(summary: "Oura's 0-100 score for overall sleep quality and quantity, based on contributors such as total sleep, efficiency, restfulness, REM, deep sleep, latency, and timing.", source: "Oura Daily Sleep score", interpretation: "Higher is better. Oura rates 85-100 as Optimal, 70-84 as Good, 60-69 as Fair, and 0-59 as Pay Attention.", learnMoreURL: OuraHelpLink.sleepScore)
        case .rem:
            return MetricExplanation(summary: "Time spent in REM sleep. Oura describes REM as associated with dreaming, memory consolidation, creativity, and mental recovery.", source: "Oura Sleep detail rem_sleep_duration", interpretation: "Most healthy adults average around 1.5 hours. With naps enabled, REM-Bar follows Oura by including nap REM.", learnMoreURL: OuraHelpLink.sleepContributors)
        case .remPercentage:
            return MetricExplanation(summary: "REM sleep as a share of total sleep.", source: "REM-Bar calculation from Oura rem_sleep_duration and total_sleep_duration", interpretation: "Useful when total sleep changes a lot. With naps enabled, REM-Bar includes nap REM and total sleep.", learnMoreURL: OuraHelpLink.sleepContributors)
        case .deepSleep:
            return MetricExplanation(summary: "Time spent in deep sleep, the most physically restorative sleep stage.", source: "Oura Sleep detail deep_sleep_duration", interpretation: "Oura notes adults often spend about 15-20% of total sleep in deep sleep. With naps enabled, REM-Bar includes nap deep sleep.", learnMoreURL: OuraHelpLink.sleepContributors)
        case .deepSleepPercentage:
            return MetricExplanation(summary: "Deep sleep as a share of total sleep.", source: "REM-Bar calculation from Oura deep_sleep_duration and total_sleep_duration", interpretation: "Oura notes many adults spend about 15-20% of total sleep in deep sleep, though personal baseline matters.", learnMoreURL: OuraHelpLink.sleepContributors)
        case .totalSleep:
            return MetricExplanation(summary: "Total time asleep, including light, REM, and deep sleep. Awake time is not included.", source: "Oura Sleep detail total_sleep_duration", interpretation: "Oura includes all sleep, including naps. REM-Bar uses the same default, with a setting for main sleep only.", learnMoreURL: OuraHelpLink.sleepContributors)
        case .sleepDebt:
            return MetricExplanation(summary: "REM-Bar's running estimate of sleep missed versus your selected sleep target.", source: "REM-Bar calculation from Oura Sleep detail total_sleep_duration", interpretation: "Lower is better. It uses a decaying 14-day balance and follows your Naps setting, defaulting to Oura-like nap inclusion.", learnMoreURL: OuraHelpLink.sleepContributors)
        case .lightSleep:
            return MetricExplanation(summary: "Time spent in light sleep, one of the sleep stages that contributes to total sleep.", source: "Oura Sleep detail light_sleep_duration", interpretation: "Light sleep often makes up much of sleep. With naps enabled, REM-Bar includes nap light sleep.", learnMoreURL: OuraHelpLink.sleepContributors)
        case .lightSleepPercentage:
            return MetricExplanation(summary: "Light sleep as a share of total sleep.", source: "REM-Bar calculation from Oura light_sleep_duration and total_sleep_duration", interpretation: "Light sleep often makes up the largest share of sleep. Interpret this with REM %, Deep %, and total sleep.", learnMoreURL: OuraHelpLink.sleepContributors)
        case .awakeTime:
            return MetricExplanation(summary: "Time awake during the detected sleep period.", source: "Oura Sleep detail awake_time", interpretation: "Lower is generally better. More wake time can reduce Sleep Score through efficiency and restfulness.", learnMoreURL: OuraHelpLink.sleepContributors)
        case .timeInBed:
            return MetricExplanation(summary: "Elapsed time between bedtime start and bedtime end.", source: "Oura Sleep detail time_in_bed", interpretation: "Use this to separate opportunity to sleep from actual total sleep. A large gap can point to latency or awake time.", learnMoreURL: OuraHelpLink.sleepContributors)
        case .sleepLatency:
            return MetricExplanation(summary: "How long it took to fall asleep in the main sleep period.", source: "Oura Sleep detail latency", interpretation: "Oura describes 15-20 minutes as ideal. Less than five minutes can reflect overtiredness; longer latency can lower Sleep Score.", learnMoreURL: OuraHelpLink.sleepContributors)
        case .averageBreath:
            return MetricExplanation(summary: "Average breaths per minute during the previous night's sleep.", source: "Oura Sleep detail average_breath", interpretation: "Healthy adults are often around 12-20 breaths/min. Oura emphasizes comparing changes to your own baseline.", learnMoreURL: OuraHelpLink.respiratoryRate)
        case .hrv:
            return MetricExplanation(summary: "Average heart-rate variability during sleep, measured as millisecond-level variation between heartbeats.", source: "Oura Sleep detail average_hrv", interpretation: "Higher than your baseline often reflects stronger parasympathetic recovery. Lower values can follow stress, illness, alcohol, or hard training.", learnMoreURL: OuraHelpLink.hrv)
        case .rhr:
            return MetricExplanation(summary: "Lowest overnight resting heart rate when available; otherwise average overnight heart rate.", source: "Oura Sleep detail lowest_heart_rate / average_heart_rate", interpretation: "Oura builds an individual RHR baseline. Higher-than-usual RHR can reflect strain, illness, late meals, alcohol, or hard exercise.", learnMoreURL: OuraHelpLink.restingHeartRate)
        case .readiness:
            return MetricExplanation(summary: "Oura's 0-100 score for how balanced your recovery and activity are.", source: "Oura Daily Readiness score", interpretation: "Higher is better. Oura rates 85-100 as Optimal and below 70 as a sign to prioritize rest and recovery.", learnMoreURL: OuraHelpLink.readinessScore)
        case .activity:
            return MetricExplanation(summary: "Oura's 0-100 score for daily movement, inactivity, and training load relative to your goal and baseline.", source: "Oura Daily Activity score", interpretation: "Higher usually reflects stronger activity-goal progress without excessive inactivity or overreaching.", learnMoreURL: OuraHelpLink.activityContributors)
        case .hrvBalance:
            return MetricExplanation(summary: "Readiness contributor comparing recent HRV patterns with your longer-term baseline.", source: "Oura Daily Readiness contributors.hrv_balance", interpretation: "Higher means recent HRV is supporting recovery. Oura's balance contributors use weighted recent averages.", learnMoreURL: OuraHelpLink.readinessScore)
        case .sleepBalance:
            return MetricExplanation(summary: "Readiness contributor for recent sleep amount and sleep debt over roughly the last two weeks.", source: "Oura Daily Readiness contributors.sleep_balance", interpretation: "Higher means recent sleep quantity is supporting recovery relative to your baseline and general age-based guidance.", learnMoreURL: OuraHelpLink.readinessContributors)
        case .sleepRegularity:
            return MetricExplanation(summary: "Readiness contributor for bedtime and wake-time consistency over the previous two weeks.", source: "Oura Daily Readiness contributors.sleep_regularity", interpretation: "Higher means your schedule has been more regular. Oura says naps do not affect Sleep Regularity.", learnMoreURL: OuraHelpLink.readinessContributors)
        case .bodyTemperatureDeviation:
            return MetricExplanation(summary: "Overnight skin temperature deviation from your personal baseline.", source: "Oura Daily Readiness temperature_deviation", interpretation: "Closer to zero is usually better. Oura measures during sleep to reduce daytime noise; larger deviations can occur with illness or cycle changes.", learnMoreURL: OuraHelpLink.bodyTemperature)
        case .sleepEfficiency:
            return MetricExplanation(summary: "Percentage of time in bed that was spent asleep.", source: "Oura Sleep detail efficiency", interpretation: "Higher is better. Oura includes naps for efficiency; REM-Bar mirrors that when naps are enabled.", learnMoreURL: OuraHelpLink.sleepContributors)
        case .dailyStress:
            return MetricExplanation(summary: "Oura's daily physiological stress summary, based on daytime stress zones such as Stressed, Engaged, Relaxed, and Restored.", source: "Oura Daily Stress day_summary", interpretation: "This reflects biometrics, not emotions. Oura calculates stress from heart rate, HRV, motion, and average body temperature.", learnMoreURL: OuraHelpLink.daytimeStress)
        case .resilience:
            return MetricExplanation(summary: "Oura's medium-term estimate of your ability to withstand physiological stress and recover from it.", source: "Oura Daily Resilience level", interpretation: "It reflects a 14-day balance of daytime stress load, restorative time, and nighttime recovery, so it changes gradually.", learnMoreURL: OuraHelpLink.resilience)
        case .cardiovascularAge:
            return MetricExplanation(summary: "Oura's estimate of cardiovascular system health relative to your actual age.", source: "Oura Daily Cardiovascular Age vascular_age", interpretation: "Oura estimates this from pulse-wave-related signals in the PPG waveform. REM-Bar compares it with Personal Info age when available.", learnMoreURL: OuraHelpLink.cardiovascularAge)
        case .averageSpO2:
            return MetricExplanation(summary: "Average blood oxygen saturation during the longest sleep period of the day.", source: "Oura Daily SpO2 spo2_percentage.average", interpretation: "Higher is generally better. Oura measures this during sleep periods longer than three hours; persistent low values deserve careful interpretation.", learnMoreURL: OuraHelpLink.spo2)
        case .breathingDisturbance:
            return MetricExplanation(summary: "Oura's index of suspected overnight variation in blood oxygen levels.", source: "Oura Daily SpO2 breathing_disturbance_index", interpretation: "Lower is generally better. Oura's breathing-regularity signal is different from respiratory rate and may be unavailable on some rings.", learnMoreURL: OuraHelpLink.spo2)
        case .vo2Max:
            return MetricExplanation(summary: "Oura's estimated VO2 max, an age-adjusted cardiorespiratory fitness measure.", source: "Oura VO2 Max vo2_max", interpretation: "Higher is better. Oura says VO2 max reflects how well your heart, blood vessels, and muscles deliver oxygen during activity.", learnMoreURL: OuraHelpLink.cardioCapacity)
        case .optimalBedtime:
            return MetricExplanation(summary: "Oura's Bedtime Guidance from the Sleep Time endpoint. It may be an exact optimal bedtime window, or a recommendation to shift earlier or later when Oura has no exact window.", source: "Oura Sleep Time optimal_bedtime / recommendation", interpretation: "Use it as guidance, not a strict rule. Oura says missing the window does not directly affect Sleep or Readiness Scores.", learnMoreURL: OuraHelpLink.bedtimeGuidance)
        case .sleepTimeRecommendation:
            return MetricExplanation(summary: "Oura's sleep-time recommendation category for whether to follow, move earlier, or move later than your current pattern.", source: "Oura Sleep Time recommendation", interpretation: "Oura's Bedtime Guidance is dynamic and uses recent sleep patterns and body signals rather than a manually edited target.", learnMoreURL: OuraHelpLink.bedtimeGuidance)
        case .bestSleepWindow:
            return MetricExplanation(summary: "The 30-minute bedtime bucket associated with your best recent average Oura Sleep Score.", source: "REM-Bar calculation from Oura Sleep bedtime_start and Daily Sleep score", interpretation: "Use it as a transparent retrospective pattern. It requires at least three main sleeps in a bucket and does not include naps.", learnMoreURL: OuraHelpLink.bedtimeGuidance)
        }
    }

    var defaultThresholdOverride: MetricThresholdOverride? {
        switch self {
        case .sleepScore, .readiness, .activity, .hrvBalance, .sleepBalance, .sleepRegularity:
            return MetricThresholdOverride(direction: .higherIsBetter, green: 85, orange: 70)
        case .rem, .deepSleep:
            return MetricThresholdOverride(direction: .higherIsBetter, green: 90, orange: 60)
        case .totalSleep:
            return MetricThresholdOverride(direction: .higherIsBetter, green: 420, orange: 360)
        case .sleepDebt:
            return MetricThresholdOverride(direction: .lowerIsBetter, green: 30, orange: 90)
        case .remPercentage:
            return MetricThresholdOverride(direction: .higherIsBetter, green: 20, orange: 15)
        case .deepSleepPercentage:
            return MetricThresholdOverride(direction: .higherIsBetter, green: 15, orange: 10)
        case .lightSleep:
            return MetricThresholdOverride(direction: .higherIsBetter, green: 180, orange: 120)
        case .awakeTime:
            return MetricThresholdOverride(direction: .lowerIsBetter, green: 45, orange: 75)
        case .sleepLatency:
            return MetricThresholdOverride(direction: .lowerIsBetter, green: 20, orange: 45)
        case .hrv:
            return MetricThresholdOverride(direction: .higherIsBetter, green: 50, orange: 35)
        case .rhr:
            return MetricThresholdOverride(direction: .lowerIsBetter, green: 60, orange: 70)
        case .bodyTemperatureDeviation:
            return MetricThresholdOverride(direction: .closerToZeroIsBetter, green: 0.2, orange: 0.5)
        case .sleepEfficiency:
            return MetricThresholdOverride(direction: .higherIsBetter, green: 85, orange: 75)
        case .averageSpO2:
            return MetricThresholdOverride(direction: .higherIsBetter, green: 95, orange: 90)
        case .breathingDisturbance:
            return MetricThresholdOverride(direction: .lowerIsBetter, green: 5, orange: 15)
        case .vo2Max:
            return MetricThresholdOverride(direction: .higherIsBetter, green: 40, orange: 30)
        case .lightSleepPercentage, .timeInBed, .averageBreath, .cardiovascularAge, .dailyStress, .resilience, .optimalBedtime, .sleepTimeRecommendation, .bestSleepWindow:
            return nil
        }
    }

    static var thresholdCustomizableMetrics: [BarMetric] {
        allCases.filter { $0.defaultThresholdOverride != nil }
    }

    var supportsTrendWindow: Bool {
        switch self {
        case .dailyStress, .resilience, .optimalBedtime, .sleepTimeRecommendation:
            return false
        case .sleepScore, .rem, .remPercentage, .deepSleep, .deepSleepPercentage, .totalSleep, .sleepDebt, .lightSleep, .lightSleepPercentage, .awakeTime, .timeInBed, .sleepLatency, .averageBreath, .hrv, .rhr, .readiness, .activity, .hrvBalance, .sleepBalance, .sleepRegularity, .bodyTemperatureDeviation, .sleepEfficiency, .cardiovascularAge, .averageSpO2, .breathingDisturbance, .vo2Max, .bestSleepWindow:
            return true
        }
    }
}
