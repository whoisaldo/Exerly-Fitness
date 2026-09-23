import Foundation
import Security

struct SessionCredentialSnapshot {
    let token: String
    let refreshToken: String?
}

protocol SessionCredentials: AnyObject {
    @discardableResult func saveToken(_ token: String) -> Bool
    @discardableResult func saveSession(token: String, refreshToken: String?) -> Bool
    @discardableResult func replaceSession(expectedToken: String, expectedRefreshToken: String?, token: String, refreshToken: String) -> Bool
    func getToken() -> String?
    func getRefreshToken() -> String?
    func sessionSnapshot() -> SessionCredentialSnapshot?
    func deleteToken()
}

final class KeychainService: SessionCredentials {
    static let shared: KeychainService = {
        #if DEBUG
        if let id = ProcessInfo.processInfo.environment["EXERLY_TEST_STORE_ID"], UUID(uuidString: id) != nil {
            return KeychainService(tokenKey: "com.exerly.simulator.\(id)")
        }
        #endif
        return KeychainService()
    }()
    private let tokenKey: String
    private let lock = NSRecursiveLock()
    private struct Credentials: Codable {
        let token: String
        let refreshToken: String?
    }
    init(tokenKey: String = "com.exerly.jwt") { self.tokenKey = tokenKey }

    @discardableResult
    func saveToken(_ token: String) -> Bool { saveSession(token: token, refreshToken: nil) }

    @discardableResult
    func saveSession(token: String, refreshToken: String?) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(Credentials(token: token, refreshToken: refreshToken)) else { return false }
        let identity: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: tokenKey]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        // Both credentials change atomically. A storage failure preserves the
        // previous pair and its durable refresh operation can be retried.
        let updated = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
        if updated == errSecItemNotFound {
            return SecItemAdd(identity.merging(attributes) { _, value in value } as CFDictionary, nil) == errSecSuccess
        }
        return updated == errSecSuccess
    }

    @discardableResult
    func replaceSession(expectedToken: String, expectedRefreshToken: String?, token: String, refreshToken: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard getToken() == expectedToken, getRefreshToken() == expectedRefreshToken else { return false }
        return saveSession(token: token, refreshToken: refreshToken)
    }

    private func read() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
    func getToken() -> String? {
        lock.lock(); defer { lock.unlock() }
        guard let data = read() else { return nil }
        if let credentials = try? JSONDecoder().decode(Credentials.self, from: data) { return credentials.token }
        return String(data: data, encoding: .utf8) // Existing raw-token Keychain entry.
    }
    func getRefreshToken() -> String? {
        lock.lock(); defer { lock.unlock() }
        guard let data = read() else { return nil }
        return (try? JSONDecoder().decode(Credentials.self, from: data))?.refreshToken
    }
    func sessionSnapshot() -> SessionCredentialSnapshot? {
        lock.lock(); defer { lock.unlock() }
        guard let token = getToken() else { return nil }
        return SessionCredentialSnapshot(token: token, refreshToken: getRefreshToken())
    }
    func deleteToken() {
        lock.lock(); defer { lock.unlock() }
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: tokenKey] as CFDictionary)
    }
}
