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

enum IconStyle: String, CaseIterable, Identifiable {
    case color
    case monochrome

    var id: String { rawValue }
}

enum SleepTarget: Int, CaseIterable, Identifiable {
    case six = 360
    case sixFifteen = 375
    case sixThirty = 390
    case sixFortyFive = 405
    case seven = 420
    case sevenFifteen = 435
    case sevenThirty = 450
    case sevenFortyFive = 465
    case eight = 480
    case eightFifteen = 495
    case eightThirty = 510
    case eightFortyFive = 525
    case nine = 540
    case nineFifteen = 555
    case nineThirty = 570
    case nineFortyFive = 585
    case ten = 600

    var id: Int { rawValue }
    var minutes: Int { rawValue }

    var label: String {
        let hours = rawValue / 60
        let minutes = rawValue % 60
        return "\(hours):\(String(format: "%02d", minutes))"
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

    enum AverageWindow: Int, CaseIterable, Identifiable {
        case three = 3
        case seven = 7
        case fourteen = 14
        case thirty = 30

        var id: Int { rawValue }
        var dayCount: Int { rawValue }

        var label: String {
            switch self {
            case .three:
                return "3 days"
            case .seven:
                return "7 days"
            case .fourteen:
                return "14 days"
            case .thirty:
                return "30 days"
            }
        }

        var averageLabel: String {
            "\(dayCount)-day avg"
        }
    }

    @Published var refreshCadence: RefreshCadence {
        didSet {
            userDefaults.set(refreshCadence.rawValue, forKey: Keys.refreshCadence)
        }
    }

    @Published var averageWindow: AverageWindow {
        didSet {
            userDefaults.set(averageWindow.rawValue, forKey: Keys.averageWindow)
        }
    }

    @Published var temperatureUnit: TemperatureUnit {
        didSet {
            userDefaults.set(temperatureUnit.rawValue, forKey: Keys.temperatureUnit)
        }
    }

    @Published var iconStyle: IconStyle {
        didSet {
            userDefaults.set(iconStyle.rawValue, forKey: Keys.iconStyle)
        }
    }

    @Published var sleepTarget: SleepTarget {
        didSet {
            userDefaults.set(sleepTarget.rawValue, forKey: Keys.sleepTarget)
        }
    }

    @Published var selectedMetric: BarMetric? {
        didSet {
            guard let selectedMetric else {
                userDefaults.set(Self.iconOnlyMenuBarMetricRawValue, forKey: Keys.selectedMetric)
                return
            }
            guard enabledMetrics.contains(selectedMetric) else {
                self.selectedMetric = orderedEnabledMetrics.first ?? .sleepScore
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
            if let selectedMetric, !enabledMetrics.contains(selectedMetric) {
                self.selectedMetric = orderedEnabledMetrics.first ?? .sleepScore
            }
        }
    }

    @Published private(set) var knownUnavailableMetrics: Set<BarMetric> {
        didSet {
            saveKnownUnavailableMetrics()
        }
    }

    @Published private(set) var thresholdOverrides: [BarMetric: MetricThresholdOverride] {
        didSet {
            saveThresholdOverrides()
        }
    }

    @Published private(set) var hasCompletedOnboarding: Bool {
        didSet {
            userDefaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        }
    }

    var orderedEnabledMetrics: [BarMetric] {
        metricOrder.filter { enabledMetrics.contains($0) }
    }

    var orderedInactiveMetrics: [BarMetric] {
        metricOrder.filter { !enabledMetrics.contains($0) }
    }

    var orderedAvailableEnabledMetrics: [BarMetric] {
        metricOrder.filter { enabledMetrics.contains($0) && !knownUnavailableMetrics.contains($0) }
    }

    var orderedAvailableInactiveMetrics: [BarMetric] {
        metricOrder.filter { !enabledMetrics.contains($0) && !knownUnavailableMetrics.contains($0) }
    }

    var orderedUnavailableMetrics: [BarMetric] {
        metricOrder.filter { knownUnavailableMetrics.contains($0) }
    }

    var needsOnboarding: Bool {
        !hasCompletedOnboarding
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let metricOrder = Self.loadMetricOrder(from: userDefaults)
        self.metricOrder = metricOrder
        let enabledMetrics = Self.loadEnabledMetrics(from: userDefaults)
        self.enabledMetrics = enabledMetrics
        self.knownUnavailableMetrics = Self.loadKnownUnavailableMetrics(from: userDefaults)
        self.thresholdOverrides = Self.loadThresholdOverrides(from: userDefaults)
        if userDefaults.object(forKey: Keys.hasCompletedOnboarding) == nil {
            self.hasCompletedOnboarding = Self.hasExistingConfiguration(in: userDefaults)
        } else {
            self.hasCompletedOnboarding = userDefaults.bool(forKey: Keys.hasCompletedOnboarding)
        }
        let rawCadence = userDefaults.integer(forKey: Keys.refreshCadence)
        self.refreshCadence = RefreshCadence(rawValue: rawCadence) ?? .five
        let rawAverageWindow = userDefaults.integer(forKey: Keys.averageWindow)
        self.averageWindow = AverageWindow(rawValue: rawAverageWindow) ?? .seven
        let rawTemperatureUnit = userDefaults.string(forKey: Keys.temperatureUnit) ?? TemperatureUnit.celsius.rawValue
        self.temperatureUnit = TemperatureUnit(rawValue: rawTemperatureUnit) ?? .celsius
        let rawIconStyle = userDefaults.string(forKey: Keys.iconStyle) ?? IconStyle.color.rawValue
        self.iconStyle = IconStyle(rawValue: rawIconStyle) ?? .color
        let rawSleepTarget = userDefaults.integer(forKey: Keys.sleepTarget)
        self.sleepTarget = SleepTarget(rawValue: rawSleepTarget) ?? .eight
        let rawMetric = userDefaults.string(forKey: Keys.selectedMetric) ?? BarMetric.sleepScore.rawValue
        if rawMetric == Self.iconOnlyMenuBarMetricRawValue {
            self.selectedMetric = nil
        } else {
            let selectedMetric = BarMetric(rawValue: rawMetric) ?? .sleepScore
            self.selectedMetric = enabledMetrics.contains(selectedMetric)
                ? selectedMetric
                : Self.orderedMetrics(in: enabledMetrics, metricOrder: metricOrder).first ?? .sleepScore
        }
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

    func applyPreset(_ preset: MetricPreset) {
        let metrics = preset.metrics
        metricOrder = Self.repairedMetricOrder(metrics + metricOrder.filter { !metrics.contains($0) })
        enabledMetrics = Set(metrics)
        if let selectedMetric, !enabledMetrics.contains(selectedMetric) {
            self.selectedMetric = metrics.first
        } else if selectedMetric == nil {
            self.selectedMetric = nil
        } else {
            self.selectedMetric = selectedMetric ?? metrics.first
        }
    }

    func threshold(for metric: BarMetric) -> MetricThresholdOverride? {
        thresholdOverrides[metric] ?? metric.defaultThresholdOverride
    }

    func setThreshold(_ threshold: MetricThresholdOverride, for metric: BarMetric) {
        guard metric.defaultThresholdOverride != nil else { return }
        thresholdOverrides[metric] = sanitizedThreshold(threshold)
    }

    func resetThreshold(for metric: BarMetric) {
        thresholdOverrides.removeValue(forKey: metric)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func noteMetricAvailability(from snapshot: DashboardSnapshot) {
        var updated = knownUnavailableMetrics
        for (metric, series) in snapshot.metrics {
            if series.availabilityMessage == nil {
                updated.remove(metric)
            } else {
                updated.insert(metric)
            }
        }
        knownUnavailableMetrics = updated
        if let selectedMetric, knownUnavailableMetrics.contains(selectedMetric) {
            self.selectedMetric = orderedAvailableEnabledMetrics.first
        }
    }

    private enum Keys {
        static let refreshCadence = "refreshCadence"
        static let averageWindow = "averageWindow"
        static let selectedMetric = "selectedMetric"
        static let enabledMetrics = "enabledMetrics"
        static let metricOrder = "metricOrder"
        static let temperatureUnit = "temperatureUnit"
        static let iconStyle = "iconStyle"
        static let sleepTarget = "sleepTarget"
        static let knownUnavailableMetrics = "knownUnavailableMetrics"
        static let thresholdOverrides = "thresholdOverrides"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    static let defaultEnabledMetrics: Set<BarMetric> = [
        .sleepScore,
        .readiness,
        .hrv,
        .totalSleep,
        .deepSleep,
        .rem,
        .cardiovascularAge,
        .rhr,
        .hrvBalance,
        .bodyTemperatureDeviation,
        .vo2Max,
        .sleepDebt,
    ]

    static let defaultMetricOrder: [BarMetric] = [
        .sleepScore,
        .readiness,
        .hrv,
        .totalSleep,
        .deepSleep,
        .rem,
        .cardiovascularAge,
        .rhr,
        .hrvBalance,
        .bodyTemperatureDeviation,
        .vo2Max,
        .sleepDebt,
    ]

    static let iconOnlyMenuBarMetricRawValue = "__iconOnly"

    private static func orderedMetrics(in metrics: Set<BarMetric>, metricOrder: [BarMetric]) -> [BarMetric] {
        metricOrder.filter { metrics.contains($0) }
    }

    private static func loadMetricOrder(from userDefaults: UserDefaults) -> [BarMetric] {
        guard let data = userDefaults.data(forKey: Keys.metricOrder),
              let rawValues = try? JSONDecoder().decode([String].self, from: data)
        else {
            return repairedMetricOrder(defaultMetricOrder)
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

    private static func loadKnownUnavailableMetrics(from userDefaults: UserDefaults) -> Set<BarMetric> {
        guard let data = userDefaults.data(forKey: Keys.knownUnavailableMetrics),
              let rawValues = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }
        return Set(rawValues.compactMap(BarMetric.init(rawValue:)))
    }

    private static func loadThresholdOverrides(from userDefaults: UserDefaults) -> [BarMetric: MetricThresholdOverride] {
        guard let data = userDefaults.data(forKey: Keys.thresholdOverrides),
              let rawValues = try? JSONDecoder().decode([String: MetricThresholdOverride].self, from: data)
        else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: rawValues.compactMap { rawMetric, threshold in
            guard let metric = BarMetric(rawValue: rawMetric), metric.defaultThresholdOverride != nil else { return nil }
            return (metric, sanitizedThreshold(threshold))
        })
    }

    private static func hasExistingConfiguration(in userDefaults: UserDefaults) -> Bool {
        [
            Keys.refreshCadence,
            Keys.averageWindow,
            Keys.selectedMetric,
            Keys.enabledMetrics,
            Keys.metricOrder,
            Keys.temperatureUnit,
            Keys.iconStyle,
            Keys.sleepTarget,
            Keys.knownUnavailableMetrics,
        ].contains { userDefaults.object(forKey: $0) != nil }
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

    private func saveKnownUnavailableMetrics() {
        let rawValues = metricOrder
            .filter { knownUnavailableMetrics.contains($0) }
            .map(\.rawValue)
        if let data = try? JSONEncoder().encode(rawValues) {
            userDefaults.set(data, forKey: Keys.knownUnavailableMetrics)
        }
    }

    private func saveThresholdOverrides() {
        let rawValues = Dictionary(uniqueKeysWithValues: thresholdOverrides.map { metric, threshold in
            (metric.rawValue, threshold)
        })
        if let data = try? JSONEncoder().encode(rawValues) {
            userDefaults.set(data, forKey: Keys.thresholdOverrides)
        }
    }

    private static func sanitizedThreshold(_ threshold: MetricThresholdOverride) -> MetricThresholdOverride {
        var threshold = threshold
        switch threshold.direction {
        case .higherIsBetter:
            if threshold.green < threshold.orange {
                swap(&threshold.green, &threshold.orange)
            }
        case .lowerIsBetter, .closerToZeroIsBetter:
            if threshold.green > threshold.orange {
                swap(&threshold.green, &threshold.orange)
            }
        }
        return threshold
    }

    private func sanitizedThreshold(_ threshold: MetricThresholdOverride) -> MetricThresholdOverride {
        Self.sanitizedThreshold(threshold)
    }
}
