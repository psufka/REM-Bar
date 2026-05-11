import Foundation

public struct OuraResolvedToken: Equatable, Sendable {
    public let token: String
    public let source: OuraTokenSource
    public let keychainTokenAvailable: Bool
}

public struct OuraTokenSource: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case environment
        case keychain
        case configFile
        case launchctl
        case shellProfile
        case dotenv
    }

    public let kind: Kind
    public let name: String
    public let path: String?

    public var isKeychain: Bool {
        kind == .keychain
    }

    public var displayName: String {
        switch kind {
        case .environment:
            return "\(name) environment override"
        case .keychain:
            return "REM-Bar Keychain"
        case .configFile:
            return path ?? "~/.oura-mcp/config.json"
        case .launchctl:
            return "launchctl \(name)"
        case .shellProfile, .dotenv:
            return path ?? name
        }
    }
}

public struct OuraTokenDiscovery {
    public typealias EnvironmentProvider = @Sendable () -> [String: String]
    public typealias KeychainTokenProvider = @Sendable () throws -> String?
    public typealias LaunchctlProvider = @Sendable () -> String?

    public let environment: EnvironmentProvider
    public let keychainToken: KeychainTokenProvider
    public let launchctlToken: LaunchctlProvider
    public let fileManager: FileManager
    public let homeDirectory: URL

    public init(
        environment: @escaping EnvironmentProvider = { ProcessInfo.processInfo.environment },
        keychainToken: @escaping KeychainTokenProvider = { try KeychainStore.shared.readToken() },
        launchctlToken: @escaping LaunchctlProvider = { Self.readLaunchctlToken() },
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser)
    {
        self.environment = environment
        self.keychainToken = keychainToken
        self.launchctlToken = launchctlToken
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
    }

    public func resolve() throws -> OuraResolvedToken? {
        let keychainValue = try keychainToken()?.nonEmptyOuraToken
        let hasKeychain = keychainValue != nil

        if let token = environment()["OURA_TOKEN"]?.nonEmptyOuraToken {
            return OuraResolvedToken(
                token: token,
                source: OuraTokenSource(kind: .environment, name: "OURA_TOKEN", path: nil),
                keychainTokenAvailable: hasKeychain)
        }

        if let keychainValue {
            return OuraResolvedToken(
                token: keychainValue,
                source: OuraTokenSource(kind: .keychain, name: KeychainStore.service, path: nil),
                keychainTokenAvailable: true)
        }

        let configURL = homeDirectory.appendingPathComponent(".oura-mcp/config.json")
        if let token = Self.configFileToken(url: configURL)?.nonEmptyOuraToken {
            return OuraResolvedToken(
                token: token,
                source: OuraTokenSource(kind: .configFile, name: "oura-mcp config", path: displayPath(configURL)),
                keychainTokenAvailable: false)
        }

        if let token = launchctlToken()?.nonEmptyOuraToken {
            return OuraResolvedToken(
                token: token,
                source: OuraTokenSource(kind: .launchctl, name: "OURA_TOKEN", path: nil),
                keychainTokenAvailable: false)
        }

        if let ambient = ambientFileToken() {
            return OuraResolvedToken(
                token: ambient.token,
                source: ambient.source,
                keychainTokenAvailable: false)
        }

        return nil
    }

    public func ambientFileToken() -> (token: String, source: OuraTokenSource)? {
        for url in ambientTokenCandidateURLs() {
            guard fileManager.fileExists(atPath: url.path),
                  let contents = try? String(contentsOf: url, encoding: .utf8),
                  let token = Self.parseTokenAssignment(in: contents)?.nonEmptyOuraToken
            else {
                continue
            }
            let kind: OuraTokenSource.Kind = url.lastPathComponent.hasPrefix(".env") ? .dotenv : .shellProfile
            return (
                token,
                OuraTokenSource(kind: kind, name: "OURA_TOKEN", path: displayPath(url)))
        }
        return nil
    }

    public func ambientTokenCandidateURLs() -> [URL] {
        [
            ".zshenv",
            ".zprofile",
            ".zshrc",
            ".zlogin",
            ".bash_profile",
            ".bashrc",
            ".profile",
            ".config/fish/config.fish",
            ".env",
        ].map { homeDirectory.appendingPathComponent($0) }
    }

    public static func configFileToken(fileManager: FileManager = .default) -> String? {
        configFileToken(url: fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".oura-mcp/config.json"))
    }

    public static func configFileToken(url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return json["token"] as? String
    }

    public static func parseTokenAssignment(in contents: String) -> String? {
        for rawLine in contents.split(whereSeparator: \.isNewline).map(String.init) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            if line.hasPrefix("set ") {
                let parts = shellWords(line)
                if parts.count >= 4,
                   parts[0] == "set",
                   parts.dropFirst().contains("OURA_TOKEN"),
                   let index = parts.firstIndex(of: "OURA_TOKEN"),
                   parts.indices.contains(index + 1)
                {
                    return parts[index + 1]
                }
                continue
            }

            let stripped = line.hasPrefix("export ") ? String(line.dropFirst("export ".count)) : line
            guard stripped.hasPrefix("OURA_TOKEN=") else { continue }
            let value = String(stripped.dropFirst("OURA_TOKEN=".count))
            return cleanAssignmentValue(value)
        }
        return nil
    }

    public static func readLaunchctlToken() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["getenv", "OURA_TOKEN"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.nonEmptyOuraToken
    }

    private func displayPath(_ url: URL) -> String {
        let homePath = homeDirectory.path
        if url.path.hasPrefix(homePath + "/") {
            return "~/" + String(url.path.dropFirst(homePath.count + 1))
        }
        return url.path
    }

    private static func cleanAssignmentValue(_ value: String) -> String? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("\""), let end = trimmed.dropFirst().firstIndex(of: "\"") {
            trimmed = String(trimmed[trimmed.index(after: trimmed.startIndex)..<end])
        } else if trimmed.hasPrefix("'"), let end = trimmed.dropFirst().firstIndex(of: "'") {
            trimmed = String(trimmed[trimmed.index(after: trimmed.startIndex)..<end])
        } else if let comment = trimmed.firstIndex(of: "#") {
            trimmed = String(trimmed[..<comment]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let space = trimmed.firstIndex(where: { $0 == " " || $0 == "\t" }) {
            trimmed = String(trimmed[..<space])
        }
        return trimmed.nonEmptyOuraToken
    }

    private static func shellWords(_ line: String) -> [String] {
        var words: [String] = []
        var current = ""
        var quote: Character?

        for character in line {
            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
            } else if character == " " || character == "\t" {
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }

        if !current.isEmpty {
            words.append(current)
        }
        return words
    }
}

extension String {
    var nonEmptyOuraToken: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
