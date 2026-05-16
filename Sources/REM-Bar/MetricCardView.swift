import SwiftUI

struct MetricCardView: View {
    let series: MetricSeries
    let temperatureUnit: TemperatureUnit
    let averageWindow: SettingsStore.AverageWindow
    let sleepTarget: SleepTarget
    let iconStyle: IconStyle
    let thresholdOverrides: [BarMetric: MetricThresholdOverride]
    @State private var showingExplanation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                metricLabel
                    .layoutPriority(1)
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
                    category: series.categoryValue,
                    thresholdOverrides: thresholdOverrides)))
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
                    .padding(.trailing, 22)
            }
        }
        .padding(10)
        .frame(height: PopoverLayoutMetrics.cardHeight)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .bottomTrailing) {
            infoButton
                .padding(8)
        }
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
            Text(metricTitle)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .font(.caption)
    }

    private var infoButton: some View {
        Button {
            showingExplanation = true
        } label: {
            Image(systemName: "info.circle")
                .font(.caption2)
                .padding(2)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help("Metric details")
        .popover(isPresented: $showingExplanation, arrowEdge: .bottom) {
            MetricInfoPopoverView(metric: series.metric)
        }
    }

    private var metricTitle: String {
        guard series.metric == .sleepDebt else { return series.metric.label }
        return "\(series.metric.label) (goal: \(sleepTarget.label))"
    }

    private var iconColor: Color {
        guard iconStyle == .color else { return .secondary }
        return Color(nsColor: ColorThresholds.color(
            for: series.currentValue,
            metric: series.metric,
            baseline: series.baselineValue,
            category: series.categoryValue,
            thresholdOverrides: thresholdOverrides))
    }
}

struct CategoricalMetricCardView: View {
    let series: MetricSeries
    let iconStyle: IconStyle
    @State private var showingExplanation = false

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
                .padding(.trailing, 22)

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(height: PopoverLayoutMetrics.cardHeight)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .bottomTrailing) {
            infoButton
                .padding(8)
        }
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

    private var infoButton: some View {
        Button {
            showingExplanation = true
        } label: {
            Image(systemName: "info.circle")
                .font(.caption2)
                .padding(2)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help("Metric details")
        .popover(isPresented: $showingExplanation, arrowEdge: .bottom) {
            MetricInfoPopoverView(metric: series.metric)
        }
    }

    private var iconColor: Color {
        guard iconStyle == .color else { return .secondary }
        return Color(nsColor: ColorThresholds.color(
            for: series.currentValue,
            metric: series.metric,
            category: series.categoryValue))
    }
}

struct MetricInfoPopoverView: View {
    let metric: BarMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(metric.label, systemImage: metric.symbolName)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                labeledText("What it is", metric.explanation.summary)
                labeledText("Oura source", metric.explanation.source)
                labeledText("How to read it", metric.explanation.interpretation)
            }
        }
        .padding(14)
        .frame(width: 340, alignment: .leading)
    }

    private func labeledText(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
