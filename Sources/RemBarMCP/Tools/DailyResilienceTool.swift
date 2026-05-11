import Foundation
import OuraKit

struct DailyResilienceTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_daily_resilience",
        title: "Daily Resilience",
        description: "Get Oura daily resilience levels and contributors for a date range.",
        inputSchema: dateRangeInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try DateRange.parse(arguments)
        let response = try await client.dailyResilience(startDate: range.startDate, endDate: range.endDate)
        return try prettyJSON(response)
    }
}
