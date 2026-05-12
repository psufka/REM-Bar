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

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(lastRefreshText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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

    private var appFooterText: String {
        "REM-Bar \(appVersion)"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? RemBarVersion.current
    }
}
