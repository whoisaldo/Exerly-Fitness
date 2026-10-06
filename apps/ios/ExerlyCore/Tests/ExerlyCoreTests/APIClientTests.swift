import Foundation
import Testing
@testable import ExerlyCore

/// Scripted HTTP: each request is recorded and answered by the handler.
final class FakeTransport: HTTPTransport, @unchecked Sendable {
    struct Recorded {
        var method: String
        var path: String
        var headers: [String: String]
        var body: [String: Any]?
    }

    private let lock = NSLock()
    private var log: [Recorded] = []
    var handler: (Recorded) throws -> (Int, Any?)

    init(handler: @escaping (Recorded) throws -> (Int, Any?)) {
        self.handler = handler
    }

    var requests: [Recorded] { lock.withLock { log } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let body = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        var path = request.url!.path
        if let query = request.url!.query { path += "?\(query)" }
        let recorded = Recorded(method: request.httpMethod ?? "GET", path: path,
                                headers: request.allHTTPHeaderFields ?? [:], body: body)
        lock.withLock { log.append(recorded) }
        let (status, json) = try handler(recorded)
        let data = try json.map { try JSONSerialization.data(withJSONObject: $0) } ?? Data()
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

struct Offline: Error {}

func sessionJSON(_ token: String, refresh: String = "refresh-1", created: Bool? = nil) -> [String: Any] {
    var json: [String: Any] = [
        "token": token, "refreshToken": refresh, "expiresIn": 900, "sessionId": "8e7c0d2a-1111-4111-8111-000000000001",
        "user": ["_id": "4f9e1c3a-0000-4000-8000-000000000001", "email": "person@exerly.test", "name": "Synthetic"],
    ]
    if let created { json["created"] = created }
    return json
}

@Suite struct APIClientTests {
    let base = URL(string: "https://api.exerly.test")!
    let start = Date.milliseconds(1_791_223_200_000)

    func client(_ transport: FakeTransport, store: InMemoryCredentialStore = InMemoryCredentialStore(),
                clock: @escaping @Sendable () -> Date) -> ExerlyAPI {
        ExerlyAPI(baseURL: base, transport: transport, credentials: store, now: clock)
    }

    @Test func signsInWithAppleAndStoresTheSession() async throws {
        let transport = FakeTransport { request in
            #expect(request.method == "POST" && request.path == "/auth/apple")
            #expect(request.body?["identityToken"] as? String == "apple-jwt")
            #expect(request.body?["nonce"] as? String == "raw-nonce-0123456789")
            #expect(request.body?["timezone"] as? String == "Europe/London")
            #expect(request.headers["X-Session-Protocol"] == "2")
            return (201, sessionJSON("access-1", created: true))
        }
        let store = InMemoryCredentialStore()
        let start = self.start
        let api = client(transport, store: store, clock: { start })
        let result = try await api.signInWithApple(
            identityToken: "apple-jwt", rawNonce: "raw-nonce-0123456789", name: nil,
            timeZone: TimeZone(identifier: "Europe/London")!, unitSystem: nil
        )
        #expect(result.created)
        #expect(result.account.id == "4f9e1c3a-0000-4000-8000-000000000001")
        let saved = try #require(try store.load())
        #expect(saved.accessToken == "access-1")
        #expect(saved.refreshToken == "refresh-1")
        #expect(saved.accessExpiresAt == start.addingTimeInterval(900))
        #expect(await api.isSignedIn)
    }

    @Test func mapsLinkRequiredToATypedError() async throws {
        let transport = FakeTransport { _ in (409, ["message": "Link", "details": ["code": "link_required"]]) }
        let start = self.start
        let api = client(transport, clock: { start })
        await #expect(throws: APIError.linkRequired) {
            try await api.signInWithApple(identityToken: "t", rawNonce: "n", name: nil, timeZone: .current, unitSystem: nil)
        }
    }

    @Test func refreshesBeforeAnExpiredTokenIsUsed() async throws {
        let store = InMemoryCredentialStore()
        try store.save(Credentials(accessToken: "old", refreshToken: "refresh-1", accessExpiresAt: start.addingTimeInterval(10),
                                   sessionID: "s", accountID: "a"))
        let transport = FakeTransport { request in
            switch request.path {
            case "/auth/token":
                #expect(request.body?["refreshToken"] as? String == "refresh-1")
                #expect(request.headers["Idempotency-Key"] != nil)
                return (200, sessionJSON("new", refresh: "refresh-2"))
            default:
                #expect(request.headers["Authorization"] == "Bearer new")
                return (200, ["changes": [], "cursor": 0, "has_more": false])
            }
        }
        let start = self.start
        let api = client(transport, store: store, clock: { start })
        _ = try await api.account().changes(after: 0)
        #expect(transport.requests.map(\.path) == ["/auth/token", "/v1/changes?after=0&limit=500"])
        #expect(try store.load()?.refreshToken == "refresh-2")
        #expect(try store.loadPendingRefreshKey() == nil)
    }

    @Test func aLostRefreshResponseIsRetriedWithTheSameKey() async throws {
        let store = InMemoryCredentialStore()
        try store.save(Credentials(accessToken: "old", refreshToken: "refresh-1", accessExpiresAt: start, sessionID: "s", accountID: "a"))
        var attempts = 0
        var keys: [String] = []
        let transport = FakeTransport { request in
            if request.path == "/auth/token" {
                attempts += 1
                keys.append(request.headers["Idempotency-Key"] ?? "")
                if attempts == 1 { throw Offline() }
                return (200, sessionJSON("new", refresh: "refresh-2"))
            }
            return (200, ["changes": [], "cursor": 0, "has_more": false])
        }
        let start = self.start
        let api = client(transport, store: store, clock: { start })
        await #expect(throws: Offline.self) { try await api.account().changes(after: 0) }
        #expect(try store.loadPendingRefreshKey() == keys.first)
        _ = try await api.account().changes(after: 0)
        #expect(keys.count == 2 && keys[0] == keys[1])
        #expect(try store.loadPendingRefreshKey() == nil)
    }

    @Test func retriesOnceAfterA401AndSignsOutWhenRefreshIsRefused() async throws {
        let store = InMemoryCredentialStore()
        try store.save(Credentials(accessToken: "valid", refreshToken: "r", accessExpiresAt: start.addingTimeInterval(600),
                                   sessionID: "s", accountID: "a"))
        var refreshes = 0
        var reads = 0
        // Read 1 is refused, read 2 (after a refresh) succeeds, read 3 is
        // refused and the second refresh is refused too.
        let transport = FakeTransport { request in
            if request.path == "/auth/token" {
                refreshes += 1
                return refreshes == 1 ? (200, sessionJSON("fresh")) : (401, ["message": "Session expired"])
            }
            reads += 1
            #expect(reads == 1 || request.headers["Authorization"] == "Bearer fresh")
            return reads == 2
                ? (200, ["changes": [], "cursor": 3, "has_more": false])
                : (401, ["message": "Session has been revoked"])
        }
        let start = self.start
        let api = client(transport, store: store, clock: { start })
        #expect(try await api.account().changes(after: 0).cursor == 3)
        await #expect(throws: APIError.sessionExpired) { try await api.account().changes(after: 3) }
        #expect(try store.load() == nil)
        #expect(await !api.isSignedIn)
    }

    @Test func writesDocumentsAndReportsConflicts() async throws {
        let store = InMemoryCredentialStore()
        try store.save(Credentials(accessToken: "t", refreshToken: "r", accessExpiresAt: start.addingTimeInterval(600), sessionID: "s", accountID: "a"))
        let transport = FakeTransport { request in
            if request.method == "PUT" {
                #expect(request.path == "/v1/documents/workout_session/ABC")
                #expect(request.headers["Idempotency-Key"] == "key-123456")
                #expect(request.body?["base_revision"] as? Int == 2)
                #expect((request.body?["payload"] as? [String: Any])?["id"] as? String == "ABC")
                return (409, ["message": "Changed", "details": ["document": [
                    "kind": "workout_session", "id": "ABC", "revision": 3, "deleted": false,
                    "payload": ["id": "ABC", "notes": "remote"], "updated_at": "2026-10-05T18:00:00.000Z",
                ]]])
            }
            #expect(request.method == "DELETE" && request.path == "/v1/documents/workout_session/ABC?base_revision=3")
            return (200, ["kind": "workout_session", "id": "ABC", "revision": 4, "deleted": true, "updated_at": "2026-10-05T18:00:00.000Z"])
        }
        let start = self.start
        let api = client(transport, store: store, clock: { start })
        let result = try await api.account().putDocument(kind: "workout_session", id: "ABC", payload: Data(#"{"id":"ABC"}"#.utf8),
                                               baseRevision: 2, idempotencyKey: "key-123456")
        guard case .conflict(let remote?) = result else { Issue.record("expected a conflict"); return }
        #expect(remote.revision == 3)
        let payload = try JSONSerialization.jsonObject(with: try #require(remote.payload)) as? [String: Any]
        #expect(payload?["notes"] as? String == "remote")
        let deleted = try await api.account().deleteDocument(kind: "workout_session", id: "ABC", baseRevision: 3, idempotencyKey: "key-654321")
        #expect(deleted == .applied(revision: 4))
    }

    @Test func connectsAndDisconnectsApple() async throws {
        let store = InMemoryCredentialStore()
        try store.save(Credentials(accessToken: "t", refreshToken: "r", accessExpiresAt: start.addingTimeInterval(600), sessionID: "s", accountID: "a"))
        var conflict = false
        let transport = FakeTransport { request in
            #expect(request.path == "/api/account/identities/apple")
            if request.method == "POST" {
                #expect(request.body?["identityToken"] as? String == "jwt" && request.body?["nonce"] as? String == "raw")
                return conflict ? (409, ["message": "Taken"]) : (201, ["provider": "apple", "connected": true])
            }
            return (400, ["message": "Set a password before disconnecting Apple"])
        }
        let start = self.start
        let api = client(transport, store: store, clock: { start })
        try await api.account().connectApple(identityToken: "jwt", rawNonce: "raw")
        conflict = true
        await #expect(throws: APIError.linkConflict) { try await api.account().connectApple(identityToken: "jwt", rawNonce: "raw") }
        await #expect(throws: APIError.server(status: 400, message: "Set a password before disconnecting Apple")) {
            try await api.account().disconnectApple()
        }
    }

    @Test func deletesTheAccountAndForgetsTheSession() async throws {
        let store = InMemoryCredentialStore()
        try store.save(Credentials(accessToken: "t", refreshToken: "r", accessExpiresAt: start.addingTimeInterval(600), sessionID: "s", accountID: "a"))
        let transport = FakeTransport { request in
            #expect(request.method == "DELETE" && request.path == "/api/account")
            #expect(request.body?["confirm"] as? Bool == true)
            #expect(request.body?["appleAuthorizationCode"] as? String == "code")
            return (200, ["deleted": true, "apple_revoked": true, "removed": [:]])
        }
        let start = self.start
        let api = client(transport, store: store, clock: { start })
        try await api.deleteAccount(appleAuthorizationCode: "code")
        #expect(try store.load() == nil)
    }
}

@Suite struct AccountDeletedTests {
    let base = URL(string: "https://api.exerly.test")!
    let start = Date.milliseconds(1_791_223_200_000)

    func signedIn() throws -> InMemoryCredentialStore {
        let store = InMemoryCredentialStore()
        try store.save(Credentials(accessToken: "t", refreshToken: "r", accessExpiresAt: start.addingTimeInterval(600),
                                   sessionID: "s", accountID: "a"))
        return store
    }

    @Test func aDeletedAccountIsReportedWithoutARefreshAndForgotten() async throws {
        let store = try signedIn()
        let transport = FakeTransport { _ in (401, ["message": "This account was deleted.", "details": ["code": "account_deleted"]]) }
        let start = self.start
        let api = ExerlyAPI(baseURL: base, transport: transport, credentials: store, now: { start })
        await #expect(throws: APIError.accountDeleted) { try await api.account().changes(after: 0) }
        #expect(transport.requests.map(\.path) == ["/v1/changes?after=0&limit=500"])
        #expect(try store.load() == nil)
    }

    @Test func aDeletionWhoseResponseWasLostSucceedsOnRetry() async throws {
        let store = try signedIn()
        var attempts = 0
        let transport = FakeTransport { _ in
            attempts += 1
            if attempts == 1 { throw Offline() }
            return (401, ["message": "This account was deleted.", "details": ["code": "account_deleted"]])
        }
        let start = self.start
        let api = ExerlyAPI(baseURL: base, transport: transport, credentials: store, now: { start })
        await #expect(throws: Offline.self) { try await api.deleteAccount(appleAuthorizationCode: nil) }
        #expect(try store.load() != nil, "The outcome is unknown, so the session stays")
        try await api.deleteAccount(appleAuthorizationCode: nil)
        #expect(try store.load() == nil)
    }
}

#if os(iOS)
/// Host-less package tests have no Keychain entitlement (errSecMissingEntitlement,
/// -34018), so this runs only inside a host app: set EXERLY_KEYCHAIN_TESTS.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["EXERLY_KEYCHAIN_TESTS"] != nil))
struct KeychainCredentialStoreTests {
    @Test func storesReplacesAndRemovesTheSession() throws {
        let store = KeychainCredentialStore(service: "studio.sideband.exerly.tests.\(UUID().uuidString)")
        #expect(try store.load() == nil)
        let first = Credentials(accessToken: "a", refreshToken: "r", accessExpiresAt: .milliseconds(1_791_223_200_000),
                                sessionID: "s", accountID: "x")
        try store.save(first)
        #expect(try store.load() == first)
        var second = first
        second.refreshToken = "r2"
        try store.save(second)
        #expect(try store.load() == second)
        try store.savePendingRefreshKey("key-1")
        #expect(try store.loadPendingRefreshKey() == "key-1")
        try store.save(nil)
        try store.savePendingRefreshKey(nil)
        #expect(try store.load() == nil)
        #expect(try store.loadPendingRefreshKey() == nil)
    }
}
#endif
