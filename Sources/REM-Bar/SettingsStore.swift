import Foundation
import OuraKit

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    enum RefreshCadence: Int, CaseIterable, Identifiable {
        case one = 60
        case five = 300
        case fifteen = 900
        case thirty = 1800
        case sixty = 3600

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .one:
                return "1 min"
            case .five:
                return "5 min"
            case .fifteen:
                return "15 min"
            case .thirty:
                return "30 min"
            case .sixty:
                return "60 min"
            }
        }
    }

    @Published var refreshCadence: RefreshCadence {
        didSet {
            userDefaults.set(refreshCadence.rawValue, forKey: Keys.refreshCadence)
        }
    }

    @Published var selectedMetric: BarMetric {
        didSet {
            guard enabledMetrics.contains(selectedMetric) else {
                selectedMetric = orderedEnabledMetrics.first ?? .sleepScore
                return
            }
            userDefaults.set(selectedMetric.rawValue, forKey: Keys.selectedMetric)
        }
    }

    @Published private(set) var enabledMetrics: Set<BarMetric> {
        didSet {
            guard !enabledMetrics.isEmpty else {
                enabledMetrics = oldValue.isEmpty ? Self.defaultEnabledMetrics : oldValue
                return
            }
            saveEnabledMetrics()
            if !enabledMetrics.contains(selectedMetric) {
                selectedMetric = orderedEnabledMetrics.first ?? .sleepScore
            }
        }
    }

    var orderedEnabledMetrics: [BarMetric] {
        BarMetric.allCases.filter { enabledMetrics.contains($0) }
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let enabledMetrics = Self.loadEnabledMetrics(from: userDefaults)
        self.enabledMetrics = enabledMetrics
        let rawCadence = userDefaults.integer(forKey: Keys.refreshCadence)
        self.refreshCadence = RefreshCadence(rawValue: rawCadence) ?? .five
        let rawMetric = userDefaults.string(forKey: Keys.selectedMetric) ?? BarMetric.sleepScore.rawValue
        let selectedMetric = BarMetric(rawValue: rawMetric) ?? .sleepScore
        self.selectedMetric = enabledMetrics.contains(selectedMetric)
            ? selectedMetric
            : Self.orderedMetrics(in: enabledMetrics).first ?? .sleepScore
    }

    func setMetric(_ metric: BarMetric, enabled: Bool) {
        if enabled {
            enabledMetrics.insert(metric)
        } else {
            enabledMetrics.remove(metric)
        }
    }

    private enum Keys {
        static let refreshCadence = "refreshCadence"
        static let selectedMetric = "selectedMetric"
        static let enabledMetrics = "enabledMetrics"
    }

    static let defaultEnabledMetrics: Set<BarMetric> = [
        .sleepScore,
        .rem,
        .hrv,
        .rhr,
        .readiness,
        .activity,
    ]

    private static func orderedMetrics(in metrics: Set<BarMetric>) -> [BarMetric] {
        BarMetric.allCases.filter { metrics.contains($0) }
    }

    private static func loadEnabledMetrics(from userDefaults: UserDefaults) -> Set<BarMetric> {
        guard let data = userDefaults.data(forKey: Keys.enabledMetrics),
              let rawValues = try? JSONDecoder().decode([String].self, from: data)
        else {
            return defaultEnabledMetrics
        }
        let metrics = Set(rawValues.compactMap(BarMetric.init(rawValue:)))
        return metrics.isEmpty ? defaultEnabledMetrics : metrics
    }

    private func saveEnabledMetrics() {
        let rawValues = BarMetric.allCases
            .filter { enabledMetrics.contains($0) }
            .map(\.rawValue)
        if let data = try? JSONEncoder().encode(rawValues) {
            userDefaults.set(data, forKey: Keys.enabledMetrics)
        }
    }
}
