import Foundation

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int, String)
    case networkError(Error)
    case decodingError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .unauthorized: return "Session expired. Please log in again."
        case .serverError(let code, let msg): return "Server error (\(code)): \(msg)"
        case .networkError(let err):
            let nsError = err as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorNotConnectedToInternet {
                return "The app could not reach the development server. If you're using a physical iPhone, allow Local Network for Exerly in Settings and verify the backend is running at \(APIClient.debugBaseURL)."
            }
            return err.localizedDescription
        case .decodingError: return "Failed to parse response"
        case .unknown: return "An unknown error occurred"
        }
    }
}

// MARK: - API Response

struct APIMessageResponse: Codable {
    let message: String?
    let error: String?
}

// MARK: - API Client Actor

actor APIClient {
    static let shared = APIClient()

    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let maxRetries = 3

    private init() {
        self.baseURL = Self.resolveBaseURL()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    nonisolated fileprivate static var debugBaseURL: String {
        resolveBaseURL()
    }

    private static func resolveBaseURL() -> String {
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:3001"
        #else
        if let configuredBaseURL = Bundle.main.object(forInfoDictionaryKey: "EXERLY_API_BASE_URL") as? String,
           !configuredBaseURL.isEmpty {
            return configuredBaseURL
        }
        return "http://192.168.1.192:3001"
        #endif
    }

    // MARK: - Core Request

    func request<T: Decodable>(
        _ method: String,
        path: String,
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        var lastError: Error = APIError.unknown

        for attempt in 0..<maxRetries {
            do {
                return try await performRequest(
                    method, path: path,
                    body: body, authenticated: authenticated
                )
            } catch let error as APIError {
                if case .unauthorized = error { throw error }
                if case .serverError(let code, _) = error, code < 500 { throw error }
                lastError = error
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt)) * 0.5
                    try await Task.sleep(for: .seconds(delay))
                }
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    let delay = pow(2.0, Double(attempt)) * 0.5
                    try await Task.sleep(for: .seconds(delay))
                }
            }
        }
        throw lastError
    }

    private func performRequest<T: Decodable>(
        _ method: String,
        path: String,
        body: Encodable? = nil,
        authenticated: Bool
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated, let token = KeychainService.shared.getToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            urlRequest.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        case 401:
            throw APIError.unauthorized
        default:
            let messageResponse = try? decoder.decode(APIMessageResponse.self, from: data)
            let msg = messageResponse?.error
                ?? messageResponse?.message
                ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, msg)
        }
    }

    // MARK: - Convenience

    func get<T: Decodable>(_ path: String, authenticated: Bool = true) async throws -> T {
        try await request("GET", path: path, authenticated: authenticated)
    }

    func post<T: Decodable>(
        _ path: String,
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        try await request("POST", path: path, body: body, authenticated: authenticated)
    }

    func put<T: Decodable>(
        _ path: String,
        body: Encodable? = nil
    ) async throws -> T {
        try await request("PUT", path: path, body: body)
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        try await request("DELETE", path: path)
    }

    // MARK: - Fire and forget (for non-decodable responses)

    func postVoid(_ path: String, body: Encodable? = nil) async throws {
        let _: APIMessageResponse = try await post(path, body: body)
    }

    func deleteVoid(_ path: String) async throws {
        let _: APIMessageResponse = try await delete(path)
    }
}
