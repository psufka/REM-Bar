import Foundation
import OuraKit

@MainActor
final class RefreshCoordinator: ObservableObject {
    @Published private(set) var sleepScore: Int? = 87
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var lastError: String?

    private let settings: SettingsStore
    private let client: OuraClient
    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?

    init(settings: SettingsStore, client: OuraClient = .live()) {
        self.settings = settings
        self.client = client
    }

    func start() {
        scheduleTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        refreshTask?.cancel()
        refreshTask = nil
    }

    func scheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(settings.refreshCadence.rawValue)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            let today = Self.localDateString(Date())
            do {
                let collection = try await client.dailySleep(startDate: today, endDate: today)
                await MainActor.run {
                    self.sleepScore = collection.data.first?.score ?? self.sleepScore
                    self.lastRefresh = Date()
                    self.lastError = nil
                }
            } catch OuraError.missingToken {
                await MainActor.run {
                    self.sleepScore = 87
                    self.lastError = "No Oura token configured."
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    static func localDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
