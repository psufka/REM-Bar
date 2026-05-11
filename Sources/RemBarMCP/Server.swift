import Foundation

final class Server {
    func run() {
        while let line = readLine() {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            let response = #"{"jsonrpc":"2.0","id":null,"error":{"code":-32601,"message":"MCP tools are implemented in v1."}}"#
            print(response)
            fflush(stdout)
        }
    }
}
