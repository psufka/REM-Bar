import SwiftUI

struct PopoverView: View {
    let snapshot: DashboardSnapshot
    let lastError: String?
    let lastRefresh: Date?
    let refresh: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(BarMetric.allCases) { metric in
                    MetricCardView(series: snapshot.series(for: metric))
                }
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
        .frame(width: 430)
        .background(.regularMaterial)
    }

    private var lastRefreshText: String {
        guard let lastRefresh else { return "Not refreshed yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Updated \(formatter.localizedString(for: lastRefresh, relativeTo: Date()))"
    }
}
