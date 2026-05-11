import Foundation
import Security

public final class KeychainStore: @unchecked Sendable {
    public static let service = "com.psufka.REM-Bar"
    public static let shared = KeychainStore()

    private let serviceName: String
    private let account: String

    public init(serviceName: String = KeychainStore.service, account: String = "oura-token") {
        self.serviceName = serviceName
        self.account = account
    }

    public func readToken() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw OuraError.keychain(status)
        }
        guard let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public func saveToken(_ token: String) throws {
        try deleteToken(ignoreMissing: true)
        var query = baseQuery()
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw OuraError.keychain(status)
        }
    }

    public func deleteToken() throws {
        try deleteToken(ignoreMissing: false)
    }

    private func deleteToken(ignoreMissing: Bool) throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        if status == errSecItemNotFound, ignoreMissing {
            return
        }
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw OuraError.keychain(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
        ]
    }
}
