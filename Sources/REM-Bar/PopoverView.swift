import SwiftUI

struct PopoverView: View {
    let snapshot: DashboardSnapshot
    let enabledMetrics: Set<BarMetric>
    let lastError: String?
    let lastRefresh: Date?
    let refresh: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(visibleMetrics) { metric in
                    let series = snapshot.series(for: metric)
                    if metric == .resilience {
                        CategoricalMetricCardView(series: series)
                    } else {
                        MetricCardView(series: series)
                    }
                }
            }

            if snapshot.metrics.values.allSatisfy(\.points.isEmpty), lastError == nil {
                Text("No Oura data loaded yet. Add a token in Settings or refresh after saving one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
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

            Text(lastRefreshText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 540)
        .background(.regularMaterial)
    }

    private var visibleMetrics: [BarMetric] {
        BarMetric.allCases.filter { enabledMetrics.contains($0) }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: visibleMetrics.count > 2 ? 3 : 2)
    }

    private var lastRefreshText: String {
        guard let lastRefresh else { return "Not refreshed yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Updated \(formatter.localizedString(for: lastRefresh, relativeTo: Date()))"
    }
}
