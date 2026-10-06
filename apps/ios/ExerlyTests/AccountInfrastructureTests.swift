import XCTest
import Security
import ExerlyCore
@testable import Exerly

@MainActor
final class AccountInfrastructureTests: XCTestCase {
    func testCoreCredentialsPersistReplaceAndRemoveInHostedKeychain() throws {
        let service = "studio.sideband.exerly.hosted-tests.\(UUID().uuidString)"
        let store = KeychainCredentialStore(service: service)
        defer { try? store.save(nil); try? store.savePendingRefreshKey(nil) }
        XCTAssertNil(try store.load())
        let first = try JSONDecoder().decode(ExerlyCore.Credentials.self, from: Data(
            #"{"accessToken":"synthetic-access","refreshToken":"synthetic-refresh","accessExpiresAt":800000000,"sessionID":"session-a","accountID":"account-a"}"#.utf8))
        try store.save(first)
        XCTAssertEqual(try KeychainCredentialStore(service: service).load(), first)
        var second = first
        second.refreshToken = "synthetic-rotated"
        try store.save(second)
        XCTAssertEqual(try store.load(), second)
        try store.savePendingRefreshKey("pending-1")
        try store.savePendingRefreshKey("pending-2")
        XCTAssertEqual(try store.loadPendingRefreshKey(), "pending-2")

        var attributes: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service, kSecAttrAccount as String: "credentials",
                                   kSecReturnAttributes as String: true]
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &attributes), errSecSuccess)
        let values = try XCTUnwrap(attributes as? [String: Any])
        XCTAssertEqual(values[kSecAttrAccessible as String] as? String,
                       kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        XCTAssertNil(try KeychainCredentialStore(service: service + ".other").load())
        try store.save(nil)
        try store.savePendingRefreshKey(nil)
        XCTAssertNil(try store.load())
        XCTAssertNil(try store.loadPendingRefreshKey())
    }

    func testInternalTestAccountCompletesNativeSignInAndBootstrap() async throws {
        guard let path = ProcessInfo.processInfo.environment["EXERLY_ACCOUNT_SMOKE_PATH"] else {
            throw XCTSkip("Set EXERLY_ACCOUNT_SMOKE_PATH for the private TestFlight account smoke check")
        }
        struct Account: Decodable { let email: String; let password: String; let baseURL: String }
        let account = try JSONDecoder().decode(Account.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let configured = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "EXERLY_API_BASE_URL") as? String)
        XCTAssertEqual(configured, account.baseURL, "The tested app must target the account's backend")
        let namespace = "studio.sideband.exerly.live-account.\(UUID().uuidString)"
        let keychain = KeychainService(tokenKey: namespace)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: namespace))
        defer { keychain.deleteToken(); defaults.removePersistentDomain(forName: namespace) }
        let api = APIClient(baseURL: configured, keychain: keychain, defaults: defaults)
        let auth = AuthViewModel(api: api, keychain: keychain, defaults: defaults,
                                 automaticallyCheck: false, onSessionInvalidated: {})
        await auth.login(email: account.email, password: account.password)
        XCTAssertEqual(auth.authState, .authenticated, auth.error ?? "Sign-in did not finish")
        XCTAssertFalse(auth.isOffline)
        XCTAssertNotNil(auth.currentUser?.id)
        XCTAssertNotNil(keychain.getRefreshToken())
        if let token = keychain.getToken() { await api.revokeSession(accessToken: token) }
    }
}
