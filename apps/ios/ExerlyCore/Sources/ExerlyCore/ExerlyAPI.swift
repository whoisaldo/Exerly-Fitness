import Foundation

/// Sends one HTTP request. `URLSessionTransport` in the app; scripted in tests.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        return (data, http)
    }
}

public enum APIError: Error, Equatable {
    case notSignedIn
    /// The session can't be refreshed; sign in again.
    case sessionExpired
    /// An Exerly password account already uses this Apple ID's email.
    case linkRequired
    /// Account deletion needs a fresh Sign in with Apple authorization code.
    case appleReauthorizationRequired
    case invalidResponse
    case server(status: Int, message: String)
}

public struct AccountSummary: Sendable, Hashable {
    public var id: String
    public var email: String
    public var name: String?
}

public struct SignInResult: Sendable, Hashable {
    public var created: Bool
    public var account: AccountSummary
}

/// A document as the server holds it. `payload` is nil for a tombstone.
public struct RemoteDocument: Sendable, Hashable {
    public var kind: String
    public var id: String
    public var revision: Int
    public var deleted: Bool
    public var payload: Data?
    public var sequence: Int?
}

public enum DocumentWriteResult: Sendable, Hashable {
    case applied(revision: Int)
    /// The base revision was stale. The current document, or nil if it no longer exists.
    case conflict(RemoteDocument?)
}

public struct ChangePage: Sendable, Hashable {
    public var changes: [RemoteDocument]
    public var cursor: Int
    public var hasMore: Bool
}

/// The Exerly API client. Keeps the session fresh: refreshes shortly before
/// the access token expires and once after a 401. A refresh keeps its
/// idempotency key in the credential store until the rotated credential is
/// saved, so a lost response is retried rather than burning the session.
public actor ExerlyAPI {
    private let baseURL: URL
    private let transport: HTTPTransport
    private let credentials: CredentialStore
    private let now: @Sendable () -> Date
    private var refreshing: Task<Credentials, Error>?

    public init(baseURL: URL, transport: HTTPTransport = URLSessionTransport(), credentials: CredentialStore,
                now: @escaping @Sendable () -> Date = Date.init) {
        self.baseURL = baseURL
        self.transport = transport
        self.credentials = credentials
        self.now = now
    }

    public var isSignedIn: Bool { (try? credentials.load()) != nil }

    public var accountID: String? { (try? credentials.load())?.accountID }

    // MARK: Signing in and out

    public func signInWithApple(identityToken: String, rawNonce: String, name: String?, timeZone: TimeZone,
                                unitSystem: String?) async throws -> SignInResult {
        var body: [String: Any] = ["identityToken": identityToken, "nonce": rawNonce, "timezone": timeZone.identifier]
        if let name, !name.isEmpty { body["name"] = name }
        if let unitSystem { body["unitSystem"] = unitSystem }
        return try await startSession(path: "/auth/apple", body: body)
    }

    public func signIn(email: String, password: String) async throws -> SignInResult {
        try await startSession(path: "/login", body: ["email": email, "password": password])
    }

    /// Revokes the session on the server when reachable, and always forgets it locally.
    public func signOut() async throws {
        if isSignedIn { _ = try? await authorized("POST", "/auth/logout", body: [:]) }
        try credentials.save(nil)
        try credentials.savePendingRefreshKey(nil)
    }

    /// Deletes the account and everything in it, then forgets the session.
    public func deleteAccount(appleAuthorizationCode: String?) async throws {
        var body: [String: Any] = ["confirm": true]
        if let appleAuthorizationCode { body["appleAuthorizationCode"] = appleAuthorizationCode }
        let (status, json) = try await authorized("DELETE", "/api/account", body: body)
        guard status == 200 else {
            if status == 400, Self.code(json) == "apple_reauthorization_required" {
                throw APIError.appleReauthorizationRequired
            }
            throw Self.failure(status, json)
        }
        try credentials.save(nil)
        try credentials.savePendingRefreshKey(nil)
    }

    /// The full JSON export.
    public func exportAccount() async throws -> Data {
        let (status, data) = try await authorizedData("GET", "/api/export", body: nil)
        guard status == 200 else { throw Self.failure(status, try? JSONSerialization.jsonObject(with: data)) }
        return data
    }

    // MARK: Documents

    public func putDocument(kind: String, id: String, payload: Data, baseRevision: Int,
                            idempotencyKey: String) async throws -> DocumentWriteResult {
        var body = Data(#"{"base_revision":\#(baseRevision),"payload":"#.utf8)
        body.append(payload)
        body.append(Data("}".utf8))
        let (status, data) = try await authorizedData("PUT", "/v1/documents/\(kind)/\(id)", rawBody: body,
                                                      headers: ["Idempotency-Key": idempotencyKey])
        return try Self.writeResult(status, data)
    }

    public func deleteDocument(kind: String, id: String, baseRevision: Int,
                               idempotencyKey: String) async throws -> DocumentWriteResult {
        let (status, data) = try await authorizedData("DELETE", "/v1/documents/\(kind)/\(id)?base_revision=\(baseRevision)",
                                                      body: nil, headers: ["Idempotency-Key": idempotencyKey])
        return try Self.writeResult(status, data)
    }

    public func changes(after cursor: Int, limit: Int = 500) async throws -> ChangePage {
        let (status, data) = try await authorizedData("GET", "/v1/changes?after=\(cursor)&limit=\(limit)", body: nil)
        guard status == 200, let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let changes = json["changes"] as? [[String: Any]], let next = json["cursor"] as? Int
        else { throw Self.failure(status, try? JSONSerialization.jsonObject(with: data)) }
        return ChangePage(changes: try changes.map(Self.document), cursor: next, hasMore: json["has_more"] as? Bool ?? false)
    }

    // MARK: Sessions

    private func startSession(path: String, body: [String: Any]) async throws -> SignInResult {
        let (status, data) = try await send("POST", path, body: try JSONSerialization.data(withJSONObject: body),
                                            headers: ["X-Session-Protocol": "2"], token: nil)
        let json = try? JSONSerialization.jsonObject(with: data)
        guard status == 200 || status == 201 else {
            if status == 409, Self.code(json) == "link_required" { throw APIError.linkRequired }
            throw Self.failure(status, json)
        }
        let (saved, account) = try Self.session(from: json, issuedAt: now())
        try credentials.save(saved)
        try credentials.savePendingRefreshKey(nil)
        return SignInResult(created: (json as? [String: Any])?["created"] as? Bool ?? (status == 201), account: account)
    }

    private func freshCredentials(forceRefresh: Bool) async throws -> Credentials {
        guard let current = try credentials.load() else { throw APIError.notSignedIn }
        if !forceRefresh && current.accessExpiresAt.timeIntervalSince(now()) > 30 { return current }
        if let refreshing { return try await refreshing.value }
        let task = Task { try await self.refresh(current) }
        refreshing = task
        defer { refreshing = nil }
        return try await task.value
    }

    private func refresh(_ current: Credentials) async throws -> Credentials {
        let key = try credentials.loadPendingRefreshKey() ?? UUID().uuidString
        try credentials.savePendingRefreshKey(key)
        let body = try JSONSerialization.data(withJSONObject: ["refreshToken": current.refreshToken])
        let (status, data) = try await send("POST", "/auth/token", body: body, headers: ["Idempotency-Key": key], token: nil)
        let json = try? JSONSerialization.jsonObject(with: data)
        if status == 401 {
            try credentials.save(nil)
            try credentials.savePendingRefreshKey(nil)
            throw APIError.sessionExpired
        }
        guard status == 200 else { throw Self.failure(status, json) }
        var (rotated, _) = try Self.session(from: json, issuedAt: now())
        rotated.accountID = current.accountID
        try credentials.save(rotated)
        try credentials.savePendingRefreshKey(nil)
        return rotated
    }

    // MARK: Requests

    private func authorized(_ method: String, _ path: String, body: [String: Any]?) async throws -> (Int, Any?) {
        let (status, data) = try await authorizedData(method, path, body: body)
        return (status, try? JSONSerialization.jsonObject(with: data))
    }

    private func authorizedData(_ method: String, _ path: String, body: [String: Any]?,
                                headers: [String: String] = [:]) async throws -> (Int, Data) {
        try await authorizedData(method, path, rawBody: try body.map { try JSONSerialization.data(withJSONObject: $0) },
                                 headers: headers)
    }

    private func authorizedData(_ method: String, _ path: String, rawBody: Data?,
                                headers: [String: String] = [:]) async throws -> (Int, Data) {
        var token = try await freshCredentials(forceRefresh: false).accessToken
        for attempt in 0..<2 {
            let (status, data) = try await send(method, path, body: rawBody, headers: headers, token: token)
            if status != 401 || attempt == 1 {
                if status == 401 { throw APIError.sessionExpired }
                return (status, data)
            }
            token = try await freshCredentials(forceRefresh: true).accessToken
        }
        throw APIError.sessionExpired
    }

    private func send(_ method: String, _ path: String, body: Data?, headers: [String: String],
                      token: String?) async throws -> (Int, Data) {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(TimeZone.current.identifier, forHTTPHeaderField: "X-Timezone")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        let (data, response) = try await transport.send(request)
        return (response.statusCode, data)
    }

    // MARK: Parsing

    private static func session(from json: Any?, issuedAt: Date) throws -> (Credentials, AccountSummary) {
        guard let json = json as? [String: Any], let token = json["token"] as? String,
              let refresh = json["refreshToken"] as? String, let expiresIn = json["expiresIn"] as? Int,
              let sessionID = json["sessionId"] as? String, let user = json["user"] as? [String: Any],
              let id = user["_id"] as? String, let email = user["email"] as? String
        else { throw APIError.invalidResponse }
        let credentials = Credentials(accessToken: token, refreshToken: refresh,
                                      accessExpiresAt: issuedAt.addingTimeInterval(Double(expiresIn)),
                                      sessionID: sessionID, accountID: id)
        return (credentials, AccountSummary(id: id, email: email, name: user["name"] as? String))
    }

    private static func document(_ json: [String: Any]) throws -> RemoteDocument {
        guard let kind = json["kind"] as? String, let id = json["id"] as? String,
              let revision = json["revision"] as? Int, let deleted = json["deleted"] as? Bool
        else { throw APIError.invalidResponse }
        let payload = try (json["payload"] as? [String: Any]).map { try JSONSerialization.data(withJSONObject: $0) }
        return RemoteDocument(kind: kind, id: id, revision: revision, deleted: deleted, payload: payload,
                              sequence: json["sequence"] as? Int)
    }

    private static func writeResult(_ status: Int, _ data: Data) throws -> DocumentWriteResult {
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        switch status {
        case 200, 201:
            guard let revision = json?["revision"] as? Int else { throw APIError.invalidResponse }
            return .applied(revision: revision)
        case 409:
            let current = (json?["details"] as? [String: Any])?["document"] as? [String: Any]
            return .conflict(try current.map(document))
        default:
            throw failure(status, json)
        }
    }

    private static func code(_ json: Any?) -> String? {
        ((json as? [String: Any])?["details"] as? [String: Any])?["code"] as? String
    }

    private static func failure(_ status: Int, _ json: Any?) -> APIError {
        .server(status: status, message: (json as? [String: Any])?["message"] as? String ?? "HTTP \(status)")
    }
}
