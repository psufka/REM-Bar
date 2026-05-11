import Foundation
import OuraKit

struct DailySpO2Tool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_daily_spo2",
        title: "Daily SpO2",
        description: "Get Oura daily SpO2 summaries, including average SpO2 and breathing disturbance index, for a date range.",
        inputSchema: dateRangeInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try DateRange.parse(arguments)
        let response = try await client.dailySpO2(startDate: range.startDate, endDate: range.endDate)
        return try prettyJSON(response)
    }
}

struct VO2MaxTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_vo2_max",
        title: "VO2 Max",
        description: "Get Oura VO2 max estimates for a date range.",
        inputSchema: dateRangeInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try DateRange.parse(arguments)
        let response = try await client.vo2Max(startDate: range.startDate, endDate: range.endDate)
        return try prettyJSON(response)
    }
}

struct SleepTimeTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_sleep_time",
        title: "Sleep Time",
        description: "Get Oura sleep-time recommendations and optimal bedtime windows for a date range.",
        inputSchema: dateRangeInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try DateRange.parse(arguments)
        let response = try await client.sleepTime(startDate: range.startDate, endDate: range.endDate)
        return try prettyJSON(response)
    }
}

struct HeartRateTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_heart_rate",
        title: "Heart Rate",
        description: "Get Oura heart-rate time-series samples.",
        inputSchema: timeSeriesInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try TimeSeriesRange.parse(arguments)
        let response = try await client.heartRate(
            startDateTime: range.startDateTime,
            endDateTime: range.endDateTime,
            latest: range.latest)
        return try prettyJSON(response)
    }
}

struct RingBatteryLevelTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_ring_battery_level",
        title: "Ring Battery Level",
        description: "Get Oura ring battery-level time-series samples.",
        inputSchema: timeSeriesInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try TimeSeriesRange.parse(arguments)
        let response = try await client.ringBatteryLevel(
            startDateTime: range.startDateTime,
            endDateTime: range.endDateTime,
            latest: range.latest)
        return try prettyJSON(response)
    }
}

struct WorkoutTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_workout",
        title: "Workout",
        description: "Get Oura workout records for a date range.",
        inputSchema: dateRangeInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try DateRange.parse(arguments)
        let response = try await client.workout(startDate: range.startDate, endDate: range.endDate)
        return try prettyJSON(response)
    }
}

struct SessionTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_session",
        title: "Session",
        description: "Get Oura session records for a date range.",
        inputSchema: dateRangeInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try DateRange.parse(arguments)
        let response = try await client.session(startDate: range.startDate, endDate: range.endDate)
        return try prettyJSON(response)
    }
}

struct RestModePeriodTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_rest_mode_period",
        title: "Rest Mode Period",
        description: "Get Oura rest-mode periods for a date range.",
        inputSchema: dateRangeInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try DateRange.parse(arguments)
        let response = try await client.restModePeriod(startDate: range.startDate, endDate: range.endDate)
        return try prettyJSON(response)
    }
}

struct TagTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_tag",
        title: "Tag",
        description: "Get Oura tag records for a date range.",
        inputSchema: dateRangeInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try DateRange.parse(arguments)
        let response = try await client.tag(startDate: range.startDate, endDate: range.endDate)
        return try prettyJSON(response)
    }
}

struct EnhancedTagTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_enhanced_tag",
        title: "Enhanced Tag",
        description: "Get Oura enhanced tag records for a date range.",
        inputSchema: dateRangeInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try DateRange.parse(arguments)
        let response = try await client.enhancedTag(startDate: range.startDate, endDate: range.endDate)
        return try prettyJSON(response)
    }
}
