import Foundation
import OuraKit

struct DailyStressTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_daily_stress",
        title: "Daily Stress",
        description: "Get Oura daily stress summaries, including day summary and high-stress or high-recovery durations, for a date range.",
        inputSchema: dateRangeInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try DateRange.parse(arguments)
        let response = try await client.dailyStress(startDate: range.startDate, endDate: range.endDate)
        return try prettyJSON(response)
    }
}
