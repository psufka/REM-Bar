import Foundation

protocol OuraMCPTool {
    var definition: ToolDefinition { get }
    func call(arguments: [String: Any]) async throws -> String
}

struct ToolDefinition {
    let name: String
    let title: String
    let description: String
    let inputSchema: [String: Any]

    var json: [String: Any] {
        [
            "name": name,
            "title": title,
            "description": description,
            "inputSchema": inputSchema,
            "annotations": [
                "readOnlyHint": true,
            ],
        ]
    }
}

struct DateRange {
    let startDate: String
    let endDate: String

    static func parse(_ arguments: [String: Any]) throws -> DateRange {
        let allowedKeys = Set(["start_date", "end_date"])
        let unknownKeys = Set(arguments.keys).subtracting(allowedKeys)
        guard unknownKeys.isEmpty else {
            throw ToolInputError("Unknown argument(s): \(unknownKeys.sorted().joined(separator: ", ")).")
        }

        let rawStart = try optionalString(arguments["start_date"], name: "start_date")
        let rawEnd = try optionalString(arguments["end_date"], name: "end_date")
        let today = Self.todayString()
        let startDate = rawStart ?? rawEnd ?? today
        let endDate = rawEnd ?? rawStart ?? today

        let start = try parsedDate(startDate, name: "start_date")
        let end = try parsedDate(endDate, name: "end_date")
        guard start <= end else {
            throw ToolInputError("start_date must be on or before end_date.")
        }

        return DateRange(startDate: startDate, endDate: endDate)
    }

    private static func optionalString(_ value: Any?, name: String) throws -> String? {
        guard let value, !(value is NSNull) else {
            return nil
        }
        guard let string = value as? String else {
            throw ToolInputError("\(name) must be a string in YYYY-MM-DD format.")
        }
        return string
    }

    private static func parsedDate(_ value: String, name: String) throws -> Date {
        guard value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil,
              let date = dateFormatter.date(from: value)
        else {
            throw ToolInputError("\(name) must be a valid date in YYYY-MM-DD format.")
        }
        return date
    }

    private static func todayString() -> String {
        dateFormatter.string(from: Date())
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()
}

struct TimeSeriesRange {
    let startDateTime: String?
    let endDateTime: String?
    let latest: Bool?

    static func parse(_ arguments: [String: Any]) throws -> TimeSeriesRange {
        let allowedKeys = Set(["start_datetime", "end_datetime", "latest"])
        let unknownKeys = Set(arguments.keys).subtracting(allowedKeys)
        guard unknownKeys.isEmpty else {
            throw ToolInputError("Unknown argument(s): \(unknownKeys.sorted().joined(separator: ", ")).")
        }

        let startDateTime = try optionalString(arguments["start_datetime"], name: "start_datetime")
        let endDateTime = try optionalString(arguments["end_datetime"], name: "end_datetime")
        let requestedLatest = try optionalBool(arguments["latest"], name: "latest")
        try validateDateTime(startDateTime, name: "start_datetime")
        try validateDateTime(endDateTime, name: "end_datetime")
        let latest = requestedLatest ?? (startDateTime == nil && endDateTime == nil ? true : nil)

        return TimeSeriesRange(startDateTime: startDateTime, endDateTime: endDateTime, latest: latest)
    }

    private static func optionalString(_ value: Any?, name: String) throws -> String? {
        guard let value, !(value is NSNull) else {
            return nil
        }
        guard let string = value as? String else {
            throw ToolInputError("\(name) must be an ISO 8601 date-time string.")
        }
        return string
    }

    private static func optionalBool(_ value: Any?, name: String) throws -> Bool? {
        guard let value, !(value is NSNull) else {
            return nil
        }
        guard let bool = value as? Bool else {
            throw ToolInputError("\(name) must be a boolean.")
        }
        return bool
    }

    private static func validateDateTime(_ value: String?, name: String) throws {
        guard let value else { return }
        guard value.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}"#, options: .regularExpression) != nil else {
            throw ToolInputError("\(name) must be an ISO 8601 date-time string.")
        }
    }
}

struct ToolInputError: Error, LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}

let dateRangeInputSchema: [String: Any] = [
    "type": "object",
    "properties": [
        "start_date": [
            "type": "string",
            "description": "YYYY-MM-DD. Defaults to end_date, or today when both dates are omitted.",
        ],
        "end_date": [
            "type": "string",
            "description": "YYYY-MM-DD. Defaults to start_date, or today when both dates are omitted.",
        ],
    ],
    "additionalProperties": false,
]

let timeSeriesInputSchema: [String: Any] = [
    "type": "object",
    "properties": [
        "start_datetime": [
            "type": "string",
            "description": "ISO 8601 date-time. When omitted with end_datetime, latest defaults to true.",
        ],
        "end_datetime": [
            "type": "string",
            "description": "ISO 8601 date-time. Optional upper bound for time-series endpoints.",
        ],
        "latest": [
            "type": "boolean",
            "description": "Return only the latest sample. Defaults to true when start_datetime and end_datetime are omitted.",
        ],
    ],
    "additionalProperties": false,
]

let emptyInputSchema: [String: Any] = [
    "type": "object",
    "additionalProperties": false,
]

func prettyJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(value)
    guard let text = String(data: data, encoding: .utf8) else {
        throw ToolInputError("Could not encode tool result as UTF-8 JSON.")
    }
    return text
}
