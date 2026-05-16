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
        formattedCurrentValue(using: .celsius)
    }

    func formattedCurrentValue(using temperatureUnit: TemperatureUnit) -> String {
        if availabilityMessage != nil { return "N/A" }
        if let categoryValue {
            return metric.formattedCategory(categoryValue)
        }
        guard let currentValue else { return "?" }
        return metric.formattedValue(currentValue, temperatureUnit: temperatureUnit)
    }

    var formattedDelta: String {
        formattedDelta(using: .celsius)
    }

    func formattedDelta(using temperatureUnit: TemperatureUnit) -> String {
        if metric.isCategorical || availabilityMessage != nil { return "" }
        guard let delta else { return "0" }
        let prefix = delta >= 0 ? "+" : ""
        return "\(prefix)\(metric.formattedDelta(delta, temperatureUnit: temperatureUnit))"
    }
}

struct LatestSleepSummary: Equatable {
    let day: String
    let bedtimeStartRaw: String?
    let bedtimeEndRaw: String?
    let bedtimeStart: Date?
    let bedtimeEnd: Date?
}

struct DashboardSnapshot: Equatable {
    var metrics: [BarMetric: MetricSeries]
    var lastUpdated: Date?
    var latestSleep: LatestSleepSummary?

    init(
        metrics: [BarMetric: MetricSeries],
        lastUpdated: Date? = nil,
        latestSleep: LatestSleepSummary? = nil)
    {
        self.metrics = metrics
        self.lastUpdated = lastUpdated
        self.latestSleep = latestSleep
    }

    static let empty = DashboardSnapshot(metrics: [:])

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
        dailySpO2: [DailySpO2] = [],
        vo2Max: [VO2Max] = [],
        sleepTime: [SleepTime] = [],
        personalInfo: PersonalInfo? = nil,
        sleepTargetMinutes: Int = 480,
        enabledMetrics: Set<BarMetric> = Set(BarMetric.allCases),
        displayWindowDays: Int? = nil)
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
        let cardiovascularAgeByDay = latestByDay(dailyCardiovascularAge, day: \.day)
        let spo2ByDay = latestByDay(dailySpO2, day: \.day)
        let vo2MaxByDay = latestByDay(vo2Max, day: \.day)
        let days = Set(
            dailySleep.map(\.day)
                + sleep.map(\.day)
                + readiness.map(\.day)
                + activity.map(\.day)
                + dailyStress.map(\.day)
                + dailyResilience.map(\.day)
                + dailyCardiovascularAge.map(\.day)
                + dailySpO2.map(\.day)
                + vo2Max.map(\.day)
                + sleepTime.map(\.day))
            .sorted()
        let sleepDebtByDay = Dictionary(uniqueKeysWithValues: SleepDebtTrendCalculator
            .points(from: sleep, sleepTargetMinutes: sleepTargetMinutes)
            .map { ($0.id, $0.minutes) })

        func point(day: String, value: Double?) -> MetricPoint? {
            guard let value, let date = dateFormatter.date(from: day) else { return nil }
            return MetricPoint(id: day, date: date, value: value)
        }

        let metricPairs: [(BarMetric, MetricSeries)] = BarMetric.allCases
            .filter { enabledMetrics.contains($0) }
            .map { metric in
            let points = days.compactMap { day -> MetricPoint? in
                let detail = preferredSleepDetail(from: sleepByDay[day] ?? [])
                switch metric {
                case .sleepScore:
                    return point(day: day, value: dailySleepByDay[day]?.score.map(Double.init))
                case .rem:
                    return point(day: day, value: detail?.remSleepDuration.map { Double($0) / 60.0 })
                case .deepSleep:
                    return point(day: day, value: detail?.deepSleepDuration.map { Double($0) / 60.0 })
                case .totalSleep:
                    return point(day: day, value: detail?.totalSleepDuration.map { Double($0) / 60.0 })
                case .sleepDebt:
                    return point(day: day, value: sleepDebtByDay[day])
                case .lightSleep:
                    return point(day: day, value: detail?.lightSleepDuration.map { Double($0) / 60.0 })
                case .awakeTime:
                    return point(day: day, value: detail?.awakeTime.map { Double($0) / 60.0 })
                case .timeInBed:
                    return point(day: day, value: detail?.timeInBed.map { Double($0) / 60.0 })
                case .sleepLatency:
                    return point(day: day, value: detail?.latency.map { Double($0) / 60.0 })
                case .averageBreath:
                    return point(day: day, value: detail?.averageBreath)
                case .hrv:
                    return point(day: day, value: detail?.averageHrv.map(Double.init))
                case .rhr:
                    if let lowest = detail?.lowestHeartRate {
                        return point(day: day, value: Double(lowest))
                    }
                    return point(day: day, value: detail?.averageHeartRate)
                case .readiness:
                    return point(day: day, value: readinessByDay[day]?.score.map(Double.init))
                case .hrvBalance:
                    return point(day: day, value: readinessByDay[day]?.contributors?.hrvBalance.map(Double.init))
                case .sleepBalance:
                    return point(day: day, value: readinessByDay[day]?.contributors?.sleepBalance.map(Double.init))
                case .sleepRegularity:
                    return point(day: day, value: readinessByDay[day]?.contributors?.sleepRegularity.map(Double.init))
                case .activity:
                    return point(day: day, value: activityByDay[day]?.score.map(Double.init))
                case .bodyTemperatureDeviation:
                    return point(day: day, value: readinessByDay[day]?.temperatureDeviation)
                case .sleepEfficiency:
                    return point(day: day, value: detail?.efficiency.map(Double.init))
                case .dailyStress:
                    return nil
                case .resilience:
                    return nil
                case .cardiovascularAge:
                    return point(day: day, value: cardiovascularAgeByDay[day]?.vascularAge.map(Double.init))
                case .averageSpO2:
                    return point(day: day, value: spo2ByDay[day]?.spo2Percentage?.average)
                case .breathingDisturbance:
                    return point(day: day, value: spo2ByDay[day]?.breathingDisturbanceIndex.map(Double.init))
                case .vo2Max:
                    return point(day: day, value: vo2MaxByDay[day]?.vo2Max)
                case .optimalBedtime, .sleepTimeRecommendation:
                    return nil
                }
            }
            let sorted = displayWindowDays.map { latestPoints(points, dayCount: $0) } ?? points.sorted { $0.date < $1.date }
            let unavailableMessage = unavailableMessage(
                for: metric,
                dailyStress: dailyStress,
                dailyResilience: dailyResilience,
                dailyCardiovascularAge: dailyCardiovascularAge,
                dailySpO2: dailySpO2,
                vo2Max: vo2Max,
                sleepTime: sleepTime)
            if metric == .resilience {
                let level = dailyResilience.sorted { $0.day < $1.day }.last?.level?.rawValue
                return (metric, MetricSeries(
                    metric: metric,
                    points: [],
                    categoryValue: level,
                    availabilityMessage: unavailableMessage))
            }
            if metric == .dailyStress {
                let summary = dailyStress.sorted { $0.day < $1.day }.last?.daySummary?.rawValue
                return (metric, MetricSeries(
                    metric: metric,
                    points: [],
                    categoryValue: summary,
                    availabilityMessage: unavailableMessage))
            }
            if metric == .optimalBedtime {
                let window = sleepTime.sorted { $0.day < $1.day }.last?.optimalBedtime
                return (metric, MetricSeries(
                    metric: metric,
                    points: [],
                    categoryValue: bedtimeWindowString(from: window),
                    availabilityMessage: unavailableMessage))
            }
            if metric == .sleepTimeRecommendation {
                let recommendation = sleepTime.sorted { $0.day < $1.day }.last?.recommendation
                return (metric, MetricSeries(
                    metric: metric,
                    points: [],
                    categoryValue: recommendation,
                    availabilityMessage: unavailableMessage))
            }
            let baseline = metric == .cardiovascularAge ? personalInfo?.age.map(Double.init) : nil
            return (metric, MetricSeries(
                metric: metric,
                points: sorted,
                availabilityMessage: unavailableMessage,
                baselineValue: baseline))
        }

        return DashboardSnapshot(
            metrics: Dictionary(uniqueKeysWithValues: metricPairs),
            lastUpdated: Date(),
            latestSleep: latestSleepSummary(from: sleep))
    }

    private static func latestByDay<T>(_ values: [T], day keyPath: KeyPath<T, String>) -> [String: T] {
        var latest: [String: T] = [:]
        for value in values {
            latest[value[keyPath: keyPath]] = value
        }
        return latest
    }

    private static func latestPoints(_ points: [MetricPoint], dayCount: Int) -> [MetricPoint] {
        Array(points.sorted { $0.date < $1.date }.suffix(dayCount))
    }

    static func totalSleepMinutesForDebt(from details: [Sleep]) -> Double? {
        let sleepSessions = details.filter { detail in
            guard detail.totalSleepDuration != nil else { return false }
            return detail.type?.lowercased() != "rest"
        }
        let sleepSessionSeconds = sleepSessions.map { $0.totalSleepDuration ?? 0 }.reduce(0, +)
        if sleepSessionSeconds > 0 {
            return Double(sleepSessionSeconds) / 60.0
        }
        return preferredSleepDetail(from: details)?.totalSleepDuration.map { Double($0) / 60.0 }
    }

    private static func unavailableMessage(
        for metric: BarMetric,
        dailyStress: [DailyStress],
        dailyResilience: [DailyResilience],
        dailyCardiovascularAge: [DailyCardiovascularAge],
        dailySpO2: [DailySpO2],
        vo2Max: [VO2Max],
        sleepTime: [SleepTime])
        -> String?
    {
        switch metric {
        case .dailyStress where dailyStress.isEmpty,
             .resilience where dailyResilience.isEmpty,
             .cardiovascularAge where dailyCardiovascularAge.isEmpty,
             .averageSpO2 where dailySpO2.isEmpty,
             .breathingDisturbance where dailySpO2.isEmpty,
             .vo2Max where vo2Max.isEmpty,
             .optimalBedtime where sleepTime.isEmpty,
             .sleepTimeRecommendation where sleepTime.isEmpty:
            return "Not available on your ring"
        case .sleepScore, .rem, .deepSleep, .totalSleep, .sleepDebt, .lightSleep, .awakeTime, .timeInBed, .sleepLatency, .averageBreath, .hrv, .rhr, .readiness, .activity, .hrvBalance, .sleepBalance, .sleepRegularity, .bodyTemperatureDeviation, .sleepEfficiency, .dailyStress, .resilience, .cardiovascularAge, .averageSpO2, .breathingDisturbance, .vo2Max, .optimalBedtime, .sleepTimeRecommendation:
            return nil
        }
    }

    private static func preferredSleepDetail(from details: [Sleep]) -> Sleep? {
        details.first { $0.type == "long_sleep" } ?? details.max {
            ($0.totalSleepDuration ?? 0) < ($1.totalSleepDuration ?? 0)
        }
    }

    private static func latestSleepSummary(from sleep: [Sleep]) -> LatestSleepSummary? {
        let sleepByDay = Dictionary(grouping: sleep, by: \.day)
        guard let day = sleepByDay.keys.sorted().last,
              let detail = preferredSleepDetail(from: sleepByDay[day] ?? [])
        else {
            return nil
        }
        return LatestSleepSummary(
            day: day,
            bedtimeStartRaw: detail.bedtimeStart,
            bedtimeEndRaw: detail.bedtimeEnd,
            bedtimeStart: isoDate(from: detail.bedtimeStart),
            bedtimeEnd: isoDate(from: detail.bedtimeEnd))
    }

    private static func isoDate(from string: String?) -> Date? {
        guard let string else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: string) {
            return date
        }
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: string) {
            return date
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        for format in [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
        ] {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    private static func bedtimeWindowString(from window: SleepTime.OptimalBedtimeWindow?) -> String? {
        guard let startOffset = window?.startOffset,
              let endOffset = window?.endOffset
        else {
            return nil
        }
        return "\(clockTime(from: startOffset))-\(clockTime(from: endOffset))"
    }

    private static func clockTime(from offset: Int) -> String {
        let secondsInDay = 24 * 60 * 60
        let normalized = ((offset % secondsInDay) + secondsInDay) % secondsInDay
        let hours = normalized / 3600
        let minutes = (normalized % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}
