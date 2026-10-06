import Foundation
import Security

/// A signed-in session.
public struct Credentials: Codable, Sendable, Hashable {
    public var accessToken: String
    public var refreshToken: String
    public var accessExpiresAt: Date
    public var sessionID: String
    public var accountID: String
}

/// Where the session lives between launches.
public protocol CredentialStore: Sendable {
    func load() throws -> Credentials?
    /// Saves, or removes when nil.
    func save(_ credentials: Credentials?) throws
    /// The idempotency key of a refresh whose response hasn't been stored yet.
    func loadPendingRefreshKey() throws -> String?
    func savePendingRefreshKey(_ key: String?) throws
}

public final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var credentials: Credentials?
    private var pendingKey: String?

    public init(_ credentials: Credentials? = nil) { self.credentials = credentials }

    public func load() throws -> Credentials? { lock.withLock { credentials } }
    public func save(_ credentials: Credentials?) throws { lock.withLock { self.credentials = credentials } }
    public func loadPendingRefreshKey() throws -> String? { lock.withLock { pendingKey } }
    public func savePendingRefreshKey(_ key: String?) throws { lock.withLock { pendingKey = key } }
}

/// The session in the Keychain, readable after first unlock (so background
/// sync works) and never migrated to another device.
public struct KeychainCredentialStore: CredentialStore {
    public struct Failure: Error, Equatable { public let status: OSStatus }

    private let service: String

    public init(service: String = "studio.sideband.exerly.session") { self.service = service }

    public func load() throws -> Credentials? {
        try read("credentials").map { try JSONDecoder().decode(Credentials.self, from: $0) }
    }

    public func save(_ credentials: Credentials?) throws {
        try write("credentials", try credentials.map { try JSONEncoder().encode($0) })
    }

    public func loadPendingRefreshKey() throws -> String? {
        try read("pending-refresh-key").flatMap { String(bytes: $0, encoding: .utf8) }
    }

    public func savePendingRefreshKey(_ key: String?) throws {
        try write("pending-refresh-key", key.map { Data($0.utf8) })
    }

    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    private func read(_ account: String) throws -> Data? {
        var query = query(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw Failure(status: status) }
        return result as? Data
    }

    /// Updates in place and adds only when missing, so a failed replacement
    /// keeps the previous credential or pending refresh key.
    private func write(_ account: String, _ data: Data?) throws {
        guard let data else {
            let deleted = SecItemDelete(query(account) as CFDictionary)
            guard deleted == errSecSuccess || deleted == errSecItemNotFound else { throw Failure(status: deleted) }
            return
        }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(query(account) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query(account).merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw Failure(status: status) }
    }
}
