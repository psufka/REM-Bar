import SwiftUI

struct MetricCardView: View {
    let series: MetricSeries

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(series.metric.label, systemImage: series.metric.symbolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(series.formattedDelta)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(deltaColor)
            }
            Text(series.formattedCurrentValue)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(nsColor: ColorThresholds.color(for: series.currentValue, metric: series.metric)))
            SparklineView(points: series.points)
                .frame(height: 42)
                .opacity(series.points.isEmpty ? 0.25 : 1)
            Text("7-day avg \(series.average.map(series.metric.formattedValue) ?? "?")")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(minHeight: 126)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private var deltaColor: Color {
        guard let delta = series.delta else { return .secondary }
        if delta == 0 { return .secondary }
        if series.metric == .rhr {
            return delta < 0 ? .green : .red
        }
        return delta > 0 ? .green : .red
    }
}
