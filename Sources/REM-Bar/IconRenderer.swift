import AppKit

enum BarMetric: String, CaseIterable, Codable, Identifiable {
    case sleepScore
    case rem
    case hrv
    case rhr
    case readiness
    case activity
    case bodyTemperatureDeviation
    case sleepEfficiency
    case dailyStress
    case resilience
    case cardiovascularAge

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sleepScore:
            return "Sleep Score"
        case .rem:
            return "REM"
        case .hrv:
            return "HRV"
        case .rhr:
            return "RHR"
        case .readiness:
            return "Readiness"
        case .activity:
            return "Activity"
        case .bodyTemperatureDeviation:
            return "Body Temp"
        case .sleepEfficiency:
            return "Sleep Efficiency"
        case .dailyStress:
            return "Daily Stress"
        case .resilience:
            return "Resilience"
        case .cardiovascularAge:
            return "Cardio Age"
        }
    }

    var symbolName: String {
        switch self {
        case .sleepScore:
            return "moon.zzz"
        case .rem:
            return "bed.double"
        case .hrv, .rhr, .readiness:
            return "heart.text.square"
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
        }
    }

    var unit: String {
        switch self {
        case .sleepScore, .readiness, .activity, .sleepEfficiency:
            return ""
        case .rem:
            return "m"
        case .hrv:
            return "ms"
        case .rhr:
            return "bpm"
        case .bodyTemperatureDeviation:
            return "C"
        case .dailyStress, .resilience:
            return ""
        case .cardiovascularAge:
            return "y"
        }
    }

    func formattedValue(_ value: Double) -> String {
        switch self {
        case .sleepScore, .readiness, .activity, .rem, .hrv, .rhr, .sleepEfficiency, .cardiovascularAge:
            return "\(Int(value.rounded()))\(unit)"
        case .bodyTemperatureDeviation:
            let prefix = value >= 0 ? "+" : ""
            return "\(prefix)\(String(format: "%.1f", value))\(unit)"
        case .dailyStress:
            return stressLabel(for: value)
        case .resilience:
            return resilienceLabel(for: value)
        }
    }

    func formattedDelta(_ value: Double) -> String {
        switch self {
        case .sleepScore, .readiness, .activity, .rem, .hrv, .rhr, .sleepEfficiency, .cardiovascularAge:
            return "\(Int(value.rounded()))\(unit)"
        case .bodyTemperatureDeviation:
            return "\(String(format: "%.1f", value))\(unit)"
        case .dailyStress, .resilience:
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
        case .sleepScore, .rem, .hrv, .rhr, .readiness, .activity, .bodyTemperatureDeviation, .sleepEfficiency, .cardiovascularAge:
            return category
        }
    }

    private func stressLabel(for value: Double) -> String {
        switch Int(value.rounded()) {
        case ..<1:
            return "Restored"
        case 1:
            return "Normal"
        default:
            return "Stressful"
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
}

enum IconRenderer {
    static func image(for metric: BarMetric, color: NSColor) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(hierarchicalColor: color))
        let image = NSImage(systemSymbolName: metric.symbolName, accessibilityDescription: metric.label)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = false
        return image
    }
}
