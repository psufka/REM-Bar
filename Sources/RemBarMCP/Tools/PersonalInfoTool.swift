import Foundation
import OuraKit

struct PersonalInfoTool: OuraMCPTool {
    let client: OuraClient

    let definition = ToolDefinition(
        name: "oura_personal_info",
        title: "Personal Info",
        description: "Get Oura account personal information for the configured token.",
        inputSchema: emptyInputSchema)

    func call(arguments: [String: Any]) async throws -> String {
        guard arguments.isEmpty else {
            throw ToolInputError("oura_personal_info does not accept arguments.")
        }
        let response = try await client.personalInfo()
        return try prettyJSON(response)
    }
}
