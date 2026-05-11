import Foundation
import OuraKit

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius
    case fahrenheit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .celsius:
            return "Celsius"
        case .fahrenheit:
            return "Fahrenheit"
        }
    }

    var symbol: String {
        switch self {
        case .celsius:
            return "C"
        case .fahrenheit:
            return "F"
        }
    }

    func convertDeviationFromCelsius(_ value: Double) -> Double {
        switch self {
        case .celsius:
            return value
        case .fahrenheit:
            return value * 9.0 / 5.0
        }
    }
}

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

    @Published var temperatureUnit: TemperatureUnit {
        didSet {
            userDefaults.set(temperatureUnit.rawValue, forKey: Keys.temperatureUnit)
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

    var orderedInactiveMetrics: [BarMetric] {
        metricOrder.filter { !enabledMetrics.contains($0) }
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
        let rawTemperatureUnit = userDefaults.string(forKey: Keys.temperatureUnit) ?? TemperatureUnit.celsius.rawValue
        self.temperatureUnit = TemperatureUnit(rawValue: rawTemperatureUnit) ?? .celsius
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

    func moveMetric(_ metric: BarMetric, before targetMetric: BarMetric?, enabled: Bool) {
        guard BarMetric.allCases.contains(metric) else { return }
        if !enabled, enabledMetrics == [metric] {
            return
        }
        if targetMetric == metric, enabledMetrics.contains(metric) == enabled {
            return
        }

        var activeMetrics = orderedEnabledMetrics.filter { $0 != metric }
        var inactiveMetrics = orderedInactiveMetrics.filter { $0 != metric }
        var targetMetrics = enabled ? activeMetrics : inactiveMetrics

        if let targetMetric, let targetIndex = targetMetrics.firstIndex(of: targetMetric) {
            targetMetrics.insert(metric, at: targetIndex)
        } else {
            targetMetrics.append(metric)
        }

        if enabled {
            activeMetrics = targetMetrics
        } else {
            inactiveMetrics = targetMetrics
        }

        metricOrder = Self.repairedMetricOrder(activeMetrics + inactiveMetrics)
        enabledMetrics = Set(activeMetrics)
    }

    private enum Keys {
        static let refreshCadence = "refreshCadence"
        static let selectedMetric = "selectedMetric"
        static let enabledMetrics = "enabledMetrics"
        static let metricOrder = "metricOrder"
        static let temperatureUnit = "temperatureUnit"
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
