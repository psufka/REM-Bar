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
            return [.sleepScore, .totalSleep, .sleepDebt, .deepSleep, .rem, .sleepEfficiency, .sleepLatency, .averageBreath]
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
}

extension BarMetric {
    var displayGroup: MetricDisplayGroup {
        switch self {
        case .sleepScore, .rem, .deepSleep, .totalSleep, .sleepDebt, .lightSleep, .awakeTime, .timeInBed, .sleepLatency, .averageBreath, .sleepEfficiency:
            return .sleep
        case .readiness, .hrv, .rhr, .hrvBalance, .sleepBalance, .sleepRegularity, .bodyTemperatureDeviation, .dailyStress, .resilience:
            return .recovery
        case .activity:
            return .activity
        case .cardiovascularAge, .averageSpO2, .breathingDisturbance, .vo2Max:
            return .cardiovascular
        case .optimalBedtime, .sleepTimeRecommendation:
            return .guidance
        }
    }

    var explanation: MetricExplanation {
        switch self {
        case .sleepScore:
            return MetricExplanation(summary: "Oura's overall daily sleep score.", source: "Daily Sleep score", interpretation: "Higher is better; 85+ is typically strong, while lower values suggest sleep quantity or quality was limited.")
        case .rem:
            return MetricExplanation(summary: "Minutes spent in REM sleep.", source: "Sleep detail rem_sleep_duration", interpretation: "More REM generally supports cognitive recovery; use your own baseline more than a single-night target.")
        case .deepSleep:
            return MetricExplanation(summary: "Minutes spent in deep sleep.", source: "Sleep detail deep_sleep_duration", interpretation: "Deep sleep supports physical recovery; low values are often useful to compare against recent trends.")
        case .totalSleep:
            return MetricExplanation(summary: "Total asleep time from the latest sleep period.", source: "Sleep detail total_sleep_duration", interpretation: "Longer is generally better until it reaches your personal goal; REM-Bar colors this against broad adult sleep ranges.")
        case .sleepDebt:
            return MetricExplanation(summary: "How far total sleep fell below your selected sleep target.", source: "REM-Bar calculation from total sleep and Sleep target", interpretation: "Lower is better. Zero means the latest sleep met or exceeded your selected target.")
        case .lightSleep:
            return MetricExplanation(summary: "Minutes spent in light sleep.", source: "Sleep detail light_sleep_duration", interpretation: "Light sleep usually makes up much of total sleep; interpret it alongside total, REM, and deep sleep.")
        case .awakeTime:
            return MetricExplanation(summary: "Time awake during the sleep period.", source: "Sleep detail awake_time", interpretation: "Lower is generally better. Higher awake time can explain lower sleep efficiency.")
        case .timeInBed:
            return MetricExplanation(summary: "Elapsed time between bedtime start and end.", source: "Sleep detail time_in_bed", interpretation: "Useful for distinguishing time in bed from actual asleep time.")
        case .sleepLatency:
            return MetricExplanation(summary: "How long it took to fall asleep.", source: "Sleep detail latency", interpretation: "Lower is generally better, though very short latency can also reflect sleep pressure.")
        case .averageBreath:
            return MetricExplanation(summary: "Average respiratory rate during sleep.", source: "Sleep detail average_breath", interpretation: "Stable personal patterns matter most; large deviations can be worth reviewing with other recovery signals.")
        case .hrv:
            return MetricExplanation(summary: "Average heart-rate variability during sleep.", source: "Sleep detail average_hrv", interpretation: "Higher than your baseline often reflects better recovery; low values can follow stress, alcohol, illness, or hard training.")
        case .rhr:
            return MetricExplanation(summary: "Lowest overnight heart rate when available, otherwise average heart rate.", source: "Sleep detail lowest_heart_rate / average_heart_rate", interpretation: "Lower than your baseline can reflect recovery; higher values can signal stress, illness, or load.")
        case .readiness:
            return MetricExplanation(summary: "Oura's overall recovery/readiness score.", source: "Daily Readiness score", interpretation: "Higher is better. Use it to decide whether to push, maintain, or recover.")
        case .activity:
            return MetricExplanation(summary: "Oura's daily activity score.", source: "Daily Activity score", interpretation: "Higher usually reflects stronger movement/activity goal progress.")
        case .hrvBalance:
            return MetricExplanation(summary: "Readiness contributor for recent HRV balance.", source: "Daily Readiness contributors.hrv_balance", interpretation: "Higher means HRV is more favorable relative to your recent baseline.")
        case .sleepBalance:
            return MetricExplanation(summary: "Readiness contributor for recent sleep balance.", source: "Daily Readiness contributors.sleep_balance", interpretation: "Higher means recent sleep quantity is supporting recovery.")
        case .sleepRegularity:
            return MetricExplanation(summary: "Readiness contributor for sleep timing consistency.", source: "Daily Readiness contributors.sleep_regularity", interpretation: "Higher means your sleep schedule has been more regular.")
        case .bodyTemperatureDeviation:
            return MetricExplanation(summary: "Overnight body temperature deviation from your baseline.", source: "Daily Readiness temperature_deviation", interpretation: "Closer to zero is usually better. Larger deviations can occur with illness, cycle changes, or environmental factors.")
        case .sleepEfficiency:
            return MetricExplanation(summary: "Percentage of time in bed spent asleep.", source: "Sleep detail efficiency", interpretation: "Higher is better; low efficiency often means more awake time or fragmented sleep.")
        case .dailyStress:
            return MetricExplanation(summary: "Oura's daily stress summary category.", source: "Daily Stress day_summary", interpretation: "Categorical signal summarizing stress/restoration across the day.")
        case .resilience:
            return MetricExplanation(summary: "Oura's longer-term resilience category.", source: "Daily Resilience level", interpretation: "Higher categories suggest stronger recent capacity to handle stress and recover.")
        case .cardiovascularAge:
            return MetricExplanation(summary: "Oura's estimated cardiovascular age.", source: "Daily Cardiovascular Age vascular_age", interpretation: "REM-Bar compares this with Personal Info age when available; lower or equal is better.")
        case .averageSpO2:
            return MetricExplanation(summary: "Average blood oxygen saturation during sleep.", source: "Daily SpO2 spo2_percentage.average", interpretation: "Higher is generally better; persistent low values should be interpreted carefully and medically if relevant.")
        case .breathingDisturbance:
            return MetricExplanation(summary: "Oura's breathing disturbance index.", source: "Daily SpO2 breathing_disturbance_index", interpretation: "Lower is generally better; unavailable on some rings or memberships.")
        case .vo2Max:
            return MetricExplanation(summary: "Oura's estimated cardiorespiratory fitness.", source: "VO2 Max vo2_max", interpretation: "Higher is better; availability depends on supported ring/app data.")
        case .optimalBedtime:
            return MetricExplanation(summary: "Oura's recommended bedtime window.", source: "Sleep Time optimal_bedtime", interpretation: "Use this as a guidance window rather than a strict rule.")
        case .sleepTimeRecommendation:
            return MetricExplanation(summary: "Oura's sleep-time recommendation category.", source: "Sleep Time recommendation", interpretation: "Summarizes whether Oura suggests following, moving earlier, or moving later than the current bedtime pattern.")
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
        case .timeInBed, .averageBreath, .cardiovascularAge, .dailyStress, .resilience, .optimalBedtime, .sleepTimeRecommendation:
            return nil
        }
    }

    static var thresholdCustomizableMetrics: [BarMetric] {
        allCases.filter { $0.defaultThresholdOverride != nil }
    }
}
