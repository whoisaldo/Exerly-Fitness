import Foundation

/// Sends requests with the signed-in session. An app has exactly one owner of
/// its session, which refreshes it and stores it; in the Exerly app that is
/// the legacy `APIClient`. `ExerlyAPI` is a standalone owner for tests,
/// scripts and future targets.
public protocol SessionTransport: Sendable {
    /// Sends one request as `accountID`, refreshing the session once after a 401.
    ///
    /// Throws `APIError.accountChanged` when the session doesn't belong to
    /// `accountID`, or is replaced or removed while the request is in flight,
    /// so nothing from such a response is applied. Throws `.sessionExpired` or
    /// `.notSignedIn` when there is no usable session. Network failures are
    /// thrown as they come from the transport.
    func send(_ method: String, path: String, body: Data?, headers: [String: String],
              as accountID: String) async throws -> (status: Int, data: Data)
}

/// One account's endpoints: documents and the account lifecycle. Every request
/// is bound to `accountID`, so work started for one account can never read or
/// write as another.
public struct AccountAPI: DocumentAPI {
    public let accountID: String
    private let transport: SessionTransport

    public init(accountID: String, transport: SessionTransport) {
        self.accountID = accountID
        self.transport = transport
    }

    // MARK: Documents

    public func putDocument(kind: String, id: String, payload: Data, baseRevision: Int,
                            idempotencyKey: String) async throws -> DocumentWriteResult {
        var body = Data(#"{"base_revision":\#(baseRevision),"payload":"#.utf8)
        body.append(payload)
        body.append(Data("}".utf8))
        let (status, data) = try await send("PUT", "/v1/documents/\(kind)/\(id)", body: body,
                                            headers: ["Idempotency-Key": idempotencyKey])
        return try Wire.writeResult(status, data)
    }

    public func deleteDocument(kind: String, id: String, baseRevision: Int,
                               idempotencyKey: String) async throws -> DocumentWriteResult {
        let (status, data) = try await send("DELETE", "/v1/documents/\(kind)/\(id)?base_revision=\(baseRevision)",
                                            headers: ["Idempotency-Key": idempotencyKey])
        return try Wire.writeResult(status, data)
    }

    public func changes(after cursor: Int, limit: Int = 500) async throws -> ChangePage {
        let (status, data) = try await send("GET", "/v1/changes?after=\(cursor)&limit=\(limit)")
        guard status == 200, let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let changes = json["changes"] as? [[String: Any]], let next = json["cursor"] as? Int
        else { throw Wire.failure(status, try? JSONSerialization.jsonObject(with: data)) }
        return ChangePage(changes: try changes.map(Wire.document), cursor: next, hasMore: json["has_more"] as? Bool ?? false)
    }

    // MARK: Account lifecycle

    /// Connects Sign in with Apple to this account. Throws `linkConflict`
    /// when that Apple ID belongs to another Exerly account.
    public func connectApple(identityToken: String, rawNonce: String) async throws {
        let (status, json) = try await sendJSON("POST", "/api/account/identities/apple",
                                                body: ["identityToken": identityToken, "nonce": rawNonce])
        if status == 409 { throw APIError.linkConflict }
        guard status == 200 || status == 201 else { throw Wire.failure(status, json) }
    }

    /// Disconnects Sign in with Apple. Refused for an account with no password,
    /// which could not sign in again.
    public func disconnectApple() async throws {
        let (status, json) = try await sendJSON("DELETE", "/api/account/identities/apple", body: nil)
        guard status == 200 else { throw Wire.failure(status, json) }
    }

    /// The full JSON export.
    public func exportAccount() async throws -> Data {
        let (status, data) = try await send("GET", "/api/export")
        guard status == 200 else { throw Wire.failure(status, try? JSONSerialization.jsonObject(with: data)) }
        return data
    }

    /// Deletes the account and everything in it on the server. Throws
    /// `appleReauthorizationRequired` when the server needs a fresh Sign in
    /// with Apple authorization code. The session owner then forgets the session.
    public func deleteAccount(appleAuthorizationCode: String?) async throws {
        var body: [String: Any] = ["confirm": true]
        if let appleAuthorizationCode { body["appleAuthorizationCode"] = appleAuthorizationCode }
        let (status, json) = try await sendJSON("DELETE", "/api/account", body: body)
        guard status == 200 else {
            if status == 400, Wire.code(json) == "apple_reauthorization_required" {
                throw APIError.appleReauthorizationRequired
            }
            throw Wire.failure(status, json)
        }
    }

    // MARK: Requests

    private func send(_ method: String, _ path: String, body: Data? = nil,
                      headers: [String: String] = [:]) async throws -> (Int, Data) {
        let (status, data) = try await transport.send(method, path: path, body: body, headers: headers, as: accountID)
        return (status, data)
    }

    private func sendJSON(_ method: String, _ path: String, body: [String: Any]?) async throws -> (Int, Any?) {
        let (status, data) = try await send(method, path, body: try body.map { try JSONSerialization.data(withJSONObject: $0) })
        return (status, try? JSONSerialization.jsonObject(with: data))
    }
}

/// Parsing shared by the API types.
enum Wire {
    static func document(_ json: [String: Any]) throws -> RemoteDocument {
        guard let kind = json["kind"] as? String, let id = json["id"] as? String,
              let revision = json["revision"] as? Int, let deleted = json["deleted"] as? Bool
        else { throw APIError.invalidResponse }
        let payload = try (json["payload"] as? [String: Any]).map { try JSONSerialization.data(withJSONObject: $0) }
        return RemoteDocument(kind: kind, id: id, revision: revision, deleted: deleted, payload: payload,
                              sequence: json["sequence"] as? Int)
    }

    static func writeResult(_ status: Int, _ data: Data) throws -> DocumentWriteResult {
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

    static func code(_ json: Any?) -> String? {
        ((json as? [String: Any])?["details"] as? [String: Any])?["code"] as? String
    }

    static func failure(_ status: Int, _ json: Any?) -> APIError {
        .server(status: status, message: (json as? [String: Any])?["message"] as? String ?? "HTTP \(status)")
    }
}
