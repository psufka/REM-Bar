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
            currentValueRow
            if let availabilityMessage = series.availabilityMessage {
                Text(availabilityMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            } else {
                SparklineView(points: series.points)
                    .frame(height: sparklineHeight)
                    .opacity(series.points.isEmpty ? 0.25 : 1)
                footerText
            }
        }
        .padding(10)
        .frame(height: PopoverLayoutMetrics.cardHeight)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .bottomTrailing) {
            bottomControls
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

    private var currentValueRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(series.formattedCurrentValue(using: temperatureUnit))
                .font(.title2.weight(.semibold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            trendButton

            Spacer(minLength: 0)
        }
    }

    private var valueColor: Color {
        Color(nsColor: ColorThresholds.color(
            for: series.currentValue,
            metric: series.metric,
            baseline: series.baselineValue,
            category: series.categoryValue,
            thresholdOverrides: thresholdOverrides))
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

    private var bottomControls: some View {
        infoButton
    }

    @ViewBuilder
    private var trendButton: some View {
        if series.metric.supportsTrendWindow, series.availabilityMessage == nil {
            Button {
                if series.metric == .sleepDebt {
                    SleepDebtTrendWindowController.shared.show(sleepTarget: sleepTarget)
                } else {
                    MetricTrendWindowController.shared.show(metric: series.metric)
                }
            } label: {
                Text("📊")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .help("Open trend")
        }
    }

    private var metricTitle: String {
        series.metric.label
    }

    private var sparklineHeight: CGFloat {
        series.metric == .sleepDebt ? 26 : 34
    }

    private var footerText: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(averageWindow.averageLabel) \(series.average.map { series.metric.formattedValue($0, temperatureUnit: temperatureUnit) } ?? "?")")
            if series.metric == .sleepDebt {
                Text("Goal \(sleepTarget.label)")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.trailing, 22)
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
    let averageWindow: SettingsStore.AverageWindow
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

            Text(detailText)
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
            bottomControls
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

    private var bottomControls: some View {
        HStack(spacing: 8) {
            trendButton
            infoButton
        }
    }

    @ViewBuilder
    private var trendButton: some View {
        if series.metric.supportsTrendWindow, series.availabilityMessage == nil {
            Button {
                MetricTrendWindowController.shared.show(metric: series.metric)
            } label: {
                Text("📊")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .help("Open trend")
        }
    }

    private var detailText: String {
        if series.metric == .bestSleepWindow, let score = series.baselineValue {
            let countText = series.sampleCount.map { " from \($0) of last \(averageWindow.dayCount) night\(averageWindow.dayCount == 1 ? "" : "s")" } ?? ""
            return "Avg Sleep Score \(Int(score.rounded()))\(countText)"
        }
        return series.availabilityMessage ?? series.metric.categoricalDescription
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
        let explanation = metric.explanation
        VStack(alignment: .leading, spacing: 10) {
            Label(metric.label, systemImage: metric.symbolName)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                labeledText("What it is", explanation.summary)
                labeledText("Source", explanation.source)
                labeledText("How to read it", explanation.interpretation)
                if let url = explanation.learnMoreURL {
                    Link(destination: url) {
                        Label("Oura Help", systemImage: "safari")
                    }
                    .font(.caption)
                }
            }
        }
        .padding(14)
        .frame(width: 390, alignment: .leading)
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
