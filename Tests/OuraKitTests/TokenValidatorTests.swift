import Foundation
import XCTest
@testable import OuraKit

final class TokenValidatorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ValidatorStubURLProtocol.reset()
    }

    func testAcceptsTokenWhenPersonalInfoRequestSucceeds() async {
        ValidatorStubURLProtocol.enqueue(status: 200, body: #"{"id":"user-123","email":"paul@example.com"}"#)
        let validator = TokenValidator(baseURL: URL(string: "https://api.ouraring.test")!, session: makeSession())

        let result = await validator.validate(token: " token-123 ")

        XCTAssertEqual(result, .valid)
        XCTAssertEqual(ValidatorStubURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer token-123")
        XCTAssertEqual(ValidatorStubURLProtocol.requests.first?.url?.path, "/v2/usercollection/personal_info")
    }

    func testRejectsTokenWhenPersonalInfoReturnsUnauthorized() async {
        ValidatorStubURLProtocol.enqueue(status: 401, body: #"{"status":401,"title":"Invalid Access Token"}"#)
        ValidatorStubURLProtocol.enqueue(status: 401, body: #"{"status":401,"title":"Invalid Access Token"}"#)
        let validator = TokenValidator(baseURL: URL(string: "https://api.ouraring.test")!, session: makeSession())

        let result = await validator.validate(token: "bad-token")

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.message, "Token invalid.")
        XCTAssertEqual(ValidatorStubURLProtocol.requests.count, 2)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ValidatorStubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class ValidatorStubURLProtocol: URLProtocol, @unchecked Sendable {
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
        Self.lock.lock()
        Self.recordedRequests.append(request)
        let response = Self.responseQueue.isEmpty
            ? Response(status: 500, body: Data())
            : Self.responseQueue.removeFirst()
        Self.lock.unlock()

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
