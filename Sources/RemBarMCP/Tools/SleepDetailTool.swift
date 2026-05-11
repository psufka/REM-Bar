import Foundation
import OuraKit

struct SleepDetailTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_sleep_detail",
        title: "Sleep Detail",
        description: "Get detailed Oura sleep sessions, including sleep stages, heart rate, HRV, and timing, for a date range.",
        inputSchema: dateRangeInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        let range = try DateRange.parse(arguments)
        let response = try await client.sleep(startDate: range.startDate, endDate: range.endDate)
        return try prettyJSON(response)
    }
}
