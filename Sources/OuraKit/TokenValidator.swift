import Foundation

public struct TokenValidationResult: Equatable, Sendable {
    public let isValid: Bool
    public let message: String?

    public static let valid = TokenValidationResult(isValid: true, message: nil)
}

public struct TokenValidator: Sendable {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = URL(string: "https://api.ouraring.com")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func validate(token: String) async -> TokenValidationResult {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return TokenValidationResult(isValid: false, message: "Token is empty.")
        }

        let client = OuraClient(baseURL: baseURL, session: session, tokenProvider: { trimmed })
        do {
            _ = try await client.personalInfo()
            return .valid
        } catch OuraError.invalidToken {
            return TokenValidationResult(isValid: false, message: "Token invalid.")
        } catch {
            return TokenValidationResult(isValid: false, message: error.localizedDescription)
        }
    }
}
