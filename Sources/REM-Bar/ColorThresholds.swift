import AppKit

enum ColorThresholds {
    static func color(for score: Double?) -> NSColor {
        guard let score else {
            return .systemRed
        }
        if score >= 85 {
            return .systemGreen
        }
        if score >= 70 {
            return .systemOrange
        }
        return .systemRed
    }

    static func color(for value: Double?, metric: BarMetric, baseline: Double? = nil, category: String? = nil) -> NSColor {
        if let category {
            return color(forCategory: category, metric: metric)
        }
        guard let value else { return .systemRed }
        switch metric {
        case .sleepScore, .readiness, .activity:
            return color(for: value)
        case .rem:
            if value >= 90 { return .systemGreen }
            if value >= 60 { return .systemOrange }
            return .systemRed
        case .deepSleep:
            if value >= 90 { return .systemGreen }
            if value >= 60 { return .systemOrange }
            return .systemRed
        case .totalSleep:
            if value >= 420 { return .systemGreen }
            if value >= 360 { return .systemOrange }
            return .systemRed
        case .hrv:
            if value >= 50 { return .systemGreen }
            if value >= 35 { return .systemOrange }
            return .systemRed
        case .rhr:
            if value <= 60 { return .systemGreen }
            if value <= 70 { return .systemOrange }
            return .systemRed
        case .bodyTemperatureDeviation:
            let absoluteValue = abs(value)
            if absoluteValue < 0.2 { return .systemGreen }
            if absoluteValue <= 0.5 { return .systemOrange }
            return .systemRed
        case .sleepEfficiency:
            if value >= 85 { return .systemGreen }
            if value >= 75 { return .systemOrange }
            return .systemRed
        case .dailyStress:
            if value < 1 { return .systemGreen }
            if value < 2 { return .systemOrange }
            return .systemRed
        case .resilience:
            if value >= 3 { return .systemGreen }
            if value >= 2 { return .systemOrange }
            return .systemRed
        case .cardiovascularAge:
            guard let baseline else { return .systemOrange }
            let delta = value - baseline
            if delta <= 0 { return .systemGreen }
            if delta <= 5 { return .systemOrange }
            return .systemRed
        }
    }

    static func color(forCategory category: String, metric: BarMetric) -> NSColor {
        switch metric {
        case .dailyStress:
            switch category {
            case "restored":
                return .systemGreen
            case "normal":
                return .systemOrange
            default:
                return .systemRed
            }
        case .resilience:
            switch category {
            case "solid", "strong", "exceptional":
                return .systemGreen
            case "adequate":
                return .systemOrange
            default:
                return .systemRed
            }
        case .sleepScore, .rem, .deepSleep, .totalSleep, .hrv, .rhr, .readiness, .activity, .bodyTemperatureDeviation, .sleepEfficiency, .cardiovascularAge:
            return .systemRed
        }
    }
}
