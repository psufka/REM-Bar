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
    private let logger = Logger(subsystem: "com.psufka.REM-Bar", category: "Refresh")
    private lazy var displayLinkDriver = DisplayLinkDriver { [weak self] in
        self?.handleDisplayTick()
    }
    private var refreshTask: Task<Void, Never>?
    private var cachedPersonalInfo: PersonalInfo?
    private var nextRefreshAfter = Date.distantPast

    init(settings: SettingsStore, client: OuraClient = .live()) {
        self.settings = settings
        self.client = client
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
        refresh()
    }

    private func handleDisplayTick() {
        guard Date() >= nextRefreshAfter else { return }
        refresh()
    }

    func refresh() {
        guard refreshTask == nil else { return }
        let enabledMetrics = settings.enabledMetrics
        nextRefreshAfter = Date().addingTimeInterval(TimeInterval(settings.refreshCadence.rawValue))
        refreshTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.refreshTask = nil
            }
            let endDate = Self.localDateString(Date())
            let startDate = Self.localDateString(Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date())
            let personalInfo = await self.personalInfoForRefresh()
            do {
                async let dailySleep = fetchIfNeeded("daily_sleep", enabledMetrics: enabledMetrics, requiredMetrics: [.sleepScore]) {
                    (try await self.client.dailySleep(startDate: startDate, endDate: endDate)).data
                }
                async let sleep = fetchIfNeeded("sleep", enabledMetrics: enabledMetrics, requiredMetrics: [.rem, .deepSleep, .totalSleep, .hrv, .rhr, .sleepEfficiency]) {
                    (try await self.client.sleep(startDate: startDate, endDate: endDate)).data
                }
                async let readiness = fetchIfNeeded("daily_readiness", enabledMetrics: enabledMetrics, requiredMetrics: [.readiness, .bodyTemperatureDeviation]) {
                    (try await self.client.dailyReadiness(startDate: startDate, endDate: endDate)).data
                }
                async let activity = fetchIfNeeded("daily_activity", enabledMetrics: enabledMetrics, requiredMetrics: [.activity]) {
                    (try await self.client.dailyActivity(startDate: startDate, endDate: endDate)).data
                }
                async let dailyStress = fetchIfNeeded("daily_stress", enabledMetrics: enabledMetrics, requiredMetrics: [.dailyStress]) {
                    (try await self.client.dailyStress(startDate: startDate, endDate: endDate)).data
                }
                async let dailyResilience = fetchIfNeeded("daily_resilience", enabledMetrics: enabledMetrics, requiredMetrics: [.resilience]) {
                    (try await self.client.dailyResilience(startDate: startDate, endDate: endDate)).data
                }
                async let dailyCardiovascularAge = fetchIfNeeded("daily_cardiovascular_age", enabledMetrics: enabledMetrics, requiredMetrics: [.cardiovascularAge]) {
                    (try await self.client.dailyCardiovascularAge(startDate: startDate, endDate: endDate)).data
                }
                let dailySleepResult = try await dailySleep
                let sleepResult = try await sleep
                let readinessResult = try await readiness
                let activityResult = try await activity
                let dailyStressResult = try await dailyStress
                let dailyResilienceResult = try await dailyResilience
                let dailyCardiovascularAgeResult = try await dailyCardiovascularAge
                let failures = [
                    dailySleepResult.failure,
                    sleepResult.failure,
                    readinessResult.failure,
                    activityResult.failure,
                    dailyStressResult.failure,
                    dailyResilienceResult.failure,
                    dailyCardiovascularAgeResult.failure,
                ].compactMap { $0 }
                let snapshot = DashboardSnapshotBuilder.make(
                    dailySleep: dailySleepResult.data,
                    sleep: sleepResult.data,
                    readiness: readinessResult.data,
                    activity: activityResult.data,
                    dailyStress: dailyStressResult.data,
                    dailyResilience: dailyResilienceResult.data,
                    dailyCardiovascularAge: dailyCardiovascularAgeResult.data,
                    personalInfo: personalInfo,
                    enabledMetrics: enabledMetrics)
                await MainActor.run {
                    self.snapshot = snapshot
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

    private func fetchIfNeeded<Element>(
        _ endpointName: String,
        enabledMetrics: Set<BarMetric>,
        requiredMetrics: Set<BarMetric>,
        operation: () async throws -> [Element])
        async throws -> EndpointFetch<Element>
        where Element: Codable & Equatable & Sendable
    {
        guard enabledMetrics.containsAny(requiredMetrics) else {
            logger.debug("Skipping \(endpointName, privacy: .public) fetch because dependent metrics are disabled.")
            return EndpointFetch(data: [])
        }
        do {
            return EndpointFetch(data: try await operation())
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
