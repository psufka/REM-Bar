import Foundation

public typealias OuraTokenProvider = @Sendable () async throws -> String

public final class OuraClient: @unchecked Sendable {
    public let baseURL: URL
    private let session: URLSession
    private let tokenProvider: OuraTokenProvider
    private let retryGate = TokenRetryGate()
    private let decoder: JSONDecoder

    public init(
        baseURL: URL = URL(string: "https://api.ouraring.com")!,
        session: URLSession = .shared,
        tokenProvider: @escaping OuraTokenProvider)
    {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.decoder = JSONDecoder()
    }

    public static func live(keychain: KeychainStore = .shared) -> OuraClient {
        OuraClient(tokenProvider: tokenProvider(keychainToken: {
            try keychain.readToken()
        }))
    }

    public static func configFileToken(fileManager: FileManager = .default) -> String? {
        let home = fileManager.homeDirectoryForCurrentUser
        let url = home.appendingPathComponent(".oura-mcp/config.json")
        return configFileToken(url: url)
    }

    public static func configFileToken(url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return json["token"] as? String
    }

    static func tokenProvider(
        environment: @escaping @Sendable () -> [String: String] = { ProcessInfo.processInfo.environment },
        keychainToken: @escaping @Sendable () throws -> String? = { try KeychainStore.shared.readToken() },
        configToken: @escaping @Sendable () -> String? = { OuraClient.configFileToken() })
        -> OuraTokenProvider
    {
        {
            if let token = environment()["OURA_TOKEN"]?.nonEmptyOuraToken {
                return token
            }
            if let token = try keychainToken()?.nonEmptyOuraToken {
                return token
            }
            if let token = configToken()?.nonEmptyOuraToken {
                return token
            }
            throw OuraError.missingToken
        }
    }

    public func personalInfo() async throws -> PersonalInfo {
        try await request(endpoint: .personalInfo, queryItems: [], responseType: PersonalInfo.self)
    }

    public func dailySleep(startDate: String, endDate: String) async throws -> OuraCollection<DailySleep> {
        try await collection(endpoint: .dailySleep, startDate: startDate, endDate: endDate, responseType: DailySleep.self)
    }

    public func sleep(startDate: String, endDate: String) async throws -> OuraCollection<Sleep> {
        try await collection(endpoint: .sleep, startDate: startDate, endDate: endDate, responseType: Sleep.self)
    }

    public func dailyReadiness(startDate: String, endDate: String) async throws -> OuraCollection<DailyReadiness> {
        try await collection(endpoint: .dailyReadiness, startDate: startDate, endDate: endDate, responseType: DailyReadiness.self)
    }

    public func dailyActivity(startDate: String, endDate: String) async throws -> OuraCollection<DailyActivity> {
        try await collection(endpoint: .dailyActivity, startDate: startDate, endDate: endDate, responseType: DailyActivity.self)
    }

    private func collection<T: Codable & Equatable & Sendable>(
        endpoint: Endpoint,
        startDate: String,
        endDate: String,
        responseType _: T.Type)
        async throws -> OuraCollection<T>
    {
        try await request(
            endpoint: endpoint,
            queryItems: [
                URLQueryItem(name: "start_date", value: startDate),
                URLQueryItem(name: "end_date", value: endDate),
            ],
            responseType: OuraCollection<T>.self)
    }

    private func request<T: Decodable>(
        endpoint: Endpoint,
        queryItems: [URLQueryItem],
        responseType: T.Type)
        async throws -> T
    {
        let token = try await tokenProvider()
        do {
            return try await performRequest(endpoint: endpoint, queryItems: queryItems, token: token, responseType: responseType)
        } catch OuraError.invalidToken {
            let retriedToken = try await retryGate.token {
                try await self.tokenProvider()
            }
            do {
                return try await performRequest(endpoint: endpoint, queryItems: queryItems, token: retriedToken, responseType: responseType)
            } catch OuraError.invalidToken {
                throw OuraError.invalidToken
            }
        }
    }

    private func performRequest<T: Decodable>(
        endpoint: Endpoint,
        queryItems: [URLQueryItem],
        token: String,
        responseType: T.Type)
        async throws -> T
    {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else {
            throw OuraError.network("Could not construct Oura URL.")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OuraError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OuraError.network("Oura API returned a non-HTTP response.")
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(responseType, from: data)
            } catch {
                throw OuraError.decode(error.localizedDescription)
            }
        case 401:
            throw OuraError.invalidToken
        case 429:
            throw OuraError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OuraError.badStatus(httpResponse.statusCode, body)
        }
    }
}

private extension String {
    var nonEmptyOuraToken: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private actor TokenRetryGate {
    private var inFlight: Task<String, Error>?

    func token(_ operation: @escaping @Sendable () async throws -> String) async throws -> String {
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task {
            try await operation()
        }
        inFlight = task
        defer {
            inFlight = nil
        }
        return try await task.value
    }
}
