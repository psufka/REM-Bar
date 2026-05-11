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
    let categoryValue: String?
    let availabilityMessage: String?
    let baselineValue: Double?

    init(
        metric: BarMetric,
        points: [MetricPoint],
        categoryValue: String? = nil,
        availabilityMessage: String? = nil,
        baselineValue: Double? = nil)
    {
        self.metric = metric
        self.points = points
        self.categoryValue = categoryValue
        self.availabilityMessage = availabilityMessage
        self.baselineValue = baselineValue
    }

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
        if availabilityMessage != nil { return "N/A" }
        if let categoryValue {
            return metric.formattedCategory(categoryValue)
        }
        guard let currentValue else { return "?" }
        return metric.formattedValue(currentValue)
    }

    var formattedDelta: String {
        if metric == .resilience || availabilityMessage != nil { return "" }
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
        activity: [DailyActivity],
        dailyStress: [DailyStress] = [],
        dailyResilience: [DailyResilience] = [],
        dailyCardiovascularAge: [DailyCardiovascularAge] = [],
        personalInfo: PersonalInfo? = nil)
        -> DashboardSnapshot
    {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let sleepByDay = Dictionary(grouping: sleep, by: \.day)
        let dailySleepByDay = latestByDay(dailySleep, day: \.day)
        let readinessByDay = latestByDay(readiness, day: \.day)
        let activityByDay = latestByDay(activity, day: \.day)
        let stressByDay = latestByDay(dailyStress, day: \.day)
        let cardiovascularAgeByDay = latestByDay(dailyCardiovascularAge, day: \.day)
        let days = Set(
            dailySleep.map(\.day)
                + sleep.map(\.day)
                + readiness.map(\.day)
                + activity.map(\.day)
                + dailyStress.map(\.day)
                + dailyResilience.map(\.day)
                + dailyCardiovascularAge.map(\.day))
            .sorted()

        func point(day: String, value: Double?) -> MetricPoint? {
            guard let value, let date = dateFormatter.date(from: day) else { return nil }
            return MetricPoint(id: day, date: date, value: value)
        }

        let metricPairs: [(BarMetric, MetricSeries)] = BarMetric.allCases.map { metric in
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
                case .activity:
                    return point(day: day, value: activityByDay[day]?.score.map(Double.init))
                case .bodyTemperatureDeviation:
                    return point(day: day, value: readinessByDay[day]?.temperatureDeviation)
                case .sleepEfficiency:
                    return point(day: day, value: detail?.efficiency.map(Double.init))
                case .dailyStress:
                    return point(day: day, value: stressByDay[day].flatMap(stressValue))
                case .resilience:
                    return nil
                case .cardiovascularAge:
                    return point(day: day, value: cardiovascularAgeByDay[day]?.vascularAge.map(Double.init))
                }
            }
            let sorted = points.sorted { $0.date < $1.date }
            let unavailableMessage = unavailableMessage(
                for: metric,
                dailyStress: dailyStress,
                dailyResilience: dailyResilience,
                dailyCardiovascularAge: dailyCardiovascularAge)
            if metric == .resilience {
                let level = dailyResilience.sorted { $0.day < $1.day }.last?.level?.rawValue
                return (metric, MetricSeries(
                    metric: metric,
                    points: [],
                    categoryValue: level,
                    availabilityMessage: unavailableMessage))
            }
            let categoryValue: String?
            if metric == .dailyStress {
                categoryValue = dailyStress.sorted { $0.day < $1.day }.last?.daySummary?.rawValue
            } else {
                categoryValue = nil
            }
            let baseline = metric == .cardiovascularAge ? personalInfo?.age.map(Double.init) : nil
            return (metric, MetricSeries(
                metric: metric,
                points: sorted,
                categoryValue: categoryValue,
                availabilityMessage: unavailableMessage,
                baselineValue: baseline))
        }

        return DashboardSnapshot(
            metrics: Dictionary(uniqueKeysWithValues: metricPairs),
            lastUpdated: Date())
    }

    private static func latestByDay<T>(_ values: [T], day keyPath: KeyPath<T, String>) -> [String: T] {
        var latest: [String: T] = [:]
        for value in values {
            latest[value[keyPath: keyPath]] = value
        }
        return latest
    }

    private static func unavailableMessage(
        for metric: BarMetric,
        dailyStress: [DailyStress],
        dailyResilience: [DailyResilience],
        dailyCardiovascularAge: [DailyCardiovascularAge])
        -> String?
    {
        switch metric {
        case .dailyStress where dailyStress.isEmpty,
             .resilience where dailyResilience.isEmpty,
             .cardiovascularAge where dailyCardiovascularAge.isEmpty:
            return "Not available on your ring"
        case .sleepScore, .rem, .hrv, .rhr, .readiness, .activity, .bodyTemperatureDeviation, .sleepEfficiency, .dailyStress, .resilience, .cardiovascularAge:
            return nil
        }
    }

    private static func stressValue(from stress: DailyStress) -> Double? {
        if let summary = stress.daySummary {
            switch summary {
            case .restored:
                return 0
            case .normal:
                return 1
            case .stressful:
                return 2
            }
        }
        guard let stressHigh = stress.stressHigh, let recoveryHigh = stress.recoveryHigh else {
            return nil
        }
        if recoveryHigh > stressHigh { return 0 }
        if stressHigh > recoveryHigh { return 2 }
        return 1
    }

    private static func preferredSleepDetail(from details: [Sleep]) -> Sleep? {
        details.first { $0.type == "long_sleep" } ?? details.max {
            ($0.totalSleepDuration ?? 0) < ($1.totalSleepDuration ?? 0)
        }
    }
}
