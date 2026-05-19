import AppKit

enum BarMetric: String, CaseIterable, Codable, Identifiable {
    case sleepScore
    case rem
    case hrv
    case rhr
    case readiness
    case activity
    case deepSleep
    case deepSleepPercentage
    case totalSleep
    case sleepDebt
    case lightSleep
    case lightSleepPercentage
    case awakeTime
    case timeInBed
    case sleepLatency
    case averageBreath
    case remPercentage
    case hrvBalance
    case sleepBalance
    case sleepRegularity
    case bodyTemperatureDeviation
    case sleepEfficiency
    case recoveryCost
    case dailyStress
    case resilience
    case cardiovascularAge
    case averageSpO2
    case breathingDisturbance
    case vo2Max
    case optimalBedtime
    case sleepTimeRecommendation
    case bestSleepWindow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sleepScore:
            return "Sleep Score"
        case .rem:
            return "REM"
        case .remPercentage:
            return "REM %"
        case .deepSleep:
            return "Deep Sleep"
        case .deepSleepPercentage:
            return "Deep %"
        case .totalSleep:
            return "Total Sleep"
        case .sleepDebt:
            return "Sleep Debt"
        case .lightSleep:
            return "Light Sleep"
        case .lightSleepPercentage:
            return "Light %"
        case .awakeTime:
            return "Awake Time"
        case .timeInBed:
            return "Time in Bed"
        case .sleepLatency:
            return "Sleep Latency"
        case .averageBreath:
            return "Breath Rate"
        case .hrv:
            return "HRV"
        case .hrvBalance:
            return "HRV Balance"
        case .rhr:
            return "RHR"
        case .readiness:
            return "Readiness"
        case .sleepBalance:
            return "Sleep Balance"
        case .sleepRegularity:
            return "Sleep Regularity"
        case .activity:
            return "Activity"
        case .bodyTemperatureDeviation:
            return "Body Temp"
        case .sleepEfficiency:
            return "Sleep Efficiency"
        case .recoveryCost:
            return "Recovery Cost"
        case .dailyStress:
            return "Daily Stress"
        case .resilience:
            return "Resilience"
        case .cardiovascularAge:
            return "Cardio Age"
        case .averageSpO2:
            return "Average SpO2"
        case .breathingDisturbance:
            return "Breathing"
        case .vo2Max:
            return "VO2 Max"
        case .optimalBedtime:
            return "Optimal Bedtime"
        case .sleepTimeRecommendation:
            return "Sleep Time"
        case .bestSleepWindow:
            return "Best Sleep Window"
        }
    }

    var symbolName: String {
        switch self {
        case .sleepScore:
            return "moon.zzz"
        case .rem, .remPercentage:
            return "bed.double"
        case .deepSleep, .deepSleepPercentage:
            return "bed.double.circle"
        case .totalSleep:
            return "clock"
        case .sleepDebt:
            return "hourglass"
        case .lightSleep, .lightSleepPercentage:
            return "bed.double"
        case .awakeTime:
            return "sunrise"
        case .timeInBed:
            return "clock"
        case .sleepLatency:
            return "timer"
        case .averageBreath:
            return "lungs"
        case .hrv, .rhr, .readiness, .recoveryCost:
            return "heart.text.square"
        case .hrvBalance:
            return "waveform.path.ecg"
        case .sleepBalance:
            return "scalemass"
        case .sleepRegularity:
            return "calendar"
        case .activity:
            return "figure.walk"
        case .bodyTemperatureDeviation:
            return "thermometer.medium"
        case .sleepEfficiency:
            return "bed.double.fill"
        case .dailyStress:
            return "waveform.path.ecg"
        case .resilience:
            return "shield"
        case .cardiovascularAge:
            return "heart"
        case .averageSpO2:
            return "lungs.fill"
        case .breathingDisturbance:
            return "wind"
        case .vo2Max:
            return "figure.run"
        case .optimalBedtime, .bestSleepWindow:
            return "bed.double.fill"
        case .sleepTimeRecommendation:
            return "sparkles"
        }
    }

    var unit: String {
        unit(temperatureUnit: .celsius)
    }

    func unit(temperatureUnit: TemperatureUnit) -> String {
        switch self {
        case .sleepScore, .readiness, .activity, .sleepEfficiency, .hrvBalance, .sleepBalance, .sleepRegularity, .breathingDisturbance:
            return ""
        case .rem, .deepSleep, .totalSleep, .sleepDebt, .lightSleep, .awakeTime, .timeInBed, .sleepLatency:
            return ""
        case .remPercentage, .deepSleepPercentage, .lightSleepPercentage:
            return "%"
        case .hrv:
            return "ms"
        case .rhr:
            return "bpm"
        case .averageBreath:
            return "rpm"
        case .bodyTemperatureDeviation:
            return temperatureUnit.symbol
        case .dailyStress, .resilience:
            return ""
        case .cardiovascularAge:
            return "y"
        case .averageSpO2:
            return "%"
        case .recoveryCost:
            return "pts"
        case .vo2Max, .optimalBedtime, .sleepTimeRecommendation, .bestSleepWindow:
            return ""
        }
    }

    var isCategorical: Bool {
        switch self {
        case .dailyStress, .resilience, .optimalBedtime, .sleepTimeRecommendation, .bestSleepWindow:
            return true
        case .sleepScore, .rem, .remPercentage, .hrv, .rhr, .readiness, .activity, .deepSleep, .deepSleepPercentage, .totalSleep, .sleepDebt, .lightSleep, .lightSleepPercentage, .awakeTime, .timeInBed, .sleepLatency, .averageBreath, .hrvBalance, .sleepBalance, .sleepRegularity, .bodyTemperatureDeviation, .sleepEfficiency, .recoveryCost, .cardiovascularAge, .averageSpO2, .breathingDisturbance, .vo2Max:
            return false
        }
    }

    var categoricalDescription: String {
        switch self {
        case .resilience:
            return "Long-term resilience level"
        case .dailyStress:
            return "Daily stress summary"
        case .optimalBedtime:
            return "Recommended bedtime window"
        case .sleepTimeRecommendation:
            return "Oura sleep-time guidance"
        case .bestSleepWindow:
            return "Best historical bedtime window"
        case .sleepScore, .rem, .remPercentage, .hrv, .rhr, .readiness, .activity, .deepSleep, .deepSleepPercentage, .totalSleep, .sleepDebt, .lightSleep, .lightSleepPercentage, .awakeTime, .timeInBed, .sleepLatency, .averageBreath, .hrvBalance, .sleepBalance, .sleepRegularity, .bodyTemperatureDeviation, .sleepEfficiency, .recoveryCost, .cardiovascularAge, .averageSpO2, .breathingDisturbance, .vo2Max:
            return ""
        }
    }

    func formattedValue(_ value: Double, temperatureUnit: TemperatureUnit = .celsius) -> String {
        switch self {
        case .rem, .deepSleep, .totalSleep, .sleepDebt, .lightSleep, .awakeTime, .timeInBed, .sleepLatency:
            return formattedDuration(minutes: value)
        case .sleepScore, .readiness, .activity, .hrv, .rhr, .sleepEfficiency, .hrvBalance, .sleepBalance, .sleepRegularity, .breathingDisturbance, .cardiovascularAge, .remPercentage, .deepSleepPercentage, .lightSleepPercentage, .recoveryCost:
            return "\(Int(value.rounded()))\(unit)"
        case .averageBreath, .averageSpO2, .vo2Max:
            return "\(String(format: "%.1f", value))\(unit)"
        case .bodyTemperatureDeviation:
            let converted = temperatureUnit.convertDeviationFromCelsius(value)
            let prefix = converted >= 0 ? "+" : ""
            return "\(prefix)\(String(format: "%.1f", converted))\(unit(temperatureUnit: temperatureUnit))"
        case .resilience:
            return resilienceLabel(for: value)
        case .dailyStress, .optimalBedtime, .sleepTimeRecommendation, .bestSleepWindow:
            return ""
        }
    }

    func formattedDelta(_ value: Double, temperatureUnit: TemperatureUnit = .celsius) -> String {
        switch self {
        case .rem, .deepSleep, .totalSleep, .sleepDebt, .lightSleep, .awakeTime, .timeInBed, .sleepLatency:
            return formattedDuration(minutes: value)
        case .sleepScore, .readiness, .activity, .hrv, .rhr, .sleepEfficiency, .hrvBalance, .sleepBalance, .sleepRegularity, .breathingDisturbance, .cardiovascularAge, .remPercentage, .deepSleepPercentage, .lightSleepPercentage, .recoveryCost:
            return "\(Int(value.rounded()))\(unit)"
        case .averageBreath, .averageSpO2, .vo2Max:
            return "\(String(format: "%.1f", value))\(unit)"
        case .bodyTemperatureDeviation:
            let converted = temperatureUnit.convertDeviationFromCelsius(value)
            return "\(String(format: "%.1f", converted))\(unit(temperatureUnit: temperatureUnit))"
        case .dailyStress, .resilience, .optimalBedtime, .sleepTimeRecommendation, .bestSleepWindow:
            return "\(Int(value.rounded()))"
        }
    }

    func formattedCategory(_ category: String) -> String {
        switch self {
        case .dailyStress:
            return category
                .split(separator: "_")
                .map { $0.capitalized }
                .joined(separator: " ")
        case .resilience:
            return category.capitalized
        case .sleepTimeRecommendation:
            return category
                .split { $0 == "_" || $0 == "-" }
                .map { $0.capitalized }
                .joined(separator: " ")
        case .sleepScore, .rem, .remPercentage, .deepSleep, .deepSleepPercentage, .totalSleep, .sleepDebt, .lightSleep, .lightSleepPercentage, .awakeTime, .timeInBed, .sleepLatency, .averageBreath, .hrv, .rhr, .readiness, .activity, .hrvBalance, .sleepBalance, .sleepRegularity, .bodyTemperatureDeviation, .sleepEfficiency, .recoveryCost, .cardiovascularAge, .averageSpO2, .breathingDisturbance, .vo2Max, .optimalBedtime, .bestSleepWindow:
            return category
        }
    }

    private func resilienceLabel(for value: Double) -> String {
        switch Int(value.rounded()) {
        case ..<2:
            return "Limited"
        case 2:
            return "Adequate"
        case 3:
            return "Solid"
        case 4:
            return "Strong"
        default:
            return "Exceptional"
        }
    }

    private func formattedDuration(minutes: Double) -> String {
        let roundedMinutes = Int(minutes.rounded())
        let sign = roundedMinutes < 0 ? "-" : ""
        let absoluteMinutes = abs(roundedMinutes)
        let hours = absoluteMinutes / 60
        let minutesRemainder = absoluteMinutes % 60
        return "\(sign)\(hours):\(String(format: "%02d", minutesRemainder))"
    }
}

enum IconRenderer {
    static func image(for metric: BarMetric, color: NSColor, style: IconStyle = .color) -> NSImage? {
        var configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        if style == .color {
            configuration = configuration.applying(NSImage.SymbolConfiguration(hierarchicalColor: color))
        }
        let image = NSImage(systemSymbolName: metric.symbolName, accessibilityDescription: metric.label)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = style == .monochrome
        return image
    }
}
