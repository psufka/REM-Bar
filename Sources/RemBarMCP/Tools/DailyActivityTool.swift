import Foundation
import OuraKit

struct DailyActivityTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_daily_activity",
        title: "Daily Activity",
        description: "Get Oura daily activity summaries, including activity score, steps, calories, and distance, for a date range.",
        inputSchema: dateRangeInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try DateRange.parse(arguments)
        let response = try await client.dailyActivity(startDate: range.startDate, endDate: range.endDate)
        return try prettyJSON(response)
    }
}
