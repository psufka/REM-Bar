import Foundation
import OuraKit

struct DailySleepTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_daily_sleep",
        title: "Daily Sleep",
        description: "Get Oura daily sleep summaries, including sleep score and contributors, for a date range.",
        inputSchema: dateRangeInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try DateRange.parse(arguments)
        let response = try await client.dailySleep(startDate: range.startDate, endDate: range.endDate)
        return try prettyJSON(response)
    }
}
