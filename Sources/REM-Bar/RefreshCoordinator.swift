import Foundation
import OuraKit

@MainActor
final class RefreshCoordinator: ObservableObject {
    @Published private(set) var snapshot: DashboardSnapshot = .empty
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var lastError: String?

    private let settings: SettingsStore
    private let client: OuraClient
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
        refresh()
    }

    private func handleDisplayTick() {
        guard Date() >= nextRefreshAfter else { return }
        refresh()
    }

    func refresh() {
        guard refreshTask == nil else { return }
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
                async let dailySleep = client.dailySleep(startDate: startDate, endDate: endDate)
                async let sleep = client.sleep(startDate: startDate, endDate: endDate)
                async let readiness = client.dailyReadiness(startDate: startDate, endDate: endDate)
                async let activity = client.dailyActivity(startDate: startDate, endDate: endDate)
                async let dailyStress = client.dailyStress(startDate: startDate, endDate: endDate)
                async let dailyResilience = client.dailyResilience(startDate: startDate, endDate: endDate)
                async let dailyCardiovascularAge = client.dailyCardiovascularAge(startDate: startDate, endDate: endDate)
                let snapshot = try await DashboardSnapshotBuilder.make(
                    dailySleep: dailySleep.data,
                    sleep: sleep.data,
                    readiness: readiness.data,
                    activity: activity.data,
                    dailyStress: dailyStress.data,
                    dailyResilience: dailyResilience.data,
                    dailyCardiovascularAge: dailyCardiovascularAge.data,
                    personalInfo: personalInfo)
                await MainActor.run {
                    self.snapshot = snapshot
                    self.lastRefresh = Date()
                    self.lastError = nil
                }
            } catch OuraError.missingToken {
                await MainActor.run {
                    self.lastError = "No Oura token configured."
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                }
            }
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
}
