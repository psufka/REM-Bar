import Foundation
import OuraKit

protocol OuraCacheRecord: Codable, Equatable, Sendable {
    var cacheDay: String { get }
    var cacheKey: String { get }
}

extension DailySleep: OuraCacheRecord {
    var cacheDay: String { day }
    var cacheKey: String { id ?? day }
}

extension Sleep: OuraCacheRecord {
    var cacheDay: String { day }
    var cacheKey: String {
        id ?? [day, type, bedtimeStart, bedtimeEnd]
            .compactMap { $0 }
            .joined(separator: "|")
    }
}

extension DailyReadiness: OuraCacheRecord {
    var cacheDay: String { day }
    var cacheKey: String { id ?? day }
}

extension DailyActivity: OuraCacheRecord {
    var cacheDay: String { day }
    var cacheKey: String { id ?? day }
}

extension DailyStress: OuraCacheRecord {
    var cacheDay: String { day }
    var cacheKey: String { id ?? day }
}

extension DailyResilience: OuraCacheRecord {
    var cacheDay: String { day }
    var cacheKey: String { id ?? day }
}

extension DailyCardiovascularAge: OuraCacheRecord {
    var cacheDay: String { day }
    var cacheKey: String { id ?? day }
}

extension DailySpO2: OuraCacheRecord {
    var cacheDay: String { day }
    var cacheKey: String { id ?? day }
}

extension VO2Max: OuraCacheRecord {
    var cacheDay: String { day }
    var cacheKey: String { id ?? day }
}

extension SleepTime: OuraCacheRecord {
    var cacheDay: String { day }
    var cacheKey: String { id ?? day }
}

actor OuraDataCache {
    static let shared = OuraDataCache()

    private let rootURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default, rootURL: URL? = nil) {
        self.fileManager = fileManager
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser
            self.rootURL = appSupport
                .appendingPathComponent("REM-Bar", isDirectory: true)
                .appendingPathComponent("OuraCache", isDirectory: true)
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func values<Record: OuraCacheRecord>(
        endpoint: String,
        startDate: String,
        endDate: String,
        fetch: (String, String) async throws -> [Record])
        async throws -> [Record]
    {
        let requestedDays = Self.days(from: startDate, through: endDate)
        var envelope = readEnvelope(endpoint: endpoint, as: Record.self)
        let coveredDays = Set(envelope.coveredDays)
        let missingDays = requestedDays.filter { !coveredDays.contains($0) }

        guard !missingDays.isEmpty else {
            return filter(envelope.records, startDate: startDate, endDate: endDate)
        }

        do {
            for range in Self.contiguousRanges(from: missingDays) {
                let fetched = try await fetch(range.start, range.end)
                envelope.records = merge(existing: envelope.records, fetched: fetched)
                envelope.coveredDays = Array(Set(envelope.coveredDays).union(range.days)).sorted()
                envelope.updatedAt = Date()
            }
            writeEnvelope(envelope, endpoint: endpoint)
        } catch OuraError.missingToken {
            throw OuraError.missingToken
        } catch OuraError.invalidToken {
            throw OuraError.invalidToken
        } catch {
            let cached = filter(envelope.records, startDate: startDate, endDate: endDate)
            if !cached.isEmpty {
                return cached
            }
            throw error
        }

        return filter(envelope.records, startDate: startDate, endDate: endDate)
    }

    private func readEnvelope<Record: OuraCacheRecord>(
        endpoint: String,
        as _: Record.Type)
        -> CacheEnvelope<Record>
    {
        let url = fileURL(for: endpoint)
        guard let data = try? Data(contentsOf: url),
              let envelope = try? decoder.decode(CacheEnvelope<Record>.self, from: data)
        else {
            return CacheEnvelope(coveredDays: [], records: [], updatedAt: nil)
        }
        return envelope
    }

    private func writeEnvelope<Record: OuraCacheRecord>(_ envelope: CacheEnvelope<Record>, endpoint: String) {
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
            let data = try encoder.encode(envelope)
            try data.write(to: fileURL(for: endpoint), options: [.atomic])
        } catch {
            // Cache failures should never block the live dashboard.
        }
    }

    private func fileURL(for endpoint: String) -> URL {
        rootURL.appendingPathComponent(Self.safeFilename(endpoint), isDirectory: false)
            .appendingPathExtension("json")
    }

    private func merge<Record: OuraCacheRecord>(existing: [Record], fetched: [Record]) -> [Record] {
        var recordsByKey = Dictionary(uniqueKeysWithValues: existing.map { ($0.cacheKey, $0) })
        for record in fetched {
            recordsByKey[record.cacheKey] = record
        }
        return recordsByKey.values.sorted {
            if $0.cacheDay == $1.cacheDay {
                return $0.cacheKey < $1.cacheKey
            }
            return $0.cacheDay < $1.cacheDay
        }
    }

    private func filter<Record: OuraCacheRecord>(
        _ records: [Record],
        startDate: String,
        endDate: String)
        -> [Record]
    {
        records.filter { $0.cacheDay >= startDate && $0.cacheDay <= endDate }
    }

    private static func safeFilename(_ endpoint: String) -> String {
        endpoint.map { character in
            character.isLetter || character.isNumber || character == "_" || character == "-" ? character : "_"
        }
        .map(String.init)
        .joined()
    }

    private static func contiguousRanges(from days: [String]) -> [DayRange] {
        let uniqueDays = Array(Set(days)).sorted()
        var ranges: [DayRange] = []
        var current: [String] = []
        var previousDate: Date?

        for day in uniqueDays {
            guard let date = dayFormatter.date(from: day) else { continue }
            if let previousDate,
               Calendar.current.dateComponents([.day], from: previousDate, to: date).day != 1
            {
                if let range = DayRange(days: current) {
                    ranges.append(range)
                }
                current = []
            }
            current.append(day)
            previousDate = date
        }

        if let range = DayRange(days: current) {
            ranges.append(range)
        }
        return ranges
    }

    private static func days(from startDate: String, through endDate: String) -> [String] {
        guard let start = dayFormatter.date(from: startDate),
              let end = dayFormatter.date(from: endDate),
              start <= end
        else {
            return []
        }

        var days: [String] = []
        var date = start
        while date <= end {
            days.append(dayFormatter.string(from: date))
            guard let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: date) else {
                break
            }
            date = nextDate
        }
        return days
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct CacheEnvelope<Record: OuraCacheRecord>: Codable {
    var coveredDays: [String]
    var records: [Record]
    var updatedAt: Date?
}

private struct DayRange {
    let days: [String]
    let start: String
    let end: String

    init?(days: [String]) {
        guard let start = days.first, let end = days.last else { return nil }
        self.days = days
        self.start = start
        self.end = end
    }
}
