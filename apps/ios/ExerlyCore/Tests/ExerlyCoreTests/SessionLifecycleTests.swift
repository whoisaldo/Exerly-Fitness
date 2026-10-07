import Foundation
import Testing
@testable import ExerlyCore

/// Holds chosen requests until the test releases them, so a sign-out, a
/// sign-in or a shutdown can happen while they are in flight. Requests on a
/// path queue up and are released oldest first.
final class GatedTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var held: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var watchers: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var log: [String] = []
    private var isOpen = false
    let gatedPaths: Set<String>
    let handler: @Sendable (String, URLRequest) -> (Int, Any?)

    init(gating paths: Set<String>, handler: @escaping @Sendable (String, URLRequest) -> (Int, Any?)) {
        gatedPaths = paths
        self.handler = handler
    }

    var paths: [String] { lock.withLock { log } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var path = request.url!.path
        if let query = request.url!.query { path += "?\(query)" }
        let gated = lock.withLock { () -> Bool in
            log.append(path)
            return !isOpen && gatedPaths.contains(path)
        }
        if gated {
            await withCheckedContinuation { continuation in
                let ready = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
                    held[path, default: []].append(continuation)
                    return watchers.removeValue(forKey: path) ?? []
                }
                ready.forEach { $0.resume() }
            }
        }
        let (status, json) = handler(path, request)
        let data = try json.map { try JSONSerialization.data(withJSONObject: $0) } ?? Data()
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    /// Returns once a request for `path` is being held.
    func waitUntilHeld(_ path: String) async {
        await withCheckedContinuation { continuation in
            let ready = lock.withLock { () -> Bool in
                if !(held[path] ?? []).isEmpty { return true }
                watchers[path, default: []].append(continuation)
                return false
            }
            if ready { continuation.resume() }
        }
    }

    /// Lets the oldest held request for `path` continue.
    func release(_ path: String) {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Never>? in
            guard var queue = held[path], !queue.isEmpty else { return nil }
            let first = queue.removeFirst()
            held[path] = queue
            return first
        }
        continuation?.resume()
    }

    /// Stops holding requests and releases every held one.
    func open() {
        let all = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
            isOpen = true
            defer { held = [:] }
            return held.values.flatMap { $0 }
        }
        all.forEach { $0.resume() }
    }
}

private let accountA = "4f9e1c3a-0000-4000-8000-000000000001"
private let accountB = "4f9e1c3a-0000-4000-8000-000000000002"

private func session(_ token: String, refresh: String, account: String) -> [String: Any] {
    ["token": token, "refreshToken": refresh, "expiresIn": 900, "sessionId": "8e7c0d2a-1111-4111-8111-00000000000\(token.count)",
     "user": ["_id": account, "email": "\(account.suffix(1))@exerly.test"]]
}

private var emptyPage: [String: Any] { ["changes": [], "cursor": 0, "has_more": false] }

@Suite struct SessionLifecycleTests {
    let base = URL(string: "https://api.exerly.test")!
    let start = Date.milliseconds(1_791_223_200_000)

    func expired(_ account: String = accountA) -> Credentials {
        Credentials(accessToken: "old", refreshToken: "refresh-1", accessExpiresAt: start, sessionID: "s", accountID: account)
    }

    func fresh(_ account: String = accountA) -> Credentials {
        Credentials(accessToken: "valid", refreshToken: "refresh-1", accessExpiresAt: start.addingTimeInterval(600),
                    sessionID: "s", accountID: account)
    }

    @Test func aRefreshThatFinishesAfterSignOutSavesNothing() async throws {
        let store = InMemoryCredentialStore(expired())
        let transport = GatedTransport(gating: ["/auth/token"]) { path, _ in
            path == "/auth/token" ? (200, session("rotated", refresh: "refresh-2", account: accountA)) : (200, emptyPage)
        }
        let start = self.start
        let api = ExerlyAPI(baseURL: base, transport: transport, credentials: store, now: { start })
        let account = try await api.account()
        let read = Task { try await account.changes(after: 0) }
        await transport.waitUntilHeld("/auth/token")
        let signOut = Task { try await api.signOut() }
        // Sign-out forgets the session before it contacts the server.
        while try store.load() != nil { await Task.yield() }
        transport.release("/auth/token")
        await #expect(throws: APIError.accountChanged) { try await read.value }
        transport.open()
        try await signOut.value
        #expect(try store.load() == nil)
        #expect(!transport.paths.contains("/v1/changes?after=0&limit=500"))
    }

    @Test func aRefreshThatFinishesAfterANewerSignInKeepsTheNewerSession() async throws {
        let store = InMemoryCredentialStore(expired())
        let transport = GatedTransport(gating: ["/auth/token"]) { path, _ in
            switch path {
            case "/auth/token": (200, session("rotated", refresh: "refresh-2", account: accountA))
            case "/login": (200, session("other", refresh: "refresh-b", account: accountB))
            default: (200, emptyPage)
            }
        }
        let start = self.start
        let api = ExerlyAPI(baseURL: base, transport: transport, credentials: store, now: { start })
        let account = try await api.account()
        let read = Task { try await account.changes(after: 0) }
        await transport.waitUntilHeld("/auth/token")
        _ = try await api.signIn(email: "b@exerly.test", password: "synthetic-password")
        transport.release("/auth/token")
        await #expect(throws: APIError.accountChanged) { try await read.value }
        let saved = try #require(try store.load())
        #expect(saved.accountID == accountB && saved.accessToken == "other")
    }

    @Test func aResponseThatArrivesAfterSignOutIsNotReturned() async throws {
        let store = InMemoryCredentialStore(fresh())
        let transport = GatedTransport(gating: ["/v1/changes?after=0&limit=500"]) { _, _ in (200, emptyPage) }
        let start = self.start
        let api = ExerlyAPI(baseURL: base, transport: transport, credentials: store, now: { start })
        let account = try await api.account()
        let read = Task { try await account.changes(after: 0) }
        await transport.waitUntilHeld("/v1/changes?after=0&limit=500")
        try await api.signOut()
        transport.release("/v1/changes?after=0&limit=500")
        await #expect(throws: APIError.accountChanged) { try await read.value }
    }

    @Test func aSignInThatFinishesAfterSignOutIsDiscarded() async throws {
        let store = InMemoryCredentialStore()
        let transport = GatedTransport(gating: ["/login"]) { _, _ in (200, session("late", refresh: "refresh-l", account: accountA)) }
        let start = self.start
        let api = ExerlyAPI(baseURL: base, transport: transport, credentials: store, now: { start })
        let signIn = Task { try await api.signIn(email: "a@exerly.test", password: "synthetic-password") }
        await transport.waitUntilHeld("/login")
        try await api.signOut()
        transport.release("/login")
        await #expect(throws: APIError.accountChanged) { try await signIn.value }
        #expect(try store.load() == nil)
    }

    @Test func anAccountBoundClientRefusesAnotherAccountsSession() async throws {
        let store = InMemoryCredentialStore(fresh(accountB))
        let transport = GatedTransport(gating: []) { _, _ in (200, emptyPage) }
        let start = self.start
        let api = ExerlyAPI(baseURL: base, transport: transport, credentials: store, now: { start })
        let stale = AccountAPI(accountID: accountA, transport: api)
        await #expect(throws: APIError.accountChanged) { try await stale.changes(after: 0) }
        #expect(transport.paths.isEmpty)
    }

    @Test func signingOutWithAnExpiredTokenStillRevokesTheSession() async throws {
        let store = InMemoryCredentialStore(expired())
        let transport = GatedTransport(gating: []) { path, request in
            switch path {
            case "/auth/token": return (200, session("revoker", refresh: "refresh-2", account: accountA))
            default:
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer revoker")
                return (200, ["message": "Signed out"])
            }
        }
        let start = self.start
        let api = ExerlyAPI(baseURL: base, transport: transport, credentials: store, now: { start })
        try await api.signOut()
        #expect(transport.paths == ["/auth/token", "/auth/logout"])
        #expect(try store.load() == nil)
        #expect(try store.loadPendingRefreshKey() == nil)
    }
}

/// A document server whose change feed can be held mid-request.
final class GatedDocumentAPI: DocumentAPI, @unchecked Sendable {
    let inner: FakeDocumentServer
    let gate: GatedTransport
    init(_ inner: FakeDocumentServer) {
        self.inner = inner
        gate = GatedTransport(gating: ["/changes"]) { _, _ in (200, nil) }
    }

    func putDocument(kind: String, id: String, payload: Data, baseRevision: Int, idempotencyKey: String) async throws -> DocumentWriteResult {
        try await inner.putDocument(kind: kind, id: id, payload: payload, baseRevision: baseRevision, idempotencyKey: idempotencyKey)
    }

    func deleteDocument(kind: String, id: String, baseRevision: Int, idempotencyKey: String) async throws -> DocumentWriteResult {
        try await inner.deleteDocument(kind: kind, id: id, baseRevision: baseRevision, idempotencyKey: idempotencyKey)
    }

    func changes(after cursor: Int, limit: Int) async throws -> ChangePage {
        let page = try await inner.changes(after: cursor, limit: limit)
        _ = try await gate.send(URLRequest(url: URL(string: "https://gate.exerly.test/changes")!))
        return page
    }
}

@MainActor
@Suite struct SyncShutdownTests {
    /// A server holding one finished session, logged from another device.
    private func serverWithOneSession() async throws -> FakeDocumentServer {
        let server = FakeDocumentServer()
        let phone = try Device(server: server)
        try phone.store.startSession(name: "Legs", bodyweight: .kg(80))
        try phone.store.addExercise("back-squat")
        try phone.logSet(reps: 5, kg: 100)
        try phone.store.finishSession()
        try await phone.engine.sync()
        return server
    }

    @Test func shutdownDuringAPullWritesNothingAndRefusesLaterSyncs() async throws {
        let gated = GatedDocumentAPI(try await serverWithOneSession())
        let persistence = InMemoryTrainingPersistence()
        let store = try TrainingStore(persistence: persistence)
        let engine = SyncEngine(store: store, state: persistence, api: gated)
        let run = Task { try await engine.sync() }
        await gated.gate.waitUntilHeld("/changes")
        let stopped = Task { await engine.shutdown() }
        while !engine.isShutDown { await Task.yield() }
        gated.gate.open()
        await stopped.value
        await #expect(throws: CancellationError.self) { try await run.value }
        #expect(store.history.sessions.isEmpty)
        #expect(try persistence.syncCursor() == 0)
        await #expect(throws: CancellationError.self) { try await engine.sync() }
        #expect(engine.state == .idle)
    }

    @Test func cancellingTheCallerCancelsTheRun() async throws {
        let gated = GatedDocumentAPI(try await serverWithOneSession())
        let persistence = InMemoryTrainingPersistence()
        let store = try TrainingStore(persistence: persistence)
        let engine = SyncEngine(store: store, state: persistence, api: gated)
        let run = Task { try await engine.sync() }
        await gated.gate.waitUntilHeld("/changes")
        run.cancel()
        gated.gate.release("/changes")
        await #expect(throws: CancellationError.self) { try await run.value }
        #expect(store.history.sessions.isEmpty)
        // The engine wasn't shut down, so a later sync pulls normally.
        gated.gate.open()
        try await engine.sync()
        #expect(store.history.sessions.count == 1)
    }
}
