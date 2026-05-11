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
}

enum IconRenderer {
    static func image(for metric: BarMetric, color: NSColor) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let image = NSImage(systemSymbolName: metric.symbolName, accessibilityDescription: metric.label)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }
}
