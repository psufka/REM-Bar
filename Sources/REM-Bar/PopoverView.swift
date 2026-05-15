import OuraKit
import SwiftUI

struct PopoverView: View {
    let snapshot: DashboardSnapshot
    let enabledMetrics: Set<BarMetric>
    let metricOrder: [BarMetric]
    let temperatureUnit: TemperatureUnit
    let averageWindow: SettingsStore.AverageWindow
    let sleepTarget: SleepTarget
    let iconStyle: IconStyle
    let gridViewportHeight: CGFloat
    let lastError: String?
    let tokenNeedsUpdate: Bool
    let lastRefresh: Date?
    let refresh: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void
    @State private var showingSyncHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: PopoverLayoutMetrics.contentSpacing) {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: PopoverLayoutMetrics.cardSpacing) {
                    ForEach(visibleMetrics) { metric in
                        let series = snapshot.series(for: metric)
                        if metric.isCategorical {
                            CategoricalMetricCardView(series: series, iconStyle: iconStyle)
                        } else {
                            MetricCardView(
                                series: series,
                                temperatureUnit: temperatureUnit,
                                averageWindow: averageWindow,
                                sleepTarget: sleepTarget,
                                iconStyle: iconStyle)
                        }
                    }
                }
            }
            .frame(height: gridViewportHeight)

            if snapshot.metrics.values.allSatisfy({ $0.points.isEmpty && $0.categoryValue == nil && $0.availabilityMessage == nil }), lastError == nil {
                Text("No Oura data loaded yet. Add a token in Settings or refresh after saving one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lastError {
                if tokenNeedsUpdate {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(lastError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button("Settings", action: openSettings)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    Text(lastError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            Divider()

            HStack(spacing: 10) {
                Link(destination: URL(string: "https://cloud.ouraring.com")!) {
                    Label("Open Oura", systemImage: "safari")
                }
                Spacer()
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh now")
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
                Button(action: quit) {
                    Image(systemName: "power")
                }
                .help("Quit")
            }
            .buttonStyle(.borderless)

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(syncStatusText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("Data can take a couple hours to sync to Oura Cloud/API.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Button {
                            showingSyncHelp = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("How to force Oura Cloud sync")
                        .popover(isPresented: $showingSyncHelp, arrowEdge: .bottom) {
                            OuraSyncHelpView()
                        }
                    }
                }
                Spacer(minLength: 8)
                Text(appFooterText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(PopoverLayoutMetrics.contentPadding)
        .frame(width: PopoverLayoutMetrics.popoverWidth)
        .background(.regularMaterial)
    }

    private var visibleMetrics: [BarMetric] {
        metricOrder.filter { enabledMetrics.contains($0) }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: PopoverLayoutMetrics.cardSpacing), count: gridColumnCount)
    }

    private var gridColumnCount: Int {
        PopoverLayoutMetrics.columnCount(for: visibleMetrics.count)
    }

    private var lastRefreshText: String {
        guard let lastRefresh else { return "Not refreshed yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Updated \(formatter.localizedString(for: lastRefresh, relativeTo: Date()))"
    }

    private var syncStatusText: String {
        guard let latestSleepText else { return lastRefreshText }
        return "\(latestSleepText) - \(lastRefreshText)"
    }

    private var latestSleepText: String? {
        guard let latestSleep = snapshot.latestSleep else { return nil }
        guard let bedtimeRange = formattedBedtimeRange(latestSleep) else {
            return "Latest sleep synced: \(formattedSleepDay(latestSleep.day))"
        }
        return "Latest sleep synced: \(bedtimeRange)"
    }

    private func formattedSleepDay(_ day: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: day) else { return day }

        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }

    private func formattedBedtimeRange(_ latestSleep: LatestSleepSummary) -> String? {
        let start = latestSleep.bedtimeStart.map(formattedSleepDateTime)
            ?? formattedRawSleepDateTime(latestSleep.bedtimeStartRaw)
        let end = latestSleep.bedtimeEnd.map(formattedSleepDateTime)
            ?? formattedRawSleepDateTime(latestSleep.bedtimeEndRaw)
        guard let start, let end else { return nil }
        return "\(start) - \(end)"
    }

    private func formattedSleepDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMM d h:mm a")
        return formatter.string(from: date)
    }

    private func formattedRawSleepDateTime(_ string: String?) -> String? {
        guard let string else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let localPart = trimmed.split(separator: "T", maxSplits: 1).dropFirst().first
        let dayPart = trimmed.split(separator: "T", maxSplits: 1).first.map(String.init)
        guard let localPart, let dayPart else { return trimmed }

        let day = formattedSleepDay(dayPart)
        let timePrefix = localPart.prefix(5)
        guard timePrefix.count == 5 else { return "\(day) \(localPart)" }
        return "\(day) \(timePrefix)"
    }

    private var appFooterText: String {
        "REM-Bar \(appVersion)"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? RemBarVersion.current
    }
}

private struct OuraSyncHelpView: View {
    private let supportURL = URL(string: "https://support.ouraring.com/hc/en-us/articles/360025587353-Oura-on-the-Web")!
    private let cloudURL = URL(string: "https://cloud.ouraring.com")!

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Force Oura Cloud Sync")
                .font(.headline)

            Text("REM-Bar can only read sleep data after it reaches Oura Cloud/API.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                instruction("1.", "Put your ring on the charger for a few minutes.")
                instruction("2.", "Open the Oura iPhone app and wait for the ring sync.")
                instruction("3.", "In Oura: menu > Settings > Back up all data.")
                instruction("4.", "After backup completes, check Oura on the Web.")
                instruction("5.", "If the sleep appears there, refresh REM-Bar.")
            }

            HStack(spacing: 12) {
                Link(destination: supportURL) {
                    Label("Oura instructions", systemImage: "safari")
                }
                Link(destination: cloudURL) {
                    Label("Oura Web", systemImage: "globe")
                }
            }
            .font(.caption)
        }
        .padding(14)
        .frame(width: 340)
    }

    private func instruction(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(number)
                .font(.caption.weight(.semibold))
                .frame(width: 18, alignment: .trailing)
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
