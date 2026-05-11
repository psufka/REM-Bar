import Charts
import SwiftUI

struct SparklineView: View {
    let points: [MetricPoint]

    var body: some View {
        if points.isEmpty {
            RoundedRectangle(cornerRadius: 4)
                .stroke(.quaternary, lineWidth: 1)
        } else {
            Chart(points) { point in
                LineMark(
                    x: .value("Day", point.date),
                    y: .value("Value", point.value))
                .interpolationMethod(.catmullRom)
                AreaMark(
                    x: .value("Day", point.date),
                    y: .value("Value", point.value))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.linearGradient(
                    colors: [.accentColor.opacity(0.18), .accentColor.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
        }
    }
}
