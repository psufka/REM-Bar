import Foundation
import Testing

struct RemBarMCPProtocolTests {
    @Test func stdioProtocolSmoke() throws {
        guard let executableURL = remBarMCPExecutableURL() else {
            return
        }

        let input = [
            #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}"#,
            #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#,
            #"{"jsonrpc":"2.0","id":2,"method":"ping"}"#,
            #"{"jsonrpc":"2.0","id":3,"method":"tools/list"}"#,
            #"{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"oura_daily_sleep","arguments":{"start_date":"bad-date"}}}"#,
        ].joined(separator: "\n") + "\n"

        let process = Process()
        process.executableURL = executableURL

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        stdin.fileHandleForWriting.write(Data(input.utf8))
        stdin.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let responses = try output
            .split(separator: "\n")
            .map { line in
                let data = Data(line.utf8)
                return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            }

        #expect(responses.count == 4)
        #expect(((responses[0]["result"] as? [String: Any])?["protocolVersion"] as? String) == "2025-11-25")
        #expect((responses[1]["result"] as? [String: Any])?.isEmpty == true)

        let tools = try #require((responses[2]["result"] as? [String: Any])?["tools"] as? [[String: Any]])
        let toolNames = tools.compactMap { $0["name"] as? String }
        #expect(toolNames == [
            "oura_daily_sleep",
            "oura_sleep_detail",
            "oura_daily_readiness",
            "oura_daily_activity",
            "oura_personal_info",
        ])

        let toolError = try #require(responses[3]["result"] as? [String: Any])
        #expect(toolError["isError"] as? Bool == true)
    }

    private func remBarMCPExecutableURL() -> URL? {
        if let path = ProcessInfo.processInfo.environment["REMBAR_MCP_EXECUTABLE"], !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
        }

        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidates = [
            packageRoot.appendingPathComponent(".build/debug/RemBarMCP"),
            packageRoot.appendingPathComponent(".build/arm64-apple-macosx/debug/RemBarMCP"),
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
