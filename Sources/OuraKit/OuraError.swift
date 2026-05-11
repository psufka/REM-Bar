import Foundation

public enum OuraError: Error, Equatable, LocalizedError {
    case missingToken
    case invalidToken
    case rateLimited
    case badStatus(Int, String)
    case network(String)
    case decode(String)
    case keychain(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .missingToken:
            return "No Oura token is configured."
        case .invalidToken:
            return "The Oura token is invalid."
        case .rateLimited:
            return "Oura API rate limit exceeded."
        case let .badStatus(status, body):
            return "Oura API returned HTTP \(status): \(body)"
        case let .network(message):
            return message
        case let .decode(message):
            return message
        case let .keychain(status):
            return "Keychain error \(status)."
        }
    }
}
