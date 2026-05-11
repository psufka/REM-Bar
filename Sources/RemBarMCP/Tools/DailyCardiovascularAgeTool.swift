import Foundation
import OuraKit

struct DailyCardiovascularAgeTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_daily_cardiovascular_age",
        title: "Daily Cardiovascular Age",
        description: "Get Oura daily cardiovascular age predictions for a date range.",
        inputSchema: dateRangeInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try DateRange.parse(arguments)
        let response = try await client.dailyCardiovascularAge(startDate: range.startDate, endDate: range.endDate)
        return try prettyJSON(response)
    }
}
