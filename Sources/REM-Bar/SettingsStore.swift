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

    @Published private(set) var metricOrder: [BarMetric] {
        didSet {
            saveMetricOrder()
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
        metricOrder.filter { enabledMetrics.contains($0) }
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let metricOrder = Self.loadMetricOrder(from: userDefaults)
        self.metricOrder = metricOrder
        let enabledMetrics = Self.loadEnabledMetrics(from: userDefaults)
        self.enabledMetrics = enabledMetrics
        let rawCadence = userDefaults.integer(forKey: Keys.refreshCadence)
        self.refreshCadence = RefreshCadence(rawValue: rawCadence) ?? .five
        let rawMetric = userDefaults.string(forKey: Keys.selectedMetric) ?? BarMetric.sleepScore.rawValue
        let selectedMetric = BarMetric(rawValue: rawMetric) ?? .sleepScore
        self.selectedMetric = enabledMetrics.contains(selectedMetric)
            ? selectedMetric
            : Self.orderedMetrics(in: enabledMetrics, metricOrder: metricOrder).first ?? .sleepScore
    }

    func setMetric(_ metric: BarMetric, enabled: Bool) {
        if enabled {
            enabledMetrics.insert(metric)
        } else {
            enabledMetrics.remove(metric)
        }
    }

    func moveMetric(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !source.isEmpty else { return }
        var order = metricOrder
        let moving = source.sorted().map { order[$0] }
        for index in source.sorted(by: >) {
            order.remove(at: index)
        }
        let earlierRemovedCount = source.filter { $0 < destination }.count
        let adjustedDestination = max(0, min(destination - earlierRemovedCount, order.count))
        order.insert(contentsOf: moving, at: adjustedDestination)
        metricOrder = Self.repairedMetricOrder(order)
    }

    func moveMetric(_ metric: BarMetric, to targetMetric: BarMetric) {
        guard metric != targetMetric,
              let source = metricOrder.firstIndex(of: metric),
              let target = metricOrder.firstIndex(of: targetMetric)
        else {
            return
        }
        moveMetric(
            fromOffsets: IndexSet(integer: source),
            toOffset: target > source ? target + 1 : target)
    }

    private enum Keys {
        static let refreshCadence = "refreshCadence"
        static let selectedMetric = "selectedMetric"
        static let enabledMetrics = "enabledMetrics"
        static let metricOrder = "metricOrder"
    }

    static let defaultEnabledMetrics: Set<BarMetric> = [
        .sleepScore,
        .rem,
        .hrv,
        .rhr,
        .readiness,
        .activity,
    ]

    private static func orderedMetrics(in metrics: Set<BarMetric>, metricOrder: [BarMetric]) -> [BarMetric] {
        metricOrder.filter { metrics.contains($0) }
    }

    private static func loadMetricOrder(from userDefaults: UserDefaults) -> [BarMetric] {
        guard let data = userDefaults.data(forKey: Keys.metricOrder),
              let rawValues = try? JSONDecoder().decode([String].self, from: data)
        else {
            return Array(BarMetric.allCases)
        }
        return repairedMetricOrder(rawValues.compactMap(BarMetric.init(rawValue:)))
    }

    private static func repairedMetricOrder(_ metrics: [BarMetric]) -> [BarMetric] {
        var seen = Set<BarMetric>()
        var repaired: [BarMetric] = []
        for metric in metrics where !seen.contains(metric) {
            repaired.append(metric)
            seen.insert(metric)
        }
        for metric in BarMetric.allCases where !seen.contains(metric) {
            repaired.append(metric)
        }
        return repaired
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
        let rawValues = metricOrder
            .filter { enabledMetrics.contains($0) }
            .map(\.rawValue)
        if let data = try? JSONEncoder().encode(rawValues) {
            userDefaults.set(data, forKey: Keys.enabledMetrics)
        }
    }

    private func saveMetricOrder() {
        let rawValues = metricOrder.map(\.rawValue)
        if let data = try? JSONEncoder().encode(rawValues) {
            userDefaults.set(data, forKey: Keys.metricOrder)
        }
    }
}
