import Foundation
import OuraKit

struct BestSleepWindowBucket: Identifiable, Equatable {
    let startMinute: Int
    let label: String
    let averageScore: Double
    let nights: Int

    var id: Int { startMinute }

    var displayOrder: Int {
        startMinute < 12 * 60 ? startMinute + 24 * 60 : startMinute
    }
}

enum BestSleepWindowCalculator {
    static let minimumNightsForCard = 3

    static func buckets(
        sleep: [Sleep],
        dailySleep: [DailySleep],
        dayCount: Int? = nil,
        range: SleepDebtTrendRange? = nil,
        now: Date = Date())
        -> [BestSleepWindowBucket]
    {
        let sleepByDay = Dictionary(grouping: sleep, by: \.day)
        let dailySleepByDay = latestDailySleepByDay(dailySleep)
        let includedDays = includedDays(from: sleepByDay.keys, dayCount: dayCount, range: range, now: now)
        var bucketScores: [Int: [Double]] = [:]

        for day in sleepByDay.keys.sorted() where includedDays.contains(day) {
            guard let detail = preferredMainSleep(from: sleepByDay[day] ?? []),
                  let bedtimeStart = isoDate(from: detail.bedtimeStart),
                  let score = dailySleepByDay[day]?.score
            else {
                continue
            }

            let bucket = bedtimeBucket(for: bedtimeStart)
            guard isPlausibleBedtimeBucket(bucket) else { continue }
            bucketScores[bucket, default: []].append(Double(score))
        }

        return bucketScores
            .map { bucket, scores in
                BestSleepWindowBucket(
                    startMinute: bucket,
                    label: formattedClockRange(startMinute: bucket),
                    averageScore: scores.reduce(0, +) / Double(scores.count),
                    nights: scores.count)
            }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    static func bestBucket(
        sleep: [Sleep],
        dailySleep: [DailySleep],
        minimumNights: Int = minimumNightsForCard,
        dayCount: Int? = nil,
        range: SleepDebtTrendRange? = nil,
        now: Date = Date())
        -> BestSleepWindowBucket?
    {
        buckets(sleep: sleep, dailySleep: dailySleep, dayCount: dayCount, range: range, now: now)
            .filter { $0.nights >= minimumNights }
            .max {
                if $0.averageScore == $1.averageScore {
                    return $0.nights < $1.nights
                }
                return $0.averageScore < $1.averageScore
            }
    }

    private static func latestDailySleepByDay(_ values: [DailySleep]) -> [String: DailySleep] {
        var latest: [String: DailySleep] = [:]
        for value in values {
            latest[value.day] = value
        }
        return latest
    }

    private static func preferredMainSleep(from details: [Sleep]) -> Sleep? {
        details
            .filter { $0.type?.lowercased() == "long_sleep" }
            .max { ($0.totalSleepDuration ?? 0) < ($1.totalSleepDuration ?? 0) }
    }

    private static func isDay(_ day: String, in range: SleepDebtTrendRange?, now: Date) -> Bool {
        guard let range,
              let date = dayFormatter.date(from: day),
              let startDate = Calendar.current.date(
                byAdding: .day,
                value: -(range.rawValue - 1),
                to: Calendar.current.startOfDay(for: now))
        else {
            return true
        }
        return date >= startDate && date <= Calendar.current.startOfDay(for: now)
    }

    private static func includedDays(
        from days: Dictionary<String, [Sleep]>.Keys,
        dayCount: Int?,
        range: SleepDebtTrendRange?,
        now: Date)
        -> Set<String>
    {
        if let dayCount,
           let latestDate = days.compactMap({ dayFormatter.date(from: $0) }).max(),
           let startDate = Calendar.current.date(byAdding: .day, value: -(dayCount - 1), to: latestDate)
        {
            return Set(days.filter { day in
                guard let date = dayFormatter.date(from: day) else { return false }
                return date >= startDate && date <= latestDate
            })
        }

        return Set(days.filter { isDay($0, in: range, now: now) })
    }

    private static func bedtimeBucket(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return (minuteOfDay / 30) * 30
    }

    private static func isPlausibleBedtimeBucket(_ minuteOfDay: Int) -> Bool {
        minuteOfDay >= 18 * 60 || minuteOfDay <= 6 * 60
    }

    private static func formattedClockRange(startMinute: Int) -> String {
        let endMinute = (startMinute + 30) % (24 * 60)
        return "\(formattedClockMinute(startMinute)) - \(formattedClockMinute(endMinute))"
    }

    private static func formattedClockMinute(_ minuteOfDay: Int) -> String {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60
        let date = components.date ?? Date(timeIntervalSince1970: 0)
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("h:mm a")
        return formatter.string(from: date)
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

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
