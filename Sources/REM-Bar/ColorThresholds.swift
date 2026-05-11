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
        case .lightSleep:
            if value >= 180 { return .systemGreen }
            if value >= 120 { return .systemOrange }
            return .systemRed
        case .awakeTime:
            if value <= 45 { return .systemGreen }
            if value <= 75 { return .systemOrange }
            return .systemRed
        case .timeInBed:
            if value >= 420 && value <= 540 { return .systemGreen }
            if value >= 360 && value <= 600 { return .systemOrange }
            return .systemRed
        case .sleepLatency:
            if value <= 20 { return .systemGreen }
            if value <= 45 { return .systemOrange }
            return .systemRed
        case .averageBreath:
            if value >= 12 && value <= 20 { return .systemGreen }
            if value >= 10 && value <= 24 { return .systemOrange }
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
        case .hrvBalance, .sleepBalance, .sleepRegularity:
            return color(for: value)
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
        case .averageSpO2:
            if value >= 95 { return .systemGreen }
            if value >= 90 { return .systemOrange }
            return .systemRed
        case .breathingDisturbance:
            if value <= 5 { return .systemGreen }
            if value <= 15 { return .systemOrange }
            return .systemRed
        case .vo2Max:
            if value >= 40 { return .systemGreen }
            if value >= 30 { return .systemOrange }
            return .systemRed
        case .dailyStress, .optimalBedtime, .sleepTimeRecommendation:
            return .systemOrange
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
        case .sleepTimeRecommendation:
            switch category {
            case "follow_optimal_bedtime":
                return .systemGreen
            case "earlier_bedtime", "later_bedtime":
                return .systemOrange
            default:
                return .systemOrange
            }
        case .optimalBedtime:
            return .systemGreen
        case .sleepScore, .rem, .deepSleep, .totalSleep, .lightSleep, .awakeTime, .timeInBed, .sleepLatency, .averageBreath, .hrv, .rhr, .readiness, .activity, .hrvBalance, .sleepBalance, .sleepRegularity, .bodyTemperatureDeviation, .sleepEfficiency, .cardiovascularAge, .averageSpO2, .breathingDisturbance, .vo2Max:
            return .systemRed
        }
    }
}
