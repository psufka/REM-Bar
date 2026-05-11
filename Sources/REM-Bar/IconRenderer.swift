import AppKit

enum BarMetric: String, CaseIterable, Identifiable {
    case sleepScore
    case rem
    case hrv
    case rhr
    case readiness

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
        }
    }

    var unit: String {
        switch self {
        case .sleepScore, .readiness:
            return ""
        case .rem:
            return "m"
        case .hrv:
            return "ms"
        case .rhr:
            return "bpm"
        }
    }

    func formattedValue(_ value: Double) -> String {
        switch self {
        case .sleepScore, .readiness, .rem, .hrv, .rhr:
            return "\(Int(value.rounded()))\(unit)"
        }
    }

    func formattedDelta(_ value: Double) -> String {
        switch self {
        case .sleepScore, .readiness, .rem, .hrv, .rhr:
            return "\(Int(value.rounded()))\(unit)"
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
