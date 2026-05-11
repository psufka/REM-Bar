import Foundation
import OuraKit

struct MetricPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let value: Double
}

struct MetricSeries: Identifiable, Equatable {
    let metric: BarMetric
    let points: [MetricPoint]

    var id: BarMetric { metric }

    var currentValue: Double? {
        points.sorted { $0.date < $1.date }.last?.value
    }

    var average: Double? {
        guard !points.isEmpty else { return nil }
        return points.map(\.value).reduce(0, +) / Double(points.count)
    }

    var delta: Double? {
        guard let currentValue, let average else { return nil }
        return currentValue - average
    }

    var formattedCurrentValue: String {
        guard let currentValue else { return "?" }
        return metric.formattedValue(currentValue)
    }

    var formattedDelta: String {
        guard let delta else { return "0" }
        let prefix = delta >= 0 ? "+" : ""
        return "\(prefix)\(metric.formattedDelta(delta))"
    }
}

struct DashboardSnapshot: Equatable {
    var metrics: [BarMetric: MetricSeries]
    var lastUpdated: Date?

    static let empty = DashboardSnapshot(metrics: [:], lastUpdated: nil)

    func series(for metric: BarMetric) -> MetricSeries {
        metrics[metric] ?? MetricSeries(metric: metric, points: [])
    }
}

enum DashboardSnapshotBuilder {
    static func make(
        dailySleep: [DailySleep],
        sleep: [Sleep],
        readiness: [DailyReadiness],
        activity _: [DailyActivity])
        -> DashboardSnapshot
    {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let sleepByDay = Dictionary(grouping: sleep, by: \.day)
        let dailySleepByDay = Dictionary(uniqueKeysWithValues: dailySleep.map { ($0.day, $0) })
        let readinessByDay = Dictionary(uniqueKeysWithValues: readiness.map { ($0.day, $0) })
        let days = Set(dailySleep.map(\.day) + sleep.map(\.day) + readiness.map(\.day)).sorted()

        func point(day: String, value: Double?) -> MetricPoint? {
            guard let value, let date = dateFormatter.date(from: day) else { return nil }
            return MetricPoint(id: day, date: date, value: value)
        }

        let metricPairs: [(BarMetric, [MetricPoint])] = BarMetric.allCases.map { metric in
            let points = days.compactMap { day -> MetricPoint? in
                let detail = preferredSleepDetail(from: sleepByDay[day] ?? [])
                switch metric {
                case .sleepScore:
                    return point(day: day, value: dailySleepByDay[day]?.score.map(Double.init))
                case .rem:
                    return point(day: day, value: detail?.remSleepDuration.map { Double($0) / 60.0 })
                case .hrv:
                    return point(day: day, value: detail?.averageHrv.map(Double.init))
                case .rhr:
                    if let lowest = detail?.lowestHeartRate {
                        return point(day: day, value: Double(lowest))
                    }
                    return point(day: day, value: detail?.averageHeartRate)
                case .readiness:
                    return point(day: day, value: readinessByDay[day]?.score.map(Double.init))
                }
            }
            let sorted = points.sorted { $0.date < $1.date }
            return (metric, sorted)
        }

        return DashboardSnapshot(
            metrics: Dictionary(uniqueKeysWithValues: metricPairs.map { metric, points in
                (metric, MetricSeries(metric: metric, points: points))
            }),
            lastUpdated: Date())
    }

    private static func preferredSleepDetail(from details: [Sleep]) -> Sleep? {
        details.first { $0.type == "long_sleep" } ?? details.max {
            ($0.totalSleepDuration ?? 0) < ($1.totalSleepDuration ?? 0)
        }
    }
}
