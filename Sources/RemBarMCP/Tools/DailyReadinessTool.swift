import Foundation
import OuraKit

struct DailyReadinessTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_daily_readiness",
        title: "Daily Readiness",
        description: "Get Oura daily readiness summaries, including readiness score and contributors, for a date range.",
        inputSchema: dateRangeInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try DateRange.parse(arguments)
        let response = try await client.dailyReadiness(startDate: range.startDate, endDate: range.endDate)
        return try prettyJSON(response)
    }
}
