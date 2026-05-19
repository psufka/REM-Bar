import Foundation
import OuraKit
import OSLog

@MainActor
final class RefreshCoordinator: ObservableObject {
    @Published private(set) var snapshot: DashboardSnapshot = .empty
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var tokenNeedsUpdate = false

    private let settings: SettingsStore
    private let client: OuraClient
    private let cache: OuraDataCache
    private let logger = Logger(subsystem: "com.psufka.REM-Bar", category: "Refresh")
    private lazy var displayLinkDriver = DisplayLinkDriver { [weak self] in
        self?.handleDisplayTick()
    }
    private var refreshTask: Task<Void, Never>?
    private var cachedPersonalInfo: PersonalInfo?
    private var nextRefreshAfter = Date.distantPast

    init(settings: SettingsStore, client: OuraClient = .live(), cache: OuraDataCache = .shared) {
        self.settings = settings
        self.client = client
        self.cache = cache
    }

    func start() {
        displayLinkDriver.start(fps: 1)
        refresh()
    }

    func stop() {
        displayLinkDriver.stop()
        refreshTask?.cancel()
        refreshTask = nil
    }

    func scheduleTimer() {
        nextRefreshAfter = Date().addingTimeInterval(TimeInterval(settings.refreshCadence.rawValue))
    }

    func tokenDidChange() {
        cachedPersonalInfo = nil
        tokenNeedsUpdate = false
        refresh(forceRecentRefresh: true)
    }

    private func handleDisplayTick() {
        guard Date() >= nextRefreshAfter else { return }
        refresh()
    }

    func refresh(forceRecentRefresh: Bool = false) {
        guard refreshTask == nil else { return }
        let enabledMetrics = settings.enabledMetrics
        let averageWindow = settings.averageWindow
        let sleepTarget = settings.sleepTarget
        let sleepAggregationMode = settings.sleepAggregationMode
        nextRefreshAfter = Date().addingTimeInterval(TimeInterval(settings.refreshCadence.rawValue))
        refreshTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.refreshTask = nil
            }
            let endDate = Self.localDateString(Date())
            let requestWindowDays = Self.requestWindowDays(for: enabledMetrics, averageWindow: averageWindow)
            let startDate = Self.localDateString(Calendar.current.date(
                byAdding: .day,
                value: -(requestWindowDays - 1),
                to: Date()) ?? Date())
            let personalInfo = await self.personalInfoForRefresh()
            do {
                async let dailySleep = fetchIfNeeded("daily_sleep", startDate: startDate, endDate: endDate, enabledMetrics: enabledMetrics, requiredMetrics: [.sleepScore, .bestSleepWindow], forceRecentRefresh: forceRecentRefresh) { startDate, endDate in
                    (try await self.client.dailySleep(startDate: startDate, endDate: endDate)).data
                }
                async let sleep = fetchIfNeeded("sleep", startDate: startDate, endDate: endDate, enabledMetrics: enabledMetrics, requiredMetrics: [.rem, .remPercentage, .deepSleep, .deepSleepPercentage, .totalSleep, .sleepDebt, .lightSleep, .lightSleepPercentage, .awakeTime, .timeInBed, .sleepLatency, .averageBreath, .hrv, .rhr, .sleepEfficiency, .bestSleepWindow], forceRecentRefresh: forceRecentRefresh) { startDate, endDate in
                    (try await self.client.sleep(startDate: startDate, endDate: endDate)).data
                }
                async let readiness = fetchIfNeeded("daily_readiness", startDate: startDate, endDate: endDate, enabledMetrics: enabledMetrics, requiredMetrics: [.readiness, .hrvBalance, .sleepBalance, .sleepRegularity, .bodyTemperatureDeviation], forceRecentRefresh: forceRecentRefresh) { startDate, endDate in
                    (try await self.client.dailyReadiness(startDate: startDate, endDate: endDate)).data
                }
                async let activity = fetchIfNeeded("daily_activity", startDate: startDate, endDate: endDate, enabledMetrics: enabledMetrics, requiredMetrics: [.activity], forceRecentRefresh: forceRecentRefresh) { startDate, endDate in
                    (try await self.client.dailyActivity(startDate: startDate, endDate: endDate)).data
                }
                async let dailyStress = fetchIfNeeded("daily_stress", startDate: startDate, endDate: endDate, enabledMetrics: enabledMetrics, requiredMetrics: [.dailyStress], forceRecentRefresh: forceRecentRefresh) { startDate, endDate in
                    (try await self.client.dailyStress(startDate: startDate, endDate: endDate)).data
                }
                async let dailyResilience = fetchIfNeeded("daily_resilience", startDate: startDate, endDate: endDate, enabledMetrics: enabledMetrics, requiredMetrics: [.resilience], forceRecentRefresh: forceRecentRefresh) { startDate, endDate in
                    (try await self.client.dailyResilience(startDate: startDate, endDate: endDate)).data
                }
                async let dailyCardiovascularAge = fetchIfNeeded("daily_cardiovascular_age", startDate: startDate, endDate: endDate, enabledMetrics: enabledMetrics, requiredMetrics: [.cardiovascularAge], forceRecentRefresh: forceRecentRefresh) { startDate, endDate in
                    (try await self.client.dailyCardiovascularAge(startDate: startDate, endDate: endDate)).data
                }
                async let dailySpO2 = fetchIfNeeded("daily_spo2", startDate: startDate, endDate: endDate, enabledMetrics: enabledMetrics, requiredMetrics: [.averageSpO2, .breathingDisturbance], forceRecentRefresh: forceRecentRefresh) { startDate, endDate in
                    (try await self.client.dailySpO2(startDate: startDate, endDate: endDate)).data
                }
                async let vo2Max = fetchIfNeeded("vO2_max", startDate: startDate, endDate: endDate, enabledMetrics: enabledMetrics, requiredMetrics: [.vo2Max], forceRecentRefresh: forceRecentRefresh) { startDate, endDate in
                    (try await self.client.vo2Max(startDate: startDate, endDate: endDate)).data
                }
                async let sleepTime = fetchIfNeeded("sleep_time", startDate: startDate, endDate: endDate, enabledMetrics: enabledMetrics, requiredMetrics: [.optimalBedtime, .sleepTimeRecommendation], forceRecentRefresh: forceRecentRefresh) { startDate, endDate in
                    (try await self.client.sleepTime(startDate: startDate, endDate: endDate)).data
                }
                let dailySleepResult = try await dailySleep
                let sleepResult = try await sleep
                let readinessResult = try await readiness
                let activityResult = try await activity
                let dailyStressResult = try await dailyStress
                let dailyResilienceResult = try await dailyResilience
                let dailyCardiovascularAgeResult = try await dailyCardiovascularAge
                let dailySpO2Result = try await dailySpO2
                let vo2MaxResult = try await vo2Max
                let sleepTimeResult = try await sleepTime
                let failures = [
                    dailySleepResult.failure,
                    sleepResult.failure,
                    readinessResult.failure,
                    activityResult.failure,
                    dailyStressResult.failure,
                    dailyResilienceResult.failure,
                    dailyCardiovascularAgeResult.failure,
                    dailySpO2Result.failure,
                    vo2MaxResult.failure,
                    sleepTimeResult.failure,
                ].compactMap { $0 }
                let snapshot = DashboardSnapshotBuilder.make(
                    dailySleep: dailySleepResult.data,
                    sleep: sleepResult.data,
                    readiness: readinessResult.data,
                    activity: activityResult.data,
                    dailyStress: dailyStressResult.data,
                    dailyResilience: dailyResilienceResult.data,
                    dailyCardiovascularAge: dailyCardiovascularAgeResult.data,
                    dailySpO2: dailySpO2Result.data,
                    vo2Max: vo2MaxResult.data,
                    sleepTime: sleepTimeResult.data,
                    personalInfo: personalInfo,
                    sleepTargetMinutes: sleepTarget.minutes,
                    sleepAggregationMode: sleepAggregationMode,
                    enabledMetrics: enabledMetrics,
                    displayWindowDays: averageWindow.dayCount)
                await MainActor.run {
                    self.snapshot = snapshot
                    self.settings.noteMetricAvailability(from: snapshot)
                    self.lastRefresh = Date()
                    self.lastError = Self.partialFailureMessage(for: failures)
                    self.tokenNeedsUpdate = false
                }
            } catch OuraError.missingToken {
                await MainActor.run {
                    self.lastError = "No Oura token configured."
                    self.tokenNeedsUpdate = false
                }
            } catch OuraError.invalidToken {
                await MainActor.run {
                    self.lastError = "Oura token is invalid. Open Settings to update it."
                    self.tokenNeedsUpdate = true
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.tokenNeedsUpdate = false
                }
            }
        }
    }

    private static func requestWindowDays(
        for enabledMetrics: Set<BarMetric>,
        averageWindow: SettingsStore.AverageWindow)
        -> Int
    {
        var dayCount = averageWindow.dayCount
        if enabledMetrics.contains(.sleepDebt) {
            dayCount = max(dayCount, SleepDebtTrendCalculator.lookbackDays)
        }
        return dayCount
    }

    private func fetchIfNeeded<Element>(
        _ endpointName: String,
        startDate: String,
        endDate: String,
        enabledMetrics: Set<BarMetric>,
        requiredMetrics: Set<BarMetric>,
        forceRecentRefresh: Bool,
        operation: (String, String) async throws -> [Element])
        async throws -> EndpointFetch<Element>
        where Element: OuraCacheRecord
    {
        guard enabledMetrics.containsAny(requiredMetrics) else {
            logger.debug("Skipping \(endpointName, privacy: .public) fetch because dependent metrics are disabled.")
            return EndpointFetch(data: [])
        }
        do {
            let data = try await cache.values(
                endpoint: endpointName,
                startDate: startDate,
                endDate: endDate,
                forceRecentRefresh: forceRecentRefresh,
                fetch: operation)
            return EndpointFetch(data: data)
        } catch OuraError.missingToken {
            throw OuraError.missingToken
        } catch OuraError.invalidToken {
            throw OuraError.invalidToken
        } catch {
            return EndpointFetch(data: [], failure: EndpointFailure(endpointName: endpointName, error: error))
        }
    }

    private func personalInfoForRefresh() async -> PersonalInfo? {
        if let cachedPersonalInfo {
            return cachedPersonalInfo
        }
        guard let personalInfo = try? await client.personalInfo() else {
            return nil
        }
        cachedPersonalInfo = personalInfo
        return personalInfo
    }

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func localDateString(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private static func partialFailureMessage(for failures: [EndpointFailure]) -> String? {
        guard !failures.isEmpty else { return nil }
        let unavailable = failures.filter(\.isUnavailable)
        if unavailable.count == failures.count {
            return "\(failures.count) endpoint\(failures.count == 1 ? "" : "s") not available on your ring."
        }
        let names = failures.map(\.endpointName).joined(separator: ", ")
        return "\(failures.count) endpoint\(failures.count == 1 ? "" : "s") unavailable: \(names)."
    }
}

private extension Set where Element == BarMetric {
    func containsAny(_ metrics: Set<BarMetric>) -> Bool {
        !isDisjoint(with: metrics)
    }
}

private struct EndpointFetch<Element: Codable & Equatable & Sendable> {
    let data: [Element]
    let failure: EndpointFailure?

    init(data: [Element], failure: EndpointFailure? = nil) {
        self.data = data
        self.failure = failure
    }
}

private struct EndpointFailure {
    let endpointName: String
    let error: Error

    var isUnavailable: Bool {
        if case let OuraError.badStatus(status, _) = error {
            return status == 403 || status == 404
        }
        return false
    }
}
