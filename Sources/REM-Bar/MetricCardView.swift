import SwiftUI

struct MetricCardView: View {
    let series: MetricSeries
    let temperatureUnit: TemperatureUnit
    let averageWindow: SettingsStore.AverageWindow
    let iconStyle: IconStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                metricLabel
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
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            if let availabilityMessage = series.availabilityMessage {
                Text(availabilityMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            } else {
                SparklineView(points: series.points)
                    .frame(height: 34)
                    .opacity(series.points.isEmpty ? 0.25 : 1)
                Text("\(averageWindow.averageLabel) \(series.average.map { series.metric.formattedValue($0, temperatureUnit: temperatureUnit) } ?? "?")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(height: PopoverLayoutMetrics.cardHeight)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private var deltaColor: Color {
        guard let delta = series.delta else { return .secondary }
        if delta == 0 { return .secondary }
        if series.metric == .rhr || series.metric == .sleepDebt {
            return delta < 0 ? .green : .red
        }
        return delta > 0 ? .green : .red
    }

    private var metricLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: series.metric.symbolName)
                .foregroundStyle(iconColor)
            Text(series.metric.label)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .font(.caption)
    }

    private var iconColor: Color {
        guard iconStyle == .color else { return .secondary }
        return Color(nsColor: ColorThresholds.color(
            for: series.currentValue,
            metric: series.metric,
            baseline: series.baselineValue,
            category: series.categoryValue))
    }
}

struct CategoricalMetricCardView: View {
    let series: MetricSeries
    let iconStyle: IconStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            metricLabel

            Text(series.formattedCurrentValue)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(nsColor: ColorThresholds.color(
                    for: series.currentValue,
                    metric: series.metric,
                    category: series.categoryValue)))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(series.availabilityMessage ?? series.metric.categoricalDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(height: PopoverLayoutMetrics.cardHeight)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private var metricLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: series.metric.symbolName)
                .foregroundStyle(iconColor)
            Text(series.metric.label)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .font(.caption)
    }

    private var iconColor: Color {
        guard iconStyle == .color else { return .secondary }
        return Color(nsColor: ColorThresholds.color(
            for: series.currentValue,
            metric: series.metric,
            category: series.categoryValue))
    }
}
