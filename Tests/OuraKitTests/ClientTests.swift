import Foundation
import XCTest
@testable import OuraKit

final class ClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    func testPersonalInfoRequestUsesBearerToken() async throws {
        StubURLProtocol.enqueue(status: 200, body: #"{"id":"user-123","email":"paul@example.com"}"#)
        let client = makeClient(token: "test-token")

        let info = try await client.personalInfo()

        XCTAssertEqual(info.email, "paul@example.com")
        XCTAssertEqual(StubURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        XCTAssertEqual(StubURLProtocol.requests.first?.url?.path, "/v2/usercollection/personal_info")
    }

    func testDailySleepAddsDateQueryItems() async throws {
        StubURLProtocol.enqueue(status: 200, body: #"{"data":[]}"#)
        let client = makeClient(token: "test-token")

        _ = try await client.dailySleep(startDate: "2026-05-01", endDate: "2026-05-08")

        let requestURL = try XCTUnwrap(StubURLProtocol.requests.first?.url)
        let components = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "start_date", value: "2026-05-01")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "end_date", value: "2026-05-08")) == true)
    }

    func testTimeSeriesEndpointsDefaultToLatest() async throws {
        StubURLProtocol.enqueue(status: 200, body: #"{"data":[]}"#)
        let client = makeClient(token: "test-token")

        _ = try await client.heartRate()

        let requestURL = try XCTUnwrap(StubURLProtocol.requests.first?.url)
        let components = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        XCTAssertEqual(requestURL.path, "/v2/usercollection/heartrate")
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "latest", value: "true")) == true)
    }

    func testNewDateRangeEndpointAddsDateQueryItems() async throws {
        StubURLProtocol.enqueue(status: 200, body: #"{"data":[]}"#)
        let client = makeClient(token: "test-token")

        _ = try await client.dailySpO2(startDate: "2026-05-01", endDate: "2026-05-08")

        let requestURL = try XCTUnwrap(StubURLProtocol.requests.first?.url)
        let components = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        XCTAssertEqual(requestURL.path, "/v2/usercollection/daily_spo2")
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "start_date", value: "2026-05-01")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "end_date", value: "2026-05-08")) == true)
    }

    func testUnauthorizedResponseReReadsTokenAndRetriesOnce() async throws {
        let provider = TokenCounter()
        StubURLProtocol.enqueue(status: 401, body: #"{"status":401,"title":"Invalid Access Token"}"#)
        StubURLProtocol.enqueue(status: 200, body: #"{"id":"user-123","email":"paul@example.com"}"#)
        let client = makeClient {
            await provider.next()
        }

        let info = try await client.personalInfo()

        let tokenReadCount = await provider.count
        XCTAssertEqual(info.email, "paul@example.com")
        XCTAssertEqual(tokenReadCount, 2)
        XCTAssertEqual(StubURLProtocol.requests.count, 2)
        XCTAssertEqual(StubURLProtocol.requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer token-2")
    }

    func testSecondUnauthorizedResponseReturnsInvalidToken() async throws {
        let provider = TokenCounter()
        StubURLProtocol.enqueue(status: 401, body: #"{"status":401,"title":"Invalid Access Token"}"#)
        StubURLProtocol.enqueue(status: 401, body: #"{"status":401,"title":"Invalid Access Token"}"#)
        let client = makeClient {
            await provider.next()
        }

        do {
            _ = try await client.personalInfo()
            XCTFail("Expected invalidToken error.")
        } catch OuraError.invalidToken {
            let tokenReadCount = await provider.count
            XCTAssertEqual(tokenReadCount, 2)
            XCTAssertEqual(StubURLProtocol.requests.count, 2)
            XCTAssertEqual(StubURLProtocol.requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer token-2")
        } catch {
            XCTFail("Expected invalidToken error, got \(error).")
        }
    }

    func testEnvironmentTokenOverridesKeychainAndConfigTokens() async throws {
        let provider = OuraClient.tokenProvider(
            environment: { ["OURA_TOKEN": " env-token\n"] },
            keychainToken: { "keychain-token" },
            configToken: { "config-token" })

        let token = try await provider()

        XCTAssertEqual(token, "env-token")
    }

    func testConfigTokenIsFallbackWithoutReadingUserConfig() async throws {
        let configURL = try temporaryConfigURL(contents: #"{"token":"config-token"}"#)
        defer {
            try? FileManager.default.removeItem(at: configURL.deletingLastPathComponent().deletingLastPathComponent())
        }

        let provider = OuraClient.tokenProvider(
            environment: { [:] },
            keychainToken: { nil },
            configToken: { OuraClient.configFileToken(url: configURL) })

        let token = try await provider()

        XCTAssertEqual(token, "config-token")
    }

    func testMissingTokenThrowsWhenAllSourcesAreEmpty() async throws {
        let provider = OuraClient.tokenProvider(
            environment: { ["OURA_TOKEN": "  "] },
            keychainToken: { "\n" },
            configToken: { "" },
            ambientToken: { "" })

        do {
            _ = try await provider()
            XCTFail("Expected missingToken error.")
        } catch OuraError.missingToken {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Expected missingToken error, got \(error).")
        }
    }

    func testAmbientShellProfileTokenIsFallback() throws {
        let home = try temporaryHome()
        let zshrc = home.appendingPathComponent(".zshrc")
        try """
        # comment
        export OURA_TOKEN="shell-profile-token"
        """.write(to: zshrc, atomically: true, encoding: .utf8)

        let discovery = OuraTokenDiscovery(
            environment: { [:] },
            keychainToken: { nil },
            launchctlToken: { nil },
            homeDirectory: home)

        let resolved = try XCTUnwrap(try discovery.resolve())

        XCTAssertEqual(resolved.token, "shell-profile-token")
        XCTAssertEqual(resolved.source.kind, .shellProfile)
        XCTAssertEqual(resolved.source.displayName, "~/.zshrc")
    }

    func testTokenDiscoveryPrecedenceMatchesRuntimeOrder() throws {
        let home = try temporaryHome()
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".oura-mcp", isDirectory: true),
            withIntermediateDirectories: true)
        try #"{"token":"config-token"}"#.write(
            to: home.appendingPathComponent(".oura-mcp/config.json"),
            atomically: true,
            encoding: .utf8)
        try #"OURA_TOKEN=dotenv-token"#.write(
            to: home.appendingPathComponent(".env"),
            atomically: true,
            encoding: .utf8)

        let discovery = OuraTokenDiscovery(
            environment: { ["OURA_TOKEN": "env-token"] },
            keychainToken: { "keychain-token" },
            launchctlToken: { "launchctl-token" },
            homeDirectory: home)

        let resolved = try XCTUnwrap(try discovery.resolve())

        XCTAssertEqual(resolved.token, "env-token")
        XCTAssertEqual(resolved.source.kind, .environment)
        XCTAssertTrue(resolved.keychainTokenAvailable)
    }

    func testSourceSummariesExposeAvailabilityWithoutTokens() throws {
        let home = try temporaryHome()
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".oura-mcp", isDirectory: true),
            withIntermediateDirectories: true)
        try #"{"token":"config-secret"}"#.write(
            to: home.appendingPathComponent(".oura-mcp/config.json"),
            atomically: true,
            encoding: .utf8)
        try #"export OURA_TOKEN="shell-secret""#.write(
            to: home.appendingPathComponent(".zshrc"),
            atomically: true,
            encoding: .utf8)

        let discovery = OuraTokenDiscovery(
            environment: { [:] },
            keychainToken: { nil },
            launchctlToken: { nil },
            homeDirectory: home)

        let summaries = try discovery.sourceSummaries()
        let available = summaries.filter(\.isAvailable)

        XCTAssertEqual(available.map(\.source.kind), [.configFile, .shellProfile])
        XCTAssertEqual(summaries.first(where: { $0.source.kind == .configFile })?.isActive, true)
        XCTAssertTrue(summaries.allSatisfy { !$0.source.displayName.contains("secret") })
    }

    func testSourceSummariesMarkEnvironmentActiveAndKeychainAvailable() throws {
        let discovery = OuraTokenDiscovery(
            environment: { ["OURA_TOKEN": "env-secret"] },
            keychainToken: { "keychain-secret" },
            launchctlToken: { nil },
            homeDirectory: try temporaryHome())

        let summaries = try discovery.sourceSummaries()

        XCTAssertEqual(summaries.first?.source.kind, .environment)
        XCTAssertEqual(summaries.first?.isActive, true)
        XCTAssertEqual(summaries.first(where: { $0.source.kind == .keychain })?.isAvailable, true)
        XCTAssertEqual(summaries.first(where: { $0.source.kind == .keychain })?.isActive, false)
    }

    func testTokenAssignmentParserHandlesCommonShellForms() {
        XCTAssertEqual(OuraTokenDiscovery.parseTokenAssignment(in: "export OURA_TOKEN=plain"), "plain")
        XCTAssertEqual(OuraTokenDiscovery.parseTokenAssignment(in: #"OURA_TOKEN="quoted value""#), "quoted value")
        XCTAssertEqual(OuraTokenDiscovery.parseTokenAssignment(in: "set -gx OURA_TOKEN fish-token"), "fish-token")
        XCTAssertNil(OuraTokenDiscovery.parseTokenAssignment(in: "# OURA_TOKEN=ignored"))
    }

    private func makeClient(token: String) -> OuraClient {
        makeClient { token }
    }

    private func makeClient(tokenProvider: @escaping OuraTokenProvider) -> OuraClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return OuraClient(baseURL: URL(string: "https://api.ouraring.test")!, session: session, tokenProvider: tokenProvider)
    }

    private func temporaryConfigURL(contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OuraKitTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(".oura-mcp", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("config.json")
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func temporaryHome() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OuraKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private actor TokenCounter {
    private(set) var count = 0

    func next() -> String {
        count += 1
        return "token-\(count)"
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response {
        let status: Int
        let body: Data
    }

    private static let lock = NSLock()
    private static var responseQueue: [Response] = []
    private static var recordedRequests: [URLRequest] = []

    static var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    static func enqueue(status: Int, body: String) {
        lock.lock()
        defer { lock.unlock() }
        responseQueue.append(Response(status: status, body: Data(body.utf8)))
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        responseQueue = []
        recordedRequests = []
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response: Response = Self.lock.withLock {
            Self.recordedRequests.append(request)
            return Self.responseQueue.isEmpty
            ? Response(status: 500, body: Data())
            : Self.responseQueue.removeFirst()
        }
        let http = HTTPURLResponse(
            url: request.url!,
            statusCode: response.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
