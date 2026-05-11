import Foundation
import Testing
@testable import OuraKit

struct ClientTests {
    init() {
        StubURLProtocol.reset()
    }

    @Test func personalInfoRequestUsesBearerToken() async throws {
        StubURLProtocol.enqueue(status: 200, body: #"{"id":"user-123","email":"paul@example.com"}"#)
        let client = makeClient(token: "test-token")

        let info = try await client.personalInfo()

        #expect(info.email == "paul@example.com")
        #expect(StubURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(StubURLProtocol.requests.first?.url?.path == "/v2/usercollection/personal_info")
    }

    @Test func dailySleepAddsDateQueryItems() async throws {
        StubURLProtocol.enqueue(status: 200, body: #"{"data":[]}"#)
        let client = makeClient(token: "test-token")

        _ = try await client.dailySleep(startDate: "2026-05-01", endDate: "2026-05-08")

        let requestURL = try #require(StubURLProtocol.requests.first?.url)
        let components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.contains(URLQueryItem(name: "start_date", value: "2026-05-01")) == true)
        #expect(components.queryItems?.contains(URLQueryItem(name: "end_date", value: "2026-05-08")) == true)
    }

    @Test func unauthorizedResponseReReadsTokenAndRetriesOnce() async throws {
        let provider = TokenCounter()
        StubURLProtocol.enqueue(status: 401, body: #"{"status":401,"title":"Invalid Access Token"}"#)
        StubURLProtocol.enqueue(status: 200, body: #"{"id":"user-123","email":"paul@example.com"}"#)
        let client = makeClient {
            await provider.next()
        }

        let info = try await client.personalInfo()

        #expect(info.email == "paul@example.com")
        #expect(await provider.count == 2)
        #expect(StubURLProtocol.requests.count == 2)
        #expect(StubURLProtocol.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer token-2")
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
