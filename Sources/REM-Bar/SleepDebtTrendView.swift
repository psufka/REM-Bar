import Charts
import OuraKit
import SwiftUI

struct SleepDebtTrendPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let minutes: Double
}

struct SleepDebtTrendStats: Equatable {
    let currentMinutes: Double
    let averageMinutes: Double
    let debtFreeDays: Int
    let dataDays: Int
}

enum SleepDebtTrendRange: Int, CaseIterable, Identifiable {
    case seven = 7
    case fourteen = 14
    case thirty = 30
    case ninety = 90

    var id: Int { rawValue }

    var label: String {
        "\(rawValue)d"
    }
}

enum SleepDebtTrendCalculator {
    static let lookbackDays = 14
    static let debtHalfLifeDays = 6.5

    static func points(from sleep: [Sleep], sleepTargetMinutes: Int) -> [SleepDebtTrendPoint] {
        let sleepByDay = Dictionary(grouping: sleep, by: \.day)
        let datedDays = sleepByDay.keys.sorted().compactMap { day -> (day: String, date: Date)? in
            guard let date = dayFormatter.date(from: day) else { return nil }
            return (day, date)
        }

        return datedDays.compactMap { currentDay, currentDate in
            guard DashboardSnapshotBuilder.totalSleepMinutesForDebt(from: sleepByDay[currentDay] ?? []) != nil,
                  let startDate = Calendar.current.date(byAdding: .day, value: -(lookbackDays - 1), to: currentDate)
            else { return nil }

            var debt = 0.0
            var previousDate: Date?
            for (day, date) in datedDays where date >= startDate && date <= currentDate {
                guard let sleepMinutes = DashboardSnapshotBuilder.totalSleepMinutesForDebt(from: sleepByDay[day] ?? []) else { continue }
                if let previousDate {
                    debt *= debtDecay(daysBetween: daysBetween(previousDate, date))
                }
                debt = max(0, debt + Double(sleepTargetMinutes) - sleepMinutes)
                previousDate = date
            }
            return SleepDebtTrendPoint(
                id: currentDay,
                date: currentDate,
                minutes: debt)
        }
    }

    static func points(_ points: [SleepDebtTrendPoint], in range: SleepDebtTrendRange, now: Date = Date()) -> [SleepDebtTrendPoint] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -(range.rawValue - 1), to: startOfToday) else {
            return points
        }
        return points.filter { $0.date >= startDate && $0.date <= startOfToday }.sorted { $0.date < $1.date }
    }

    static func stats(for points: [SleepDebtTrendPoint]) -> SleepDebtTrendStats {
        let total = points.map(\.minutes).reduce(0, +)
        return SleepDebtTrendStats(
            currentMinutes: points.sorted { $0.date < $1.date }.last?.minutes ?? 0,
            averageMinutes: points.isEmpty ? 0 : total / Double(points.count),
            debtFreeDays: points.filter { $0.minutes == 0 }.count,
            dataDays: points.count)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func debtDecay(daysBetween: Int) -> Double {
        pow(0.5, Double(max(0, daysBetween)) / debtHalfLifeDays)
    }

    private static func daysBetween(_ earlier: Date, _ later: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: earlier)
        let end = calendar.startOfDay(for: later)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
}

@MainActor
final class SleepDebtTrendWindowController {
    static let shared = SleepDebtTrendWindowController()

    private var window: NSWindow?

    func show(sleepTarget: SleepTarget) {
        let content = SleepDebtTrendView(sleepTarget: sleepTarget)

        if let window {
            window.contentViewController = NSHostingController(rootView: content)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "Sleep Debt Trend"
        window.contentViewController = NSHostingController(rootView: content)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

struct SleepDebtTrendView: View {
    @ObservedObject private var settings: SettingsStore
    let client: OuraClient

    @State private var selectedRange: SleepDebtTrendRange = .fourteen
    @State private var sleepRecords: [Sleep] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @MainActor
    init(sleepTarget: SleepTarget, client: OuraClient = .live()) {
        self.init(sleepTarget: sleepTarget, client: client, settings: SettingsStore.shared)
    }

    init(sleepTarget _: SleepTarget, client: OuraClient, settings: SettingsStore) {
        self.client = client
        _settings = ObservedObject(wrappedValue: settings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if isLoading {
                ProgressView("Loading sleep debt trend...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Could not load trend",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if displayedPoints.isEmpty {
                ContentUnavailableView(
                    "No sleep debt data",
                    systemImage: "bed.double",
                    description: Text("Oura has not returned sleep details for this range."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                statsGrid
                chart
            }
        }
        .padding(22)
        .frame(minWidth: 680, minHeight: 460)
        .task {
            await loadTrend()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sleep Debt Trend")
                    .font(.title2.weight(.semibold))
                Text("Running \(SleepDebtTrendCalculator.lookbackDays)-day balance; older debt decays.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Range")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Picker("Range", selection: $selectedRange) {
                        ForEach(SleepDebtTrendRange.allCases) { range in
                            Text(range.label).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }

                HStack(spacing: 8) {
                    Text("Sleep goal")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Picker("Sleep goal", selection: $settings.sleepTarget) {
                        ForEach(SleepTarget.allCases) { target in
                            Text(target.label).tag(target)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 112)
                }
            }
        }
    }

    private var statsGrid: some View {
        HStack(spacing: 10) {
            trendStat("Current debt", durationString(stats.currentMinutes))
            trendStat("Avg balance", durationString(stats.averageMinutes))
            trendStat("Debt-free", "\(stats.debtFreeDays)/\(stats.dataDays) nights")
        }
    }

    private func trendStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private var chart: some View {
        Chart {
            ForEach(displayedPoints) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Sleep Debt", point.minutes))
                    .foregroundStyle(color(for: point.minutes))
            }

            RuleMark(y: .value("Goal", 0))
                .foregroundStyle(.green.opacity(0.45))
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text(durationString(minutes))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: selectedRange == .ninety ? 6 : 5)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYScale(domain: 0...chartMaxMinutes)
        .frame(minHeight: 280)
    }

    private var displayedPoints: [SleepDebtTrendPoint] {
        SleepDebtTrendCalculator.points(points, in: selectedRange)
    }

    private var points: [SleepDebtTrendPoint] {
        SleepDebtTrendCalculator.points(from: sleepRecords, sleepTargetMinutes: settings.sleepTarget.minutes)
    }

    private var stats: SleepDebtTrendStats {
        SleepDebtTrendCalculator.stats(for: displayedPoints)
    }

    private var chartMaxMinutes: Double {
        max(60, (displayedPoints.map(\.minutes).max() ?? 60) * 1.15)
    }

    private func loadTrend() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let endDate = localDateString(Date())
        let fetchDays = SleepDebtTrendRange.ninety.rawValue + SleepDebtTrendCalculator.lookbackDays - 1
        let startDate = localDateString(Calendar.current.date(byAdding: .day, value: -(fetchDays - 1), to: Date()) ?? Date())
        do {
            let sleep = try await client.sleep(startDate: startDate, endDate: endDate).data
            sleepRecords = sleep
            selectedRange = .fourteen
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func color(for minutes: Double) -> Color {
        if minutes <= 30 { return .green }
        if minutes <= 90 { return .orange }
        return .red
    }

    private func durationString(_ minutes: Double) -> String {
        BarMetric.sleepDebt.formattedValue(minutes)
    }

    private func localDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
