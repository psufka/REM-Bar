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
}
