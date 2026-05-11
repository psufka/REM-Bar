import SwiftUI

struct MetricCardView: View {
    let series: MetricSeries
    let temperatureUnit: TemperatureUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(series.metric.label, systemImage: series.metric.symbolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                let formattedDelta = series.formattedDelta(using: temperatureUnit)
                if !formattedDelta.isEmpty {
                    Text(formattedDelta)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(deltaColor)
                }
            }
            Text(series.formattedCurrentValue(using: temperatureUnit))
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(nsColor: ColorThresholds.color(
                    for: series.currentValue,
                    metric: series.metric,
                    baseline: series.baselineValue,
                    category: series.categoryValue)))
            if let availabilityMessage = series.availabilityMessage {
                Text(availabilityMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            } else {
                SparklineView(points: series.points)
                    .frame(height: 42)
                    .opacity(series.points.isEmpty ? 0.25 : 1)
                Text("7-day avg \(series.average.map { series.metric.formattedValue($0, temperatureUnit: temperatureUnit) } ?? "?")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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

struct CategoricalMetricCardView: View {
    let series: MetricSeries

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(series.metric.label, systemImage: series.metric.symbolName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(series.formattedCurrentValue)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(nsColor: ColorThresholds.color(
                    for: series.currentValue,
                    metric: series.metric,
                    category: series.categoryValue)))

            Text(series.availabilityMessage ?? series.metric.categoricalDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(minHeight: 126)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}
