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

    static func color(for value: Double?, metric: BarMetric) -> NSColor {
        guard let value else { return .systemRed }
        switch metric {
        case .sleepScore, .readiness:
            return color(for: value)
        case .rem:
            if value >= 90 { return .systemGreen }
            if value >= 60 { return .systemOrange }
            return .systemRed
        case .hrv:
            if value >= 50 { return .systemGreen }
            if value >= 35 { return .systemOrange }
            return .systemRed
        case .rhr:
            if value <= 60 { return .systemGreen }
            if value <= 70 { return .systemOrange }
            return .systemRed
        }
    }
}
