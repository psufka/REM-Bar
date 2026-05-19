import Charts
import OuraKit
import SwiftUI

struct MetricTrendStats: Equatable {
    let current: Double
    let average: Double
    let low: Double
    let high: Double
    let dataDays: Int
}

@MainActor
final class MetricTrendWindowController {
    static let shared = MetricTrendWindowController()

    private let autosaveName = "metric-trend"
    private var window: NSWindow?

    func show(metric: BarMetric) {
        let content = MetricTrendView(metric: metric)

        if let window {
            window.title = "\(metric.label) Trend"
            window.contentViewController = NSHostingController(rootView: content)
            TrendWindowPlacement.bringToFront(window)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "\(metric.label) Trend"
        window.contentViewController = NSHostingController(rootView: content)
        window.isReleasedWhenClosed = false
        TrendWindowPlacement.configure(window, autosaveName: autosaveName)
        TrendWindowPlacement.bringToFront(window)
        self.window = window
    }
}

struct MetricTrendView: View {
    let metric: BarMetric
    let client: OuraClient

    @ObservedObject private var settings: SettingsStore
    @State private var selectedRange: SleepDebtTrendRange = .fourteen
    @State private var series: MetricSeries?
    @State private var hoveredPoint: MetricPoint?
    @State private var bestSleepRecords: [Sleep] = []
    @State private var bestSleepDailyScores: [DailySleep] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @MainActor
    init(metric: BarMetric, client: OuraClient = .live()) {
        self.init(metric: metric, client: client, settings: SettingsStore.shared)
    }

    init(metric: BarMetric, client: OuraClient, settings: SettingsStore) {
        self.metric = metric
        self.client = client
        _settings = ObservedObject(wrappedValue: settings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if isLoading {
                ProgressView("Loading \(metric.label.lowercased()) trend...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Could not load trend",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let availabilityMessage = series?.availabilityMessage {
                ContentUnavailableView(
                    metric.label,
                    systemImage: metric.symbolName,
                    description: Text(availabilityMessage))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if metric == .bestSleepWindow {
                if displayedBestSleepBuckets.isEmpty {
                    ContentUnavailableView(
                        "No sleep window data",
                        systemImage: metric.symbolName,
                        description: Text("Oura has not returned enough sleep scores and bedtime starts for this range."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    bestSleepStatsGrid
                    bestSleepWindowChart
                }
            } else if displayedPoints.isEmpty {
                ContentUnavailableView(
                    "No trend data",
                    systemImage: metric.symbolName,
                    description: Text("Oura has not returned enough \(metric.label.lowercased()) data for this range."))
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
                Label(metric.label, systemImage: metric.symbolName)
                    .font(.title2.weight(.semibold))
                Text(metric.explanation.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
                .frame(width: 360)
            }
        }
    }

    private var statsGrid: some View {
        HStack(spacing: 10) {
            trendStat("Current", format(stats.current))
            trendStat("Avg", format(stats.average))
            trendStat("Range", "\(format(stats.low)) - \(format(stats.high))")
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
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private var bestSleepStatsGrid: some View {
        HStack(spacing: 10) {
            trendStat("Best window", bestSleepBestBucket?.label ?? "?")
            trendStat("Avg Sleep Score", bestSleepBestBucket.map { "\(Int($0.averageScore.rounded()))" } ?? "?")
            trendStat("Nights", bestSleepBestBucket.map { "\($0.nights)" } ?? "0")
        }
    }

    private var chart: some View {
        Chart {
            ForEach(displayedPoints) { point in
                LineMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value(metric.label, point.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentColor)

                PointMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value(metric.label, point.value))
                    .foregroundStyle(color(for: point.value))
            }

            if let hoveredPoint {
                RuleMark(x: .value("Selected Day", hoveredPoint.date, unit: .day))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .center, spacing: 6) {
                        hoverAnnotation(for: hoveredPoint)
                    }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let value = value.as(Double.self) {
                        Text(format(value))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: selectedRange.rawValue >= 90 ? 6 : 5)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYScale(domain: chartYDomain)
        .chartXScale(domain: chartXDomain)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        updateHoveredPoint(phase: phase, proxy: proxy, geometry: geometry)
                    }
            }
        }
        .frame(minHeight: 280)
    }

    private var bestSleepWindowChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                Chart {
                    ForEach(displayedBestSleepBuckets) { bucket in
                        BarMark(
                            x: .value("Window", bucket.displayOrder),
                            yStart: .value("Axis Label Clearance", bestSleepBarBaseline),
                            yEnd: .value("Avg Sleep Score", bucket.averageScore),
                            width: .fixed(30))
                            .foregroundStyle(Color(nsColor: ColorThresholds.color(for: bucket.averageScore, metric: .sleepScore)))
                            .annotation(position: .top, alignment: .center, spacing: 2) {
                                Text("\(Int(bucket.averageScore.rounded()))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let score = value.as(Double.self) {
                                Text("\(Int(score.rounded()))")
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: displayedBestSleepBuckets.map { Double($0.displayOrder) }) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(anchor: .top) {
                            if let order = value.as(Double.self),
                               let bucket = bestSleepBucket(displayOrder: order)
                            {
                                Text(compactWindowLabel(for: bucket))
                                    .font(.caption2)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .chartYScale(domain: bestSleepYDomain)
                .chartXScale(domain: bestSleepXDomain)
                .chartPlotStyle { plotArea in
                    plotArea
                        .padding(.bottom, 24)
                }
                .frame(width: bestSleepChartWidth, height: 300)
            }
        }
    }

    private var displayedPoints: [MetricPoint] {
        guard let series else { return [] }
        let sleepDebtPoints = series.points.map {
            SleepDebtTrendPoint(id: $0.id, date: $0.date, minutes: $0.value)
        }
        let dates = Set(SleepDebtTrendCalculator.points(sleepDebtPoints, in: selectedRange).map(\.id))
        return series.points.filter { dates.contains($0.id) }.sorted { $0.date < $1.date }
    }

    private var displayedBestSleepBuckets: [BestSleepWindowBucket] {
        BestSleepWindowCalculator.buckets(
            sleep: bestSleepRecords,
            dailySleep: bestSleepDailyScores,
            range: selectedRange)
    }

    private var bestSleepBestBucket: BestSleepWindowBucket? {
        displayedBestSleepBuckets.max {
            if $0.averageScore == $1.averageScore {
                return $0.nights < $1.nights
            }
            return $0.averageScore < $1.averageScore
        }
    }

    private var stats: MetricTrendStats {
        let values = displayedPoints.map(\.value)
        return MetricTrendStats(
            current: displayedPoints.last?.value ?? 0,
            average: values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count),
            low: values.min() ?? 0,
            high: values.max() ?? 0,
            dataDays: values.count)
    }

    private var chartYDomain: ClosedRange<Double> {
        let values = displayedPoints.map(\.value)
        guard let low = values.min(), let high = values.max() else {
            return 0...1
        }
        if low == high {
            return (low - 1)...(high + 1)
        }
        let padding = max((high - low) * 0.18, 1)
        return (low - padding)...(high + padding)
    }

    private var chartXDomain: ClosedRange<Date> {
        guard let first = displayedPoints.first?.date,
              let last = displayedPoints.last?.date
        else {
            let now = Date()
            return now...now
        }
        let rightEdge = Calendar.current.date(byAdding: .hour, value: 30, to: last) ?? last
        return first...rightEdge
    }

    private var bestSleepYDomain: ClosedRange<Double> {
        let values = displayedBestSleepBuckets.map(\.averageScore)
        guard let low = values.min(), let high = values.max() else {
            return 0...100
        }
        return max(0, low - 5)...min(100, high + 5)
    }

    private var bestSleepXDomain: ClosedRange<Double> {
        guard let first = displayedBestSleepBuckets.first?.displayOrder,
              let last = displayedBestSleepBuckets.last?.displayOrder
        else {
            return 0...1
        }
        return Double(first - 30)...Double(last + 30)
    }

    private var bestSleepBarBaseline: Double {
        let range = bestSleepYDomain.upperBound - bestSleepYDomain.lowerBound
        return bestSleepYDomain.lowerBound + max(range * 0.08, 1.5)
    }

    private var bestSleepChartWidth: CGFloat {
        max(640, CGFloat(displayedBestSleepBuckets.count) * 62)
    }

    private func hoverAnnotation(for point: MetricPoint) -> some View {
        VStack(spacing: 1) {
            Text(shortDateString(point.date))
            Text(format(point.value))
                .monospacedDigit()
        }
        .font(.caption.weight(.semibold))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func updateHoveredPoint(phase: HoverPhase, proxy: ChartProxy, geometry: GeometryProxy) {
        guard case let .active(location) = phase,
              let plotFrame = proxy.plotFrame
        else {
            hoveredPoint = nil
            return
        }

        let frame = geometry[plotFrame]
        guard frame.contains(location) else {
            hoveredPoint = nil
            return
        }

        let x = location.x - frame.origin.x
        guard let date: Date = proxy.value(atX: x) else {
            hoveredPoint = nil
            return
        }

        hoveredPoint = nearestPoint(to: date)
    }

    private func bestSleepBucket(displayOrder: Double) -> BestSleepWindowBucket? {
        let roundedOrder = Int(displayOrder.rounded())
        return displayedBestSleepBuckets.first { $0.displayOrder == roundedOrder }
    }

    private func compactWindowLabel(for bucket: BestSleepWindowBucket) -> String {
        "\(compactClockMinute(bucket.startMinute))-\(compactClockMinute((bucket.startMinute + 30) % (24 * 60)))"
    }

    private func compactClockMinute(_ minuteOfDay: Int) -> String {
        let hour24 = minuteOfDay / 60
        let minute = minuteOfDay % 60
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        let suffix = hour24 < 12 ? "a" : "p"
        if minute == 0 {
            return "\(hour12)\(suffix)"
        }
        return "\(hour12):\(String(format: "%02d", minute))\(suffix)"
    }

    private func nearestPoint(to date: Date) -> MetricPoint? {
        displayedPoints.min { first, second in
            abs(first.date.timeIntervalSince(date)) < abs(second.date.timeIntervalSince(date))
        }
    }

    private func loadTrend() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let endDate = localDateString(Date())
        let startDate = localDateString(Calendar.current.date(
            byAdding: .day,
            value: -(SleepDebtTrendRange.maximumDayCount - 1),
            to: Date()) ?? Date())

        do {
            if metric == .bestSleepWindow {
                try await loadBestSleepWindowTrend(startDate: startDate, endDate: endDate)
            } else {
                series = try await fetchSeries(startDate: startDate, endDate: endDate)
            }
            selectedRange = .fourteen
        } catch OuraError.badStatus(403, _), OuraError.badStatus(404, _) {
            series = MetricSeries(metric: metric, points: [], availabilityMessage: "Not available on your ring")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadBestSleepWindowTrend(startDate: String, endDate: String) async throws {
        async let sleep = OuraDataCache.shared.values(endpoint: "sleep", startDate: startDate, endDate: endDate) { startDate, endDate in
            try await client.sleep(startDate: startDate, endDate: endDate).data
        }
        async let dailySleep = OuraDataCache.shared.values(endpoint: "daily_sleep", startDate: startDate, endDate: endDate) { startDate, endDate in
            try await client.dailySleep(startDate: startDate, endDate: endDate).data
        }
        bestSleepRecords = try await sleep
        bestSleepDailyScores = try await dailySleep
        series = MetricSeries(metric: metric, points: [])
    }

    private func fetchSeries(startDate: String, endDate: String) async throws -> MetricSeries {
        let enabledMetrics: Set<BarMetric> = [metric]
        let snapshot: DashboardSnapshot
        switch metric {
        case .sleepScore:
            let dailySleep = try await OuraDataCache.shared.values(endpoint: "daily_sleep", startDate: startDate, endDate: endDate) { startDate, endDate in
                try await client.dailySleep(startDate: startDate, endDate: endDate).data
            }
            snapshot = DashboardSnapshotBuilder.make(
                dailySleep: dailySleep,
                sleep: [],
                readiness: [],
                activity: [],
                enabledMetrics: enabledMetrics)
        case .rem, .remPercentage, .deepSleep, .deepSleepPercentage, .totalSleep, .lightSleep, .lightSleepPercentage, .awakeTime, .timeInBed, .sleepLatency, .averageBreath, .hrv, .rhr, .sleepEfficiency:
            let sleep = try await OuraDataCache.shared.values(endpoint: "sleep", startDate: startDate, endDate: endDate) { startDate, endDate in
                try await client.sleep(startDate: startDate, endDate: endDate).data
            }
            snapshot = DashboardSnapshotBuilder.make(
                dailySleep: [],
                sleep: sleep,
                readiness: [],
                activity: [],
                sleepAggregationMode: settings.sleepAggregationMode,
                enabledMetrics: enabledMetrics)
        case .readiness, .hrvBalance, .sleepBalance, .sleepRegularity, .bodyTemperatureDeviation:
            let readiness = try await OuraDataCache.shared.values(endpoint: "daily_readiness", startDate: startDate, endDate: endDate) { startDate, endDate in
                try await client.dailyReadiness(startDate: startDate, endDate: endDate).data
            }
            snapshot = DashboardSnapshotBuilder.make(
                dailySleep: [],
                sleep: [],
                readiness: readiness,
                activity: [],
                enabledMetrics: enabledMetrics)
        case .activity:
            let activity = try await OuraDataCache.shared.values(endpoint: "daily_activity", startDate: startDate, endDate: endDate) { startDate, endDate in
                try await client.dailyActivity(startDate: startDate, endDate: endDate).data
            }
            snapshot = DashboardSnapshotBuilder.make(
                dailySleep: [],
                sleep: [],
                readiness: [],
                activity: activity,
                enabledMetrics: enabledMetrics)
        case .cardiovascularAge:
            async let cardiovascularAge = OuraDataCache.shared.values(endpoint: "daily_cardiovascular_age", startDate: startDate, endDate: endDate) { startDate, endDate in
                try await client.dailyCardiovascularAge(startDate: startDate, endDate: endDate).data
            }
            async let personalInfo = try? client.personalInfo()
            snapshot = DashboardSnapshotBuilder.make(
                dailySleep: [],
                sleep: [],
                readiness: [],
                activity: [],
                dailyCardiovascularAge: try await cardiovascularAge,
                personalInfo: await personalInfo,
                enabledMetrics: enabledMetrics)
        case .averageSpO2, .breathingDisturbance:
            let dailySpO2 = try await OuraDataCache.shared.values(endpoint: "daily_spo2", startDate: startDate, endDate: endDate) { startDate, endDate in
                try await client.dailySpO2(startDate: startDate, endDate: endDate).data
            }
            snapshot = DashboardSnapshotBuilder.make(
                dailySleep: [],
                sleep: [],
                readiness: [],
                activity: [],
                dailySpO2: dailySpO2,
                enabledMetrics: enabledMetrics)
        case .vo2Max:
            let vo2Max = try await OuraDataCache.shared.values(endpoint: "vO2_max", startDate: startDate, endDate: endDate) { startDate, endDate in
                try await client.vo2Max(startDate: startDate, endDate: endDate).data
            }
            snapshot = DashboardSnapshotBuilder.make(
                dailySleep: [],
                sleep: [],
                readiness: [],
                activity: [],
                vo2Max: vo2Max,
                enabledMetrics: enabledMetrics)
        case .sleepDebt, .dailyStress, .resilience, .optimalBedtime, .sleepTimeRecommendation, .bestSleepWindow:
            return MetricSeries(metric: metric, points: [], availabilityMessage: "Trend not available for this card")
        }
        return snapshot.series(for: metric)
    }

    private func color(for value: Double) -> Color {
        Color(nsColor: ColorThresholds.color(
            for: value,
            metric: metric,
            baseline: series?.baselineValue,
            thresholdOverrides: settings.thresholdOverrides))
    }

    private func format(_ value: Double) -> String {
        metric.formattedValue(value, temperatureUnit: settings.temperatureUnit)
    }

    private func localDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func shortDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }
}
