import Foundation
import CryptoKit

extension Notification.Name {
    static let exerlySessionExpired = Notification.Name("exerlySessionExpired")
}

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int, String)
    case networkError(Error)
    case decodingError(Error)
    case unknown
    case invalidSessionResponse
    case sessionStorage

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The server address is invalid."
        case .unauthorized: return "Your session expired. Please sign in again."
        case .serverError(_, let message): return message
        case .networkError: return "Could not connect. Your saved data is still on this device. Try again when you have a connection."
        case .decodingError: return "The server returned an unreadable response. Refresh to check whether your change was saved."
        case .unknown: return "The request could not be completed. Please try again."
        case .invalidSessionResponse: return "The session response could not be verified. Your saved session is unchanged. Try connecting again."
        case .sessionStorage: return "Your session update could not be saved on this device. Your saved session and changes are still here. Try again."
        }
    }

    var permitsReadRetry: Bool {
        switch self {
        case .networkError(let error): return (error as? URLError)?.code != .cancelled
        case .serverError(let code, _): return [502, 503, 504].contains(code)
        default: return false
        }
    }
}

struct APIMessageResponse: Codable {
    let message: String?
    let error: String?
}

actor APIClient {
    static let shared = APIClient()
    private static let productionBaseURL = "https://exerly-fitness-93dyl.ondigitalocean.app"
    private let baseURL: String
    private let session: URLSession
    private let keychain: any SessionCredentials
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let defaults: UserDefaults
    private var refreshTask: Task<AuthResponse, Error>?
    private var refreshingToken: String?
    private var refreshingCredential: String?
    private var refreshTaskID: UUID?
    nonisolated var storageNamespace: String {
        var identity = baseURL
        #if DEBUG
        // Fixture databases restart their local account IDs between runs.
        // Keep defaults-backed drafts isolated with the test store and Keychain.
        if let id = ProcessInfo.processInfo.environment["EXERLY_TEST_STORE_ID"], UUID(uuidString: id) != nil {
            identity += "\nSimulatorTests:\(id)"
        }
        #endif
        return SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    nonisolated var permitsLegacyDraftMigration: Bool { baseURL == Self.productionBaseURL }

    init(baseURL: String? = nil, session: URLSession? = nil, keychain: any SessionCredentials = KeychainService.shared, defaults: UserDefaults = .standard) {
        self.baseURL = baseURL ?? Self.resolveBaseURL()
        self.keychain = keychain
        self.defaults = defaults
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = session ?? URLSession(configuration: config)
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
    }

    private static func resolveBaseURL() -> String {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["EXERLY_API_BASE_URL"], !override.isEmpty {
            return override
        }
        #endif
        if let configured = Bundle.main.object(forInfoDictionaryKey: "EXERLY_API_BASE_URL") as? String,
           !configured.isEmpty, !configured.contains("$(") {
            return configured
        }
        return productionBaseURL
    }

    func request<T: Decodable>(
        _ method: String, path: String, body: Encodable? = nil,
        authenticated: Bool = true, operationID: String? = nil, expectedAccountID: String? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2", forHTTPHeaderField: "X-Session-Protocol")
        request.setValue(TimeZone.current.identifier, forHTTPHeaderField: "X-Timezone")
        request.setValue(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development", forHTTPHeaderField: "X-App-Version")
        var token = authenticated ? keychain.getToken() : nil
        if let expectedAccountID, let owner = Self.accountID(in: token), owner != expectedAccountID {
            throw CancellationError()
        }
        // Installed releases can retain an email-only JWT or a long-lived
        // access token without a refresh credential. Upgrade before applying
        // account ownership checks or sending a queued mutation.
        if authenticated, path != "/auth/refresh", let originalToken = token, keychain.getRefreshToken() == nil {
            do {
                token = try await refreshSession(expectedToken: originalToken).token
            } catch APIError.unauthorized {
                try expireSession(matching: originalToken)
                throw APIError.unauthorized
            }
        }
        if let expectedAccountID, Self.accountID(in: token) != expectedAccountID { throw CancellationError() }
        if authenticated {
            guard let token else { throw APIError.unauthorized }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body { request.httpBody = try encoder.encode(body) }
        if (authenticated || operationID != nil) && !["GET", "HEAD"].contains(method) {
            request.setValue(operationID ?? UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        }
        // Mutation acknowledgements can be lost after commit. The caller owns
        // retry/reconciliation and retains its operation ID across relaunches.
        let attempts = method == "GET" ? 3 : 1
        for attempt in 0..<attempts {
            try Task.checkCancellation()
            do {
                return try await perform(request, token: token)
            } catch let error as APIError {
                if case .unauthorized = error, let token, path != "/api/change-password" {
                    if path != "/auth/refresh", keychain.getRefreshToken() != nil {
                        let renewed: AuthResponse
                        do {
                            renewed = try await refreshSession(expectedToken: token)
                        } catch APIError.unauthorized {
                            try expireSession(matching: token)
                            throw APIError.unauthorized
                        }
                        if let expectedAccountID, Self.accountID(in: renewed.token) != expectedAccountID { throw CancellationError() }
                        var retry = request
                        retry.setValue("Bearer \(renewed.token)", forHTTPHeaderField: "Authorization")
                        do {
                            return try await perform(retry, token: renewed.token)
                        } catch APIError.unauthorized {
                            try expireSession(matching: renewed.token)
                            throw APIError.unauthorized
                        }
                    }
                    try expireSession(matching: token)
                    throw error
                }
                guard attempt + 1 < attempts, error.permitsReadRetry else { throw error }
                try await Task.sleep(for: .milliseconds(250 * (attempt + 1)))
            }
        }
        throw APIError.unknown
    }

    private func perform<T: Decodable>(_ request: URLRequest, token: String?) async throws -> T {
        try Task.checkCancellation()
        if let token, keychain.getToken() != token { throw CancellationError() }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            throw APIError.networkError(error)
        }
        try Task.checkCancellation()
        // Neither a success nor a rejection from an old account may change the
        // current account after logout, login, or credential rotation.
        if let token, keychain.getToken() != token { throw CancellationError() }
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        switch http.statusCode {
        case 200...299:
            do { return try decoder.decode(T.self, from: data) }
            catch { throw APIError.decodingError(error) }
        case 401:
            throw APIError.unauthorized
        default:
            let message = try? decoder.decode(APIMessageResponse.self, from: data)
            throw APIError.serverError(http.statusCode, message?.message ?? "The server could not complete this request.")
        }
    }

    func get<T: Decodable>(_ path: String, authenticated: Bool = true) async throws -> T {
        try await request("GET", path: path, authenticated: authenticated)
    }
    func post<T: Decodable>(_ path: String, body: Encodable? = nil, authenticated: Bool = true, operationID: String? = nil) async throws -> T {
        try await request("POST", path: path, body: body, authenticated: authenticated, operationID: operationID)
    }
    func put<T: Decodable>(_ path: String, body: Encodable? = nil, operationID: String? = nil) async throws -> T {
        try await request("PUT", path: path, body: body, operationID: operationID)
    }
    func delete<T: Decodable>(_ path: String, operationID: String? = nil) async throws -> T {
        try await request("DELETE", path: path, operationID: operationID)
    }
    func postVoid(_ path: String, body: Encodable? = nil) async throws {
        let _: APIMessageResponse = try await post(path, body: body)
    }
    func deleteVoid(_ path: String) async throws {
        let _: APIMessageResponse = try await delete(path)
    }
    nonisolated static func accountCacheKey(_ token: String) -> String {
        let digest = SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
        return "session.account.v1.\(digest)"
    }
    nonisolated private static func claims(in token: String?) -> [String: Any]? {
        guard let parts = token?.split(separator: "."), parts.count == 3 else { return nil }
        var encoded = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    nonisolated static func accountID(in token: String?) -> String? {
        guard let owner = claims(in: token)?["sub"] as? String, !owner.isEmpty else { return nil }
        return owner
    }

    nonisolated static func validateSession(_ response: AuthResponse, replacing originalToken: String? = nil) throws {
        guard let refresh = response.refreshToken, !refresh.isEmpty,
              let user = response.user, let owner = user.id, !owner.isEmpty,
              accountID(in: response.token) == owner,
              let sessionID = claims(in: response.token)?["sid"] as? String, !sessionID.isEmpty else {
            throw APIError.invalidSessionResponse
        }
        if let originalToken {
            if let previousOwner = accountID(in: originalToken) {
                guard previousOwner == owner else { throw APIError.invalidSessionResponse }
            } else {
                guard let email = claims(in: originalToken)?["email"] as? String,
                      email.caseInsensitiveCompare(user.email) == .orderedSame else { throw APIError.invalidSessionResponse }
            }
        }
    }

    private func expireSession(matching token: String) throws {
        guard keychain.getToken() == token else { throw CancellationError() }
        NotificationCenter.default.post(name: .exerlySessionExpired, object: token)
    }

    func revokeSession(accessToken: String) async {
        guard let url = URL(string: baseURL + "/auth/logout") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        let _: APIMessageResponse? = try? await perform(request, token: nil)
    }
    private func refreshOperation(token: String, refresh: String?) throws -> (key: String, value: String, previousKey: String?) {
        let digest = SHA256.hash(data: Data((refresh ?? token).utf8)).map { String(format: "%02x", $0) }.joined()
        let key = "session.operation.v2.\(storageNamespace).\(refresh == nil ? "upgrade" : "rotate").\(digest)"
        let previousKey = refresh == nil ? nil : "refresh.operation.\(digest)"
        let saved = defaults.object(forKey: key) ?? previousKey.flatMap { defaults.object(forKey: $0) }
        let operation: String
        if let saved {
            guard let value = saved as? String, value.range(of: "^[a-zA-Z0-9._:-]{8,128}$", options: .regularExpression) != nil else {
                throw APIError.sessionStorage
            }
            operation = value
        } else { operation = UUID().uuidString }
        defaults.set(operation, forKey: key)
        guard defaults.string(forKey: key) == operation else { throw APIError.sessionStorage }
        return (key, operation, previousKey)
    }

    @discardableResult
    func refreshSession(expectedToken: String? = nil) async throws -> AuthResponse {
        guard let savedSession = keychain.sessionSnapshot() else { throw APIError.unauthorized }
        let originalToken = savedSession.token
        if let expectedToken, originalToken != expectedToken { throw CancellationError() }
        let refresh = savedSession.refreshToken
        if let refreshTask, refreshingToken == originalToken, refreshingCredential == refresh {
            return try await refreshTask.value
        }
        let taskID = UUID()
        let task = Task<AuthResponse, Error> {
            let operation = try refreshOperation(token: originalToken, refresh: refresh)
            let response: AuthResponse
            if let refresh {
                response = try await post("/auth/token", body: RefreshRequest(refreshToken: refresh), authenticated: false, operationID: operation.value)
            } else {
                guard let url = URL(string: baseURL + "/auth/refresh") else { throw APIError.invalidURL }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("2", forHTTPHeaderField: "X-Session-Protocol")
                request.setValue("Exerly iPhone", forHTTPHeaderField: "X-Device-Name")
                request.setValue("Bearer \(originalToken)", forHTTPHeaderField: "Authorization")
                request.setValue(operation.value, forHTTPHeaderField: "Idempotency-Key")
                response = try await perform(request, token: originalToken)
            }
            guard keychain.getToken() == originalToken, keychain.getRefreshToken() == refresh else { throw CancellationError() }
            try Self.validateSession(response, replacing: originalToken)
            // Copy only the verified owner's cached bootstrap before rotating
            // credentials, so an offline relaunch can still open this account.
            let oldKey = Self.accountCacheKey(originalToken)
            let newKey = Self.accountCacheKey(response.token)
            if let data = defaults.data(forKey: oldKey),
               let user = try? decoder.decode(UserDTO.self, from: data), user.id == response.user?.id {
                defaults.set(data, forKey: newKey)
                if let complete = defaults.object(forKey: oldKey + ".complete") { defaults.set(complete, forKey: newKey + ".complete") }
            }
            guard keychain.replaceSession(expectedToken: originalToken, expectedRefreshToken: refresh,
                                          token: response.token, refreshToken: response.refreshToken!) else {
                guard keychain.getToken() == originalToken, keychain.getRefreshToken() == refresh else { throw CancellationError() }
                throw APIError.sessionStorage
            }
            defaults.removeObject(forKey: operation.key)
            if let previousKey = operation.previousKey { defaults.removeObject(forKey: previousKey) }
            return response
        }
        refreshTask = task
        refreshTaskID = taskID
        refreshingToken = originalToken
        refreshingCredential = refresh
        defer {
            if refreshTaskID == taskID {
                refreshTask = nil
                refreshTaskID = nil
                refreshingToken = nil
                refreshingCredential = nil
            }
        }
        return try await task.value
    }
}

private struct RefreshRequest: Encodable { let refreshToken: String }
