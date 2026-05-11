import Foundation
import OuraKit

final class Server {
    private let tools: [any OuraMCPTool]
    private let toolsByName: [String: any OuraMCPTool]
    private let supportedProtocolVersions = [
        "2025-11-25",
        "2025-06-18",
        "2025-03-26",
        "2024-11-05",
    ]

    init(client: OuraClient) {
        tools = [
            DailySleepTool(client: client),
            SleepDetailTool(client: client),
            DailyReadinessTool(client: client),
            DailyActivityTool(client: client),
            DailyStressTool(client: client),
            DailyResilienceTool(client: client),
            DailyCardiovascularAgeTool(client: client),
            DailySpO2Tool(client: client),
            VO2MaxTool(client: client),
            SleepTimeTool(client: client),
            HeartRateTool(client: client),
            RingBatteryLevelTool(client: client),
            WorkoutTool(client: client),
            SessionTool(client: client),
            RestModePeriodTool(client: client),
            TagTool(client: client),
            EnhancedTagTool(client: client),
            PersonalInfoTool(client: client),
        ]
        toolsByName = Dictionary(uniqueKeysWithValues: tools.map { ($0.definition.name, $0) })
    }

    func run() async {
        while let line = readLine() {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            if let response = await handle(line: line) {
                write(response)
            }
        }
    }

    private func handle(line: String) async -> [String: Any]? {
        guard let data = line.data(using: .utf8) else {
            return errorResponse(id: NSNull(), code: -32700, message: "Request is not valid UTF-8.")
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            return errorResponse(id: NSNull(), code: -32700, message: "Parse error.")
        }

        guard let request = object as? [String: Any] else {
            return errorResponse(id: NSNull(), code: -32600, message: "Invalid JSON-RPC request.")
        }
        return await handle(request: request)
    }

    private func handle(request: [String: Any]) async -> [String: Any]? {
        let hasID = request.keys.contains("id")
        let id = request["id"] ?? NSNull()

        guard request["jsonrpc"] as? String == "2.0",
              let method = request["method"] as? String
        else {
            return hasID ? errorResponse(id: id, code: -32600, message: "Invalid JSON-RPC request.") : nil
        }

        switch method {
        case "initialize":
            guard hasID else {
                return nil
            }
            return successResponse(id: id, result: initializeResult(params: request["params"]))

        case "notifications/initialized":
            return nil

        case "ping":
            guard hasID else {
                return nil
            }
            return successResponse(id: id, result: [:])

        case "tools/list":
            guard hasID else {
                return nil
            }
            return successResponse(id: id, result: [
                "tools": tools.map(\.definition.json),
            ])

        case "tools/call":
            guard hasID else {
                return nil
            }
            return await callTool(id: id, params: request["params"])

        default:
            return hasID ? errorResponse(id: id, code: -32601, message: "Method not found: \(method)") : nil
        }
    }

    private func initializeResult(params: Any?) -> [String: Any] {
        let requested = (params as? [String: Any])?["protocolVersion"] as? String
        let protocolVersion = requested.flatMap { version in
            supportedProtocolVersions.contains(version) ? version : nil
        } ?? supportedProtocolVersions[0]

        return [
            "protocolVersion": protocolVersion,
            "capabilities": [
                "tools": [
                    "listChanged": false,
                ],
            ],
            "serverInfo": [
                "name": "rem-bar",
                "title": "REM-Bar MCP",
                "version": RemBarVersion.current,
            ],
            "instructions": "Read-only Oura Ring data from REM-Bar.",
        ]
    }

    private func callTool(id: Any, params: Any?) async -> [String: Any] {
        guard let params = params as? [String: Any],
              let name = params["name"] as? String
        else {
            return errorResponse(id: id, code: -32602, message: "tools/call requires params.name.")
        }

        guard let tool = toolsByName[name] else {
            return errorResponse(id: id, code: -32602, message: "Unknown tool: \(name)")
        }

        let arguments: [String: Any]
        if let rawArguments = params["arguments"], !(rawArguments is NSNull) {
            guard let object = rawArguments as? [String: Any] else {
                return successResponse(id: id, result: toolError("Tool arguments must be a JSON object."))
            }
            arguments = object
        } else {
            arguments = [:]
        }

        do {
            let text = try await tool.call(arguments: arguments)
            return successResponse(id: id, result: toolResult(text))
        } catch {
            return successResponse(id: id, result: toolError(message(for: error)))
        }
    }

    private func successResponse(id: Any, result: [String: Any]) -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": id,
            "result": result,
        ]
    }

    private func errorResponse(id: Any, code: Int, message: String) -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": id,
            "error": [
                "code": code,
                "message": message,
            ],
        ]
    }

    private func toolResult(_ text: String, isError: Bool = false) -> [String: Any] {
        [
            "content": [
                [
                    "type": "text",
                    "text": text,
                ],
            ],
            "isError": isError,
        ]
    }

    private func toolError(_ text: String) -> [String: Any] {
        toolResult(text, isError: true)
    }

    private func message(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription
        {
            return description
        }
        return error.localizedDescription
    }

    private func write(_ response: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(response),
              let data = try? JSONSerialization.data(withJSONObject: response, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8)
        else {
            fputs("RemBarMCP failed to encode JSON-RPC response.\n", stderr)
            return
        }
        print(json)
        fflush(stdout)
    }
}
