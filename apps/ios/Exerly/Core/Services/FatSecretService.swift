import Foundation

actor FatSecretService {
    static let shared = FatSecretService()

    private let clientID = "82c4d8336e5747b2b48cc5f23ca9e017"
    private let clientSecret = "3666ef5a43184b749fe4a5316fd9fff4"
    private let tokenURL = "https://oauth.fatsecret.com/connect/token"
    private let apiBase = "https://platform.fatsecret.com/rest"
    private let session: URLSession
    private let decoder = JSONDecoder()

    private var accessToken: String?
    private var tokenExpiry: Date = .distantPast

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    // MARK: - OAuth2 Token

    private func getToken() async throws -> String {
        if let token = accessToken, Date() < tokenExpiry {
            return token
        }

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let credentials = Data("\(clientID):\(clientSecret)".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.httpBody = "grant_type=client_credentials&scope=basic barcode".data(using: .utf8)

        let (data, _) = try await session.data(for: request)
        let token = try decoder.decode(TokenResponse.self, from: data)
        accessToken = token.access_token
        tokenExpiry = Date().addingTimeInterval(TimeInterval(token.expires_in - 60))
        return token.access_token
    }

    // MARK: - Barcode Lookup

    func fetchByBarcode(_ barcode: String) async -> OpenFoodItem? {
        let gtin13 = barcode.count < 13
            ? String(repeating: "0", count: 13 - barcode.count) + barcode
            : barcode

        guard let token = try? await getToken(),
              var components = URLComponents(string: "\(apiBase)/food/barcode/find-by-id/v2") else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "barcode", value: gtin13),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "flag_default_serving", value: "true")
        ]

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await session.data(for: request)
            let response = try decoder.decode(FSBarcodeResponse.self, from: data)
            return normalize(response.food, barcode: barcode)
        } catch {
            return nil
        }
    }

    private func normalize(_ food: FSFood, barcode: String) -> OpenFoodItem? {
        guard !food.food_name.isEmpty else { return nil }

        let serving = food.servings.serving.first
        let cal = Int(Double(serving?.calories ?? "0") ?? 0)
        let protein = Double(serving?.protein ?? "0") ?? 0
        let carbs = Double(serving?.carbohydrate ?? "0") ?? 0
        let fat = Double(serving?.fat ?? "0") ?? 0
        let sugar = Double(serving?.sugar ?? "0") ?? 0
        let fiber = Double(serving?.fiber ?? "0") ?? 0
        let servingDesc = serving?.serving_description ?? serving?.metric_serving_amount.map { "\($0)\(serving?.metric_serving_unit ?? "g")" } ?? "1 serving"

        return OpenFoodItem(
            barcode: barcode,
            name: food.food_name,
            brand: food.brand_name,
            calories: cal,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            sugar: sugar,
            servingSize: servingDesc
        )
    }
}

// MARK: - FatSecret API Models

private struct TokenResponse: Decodable {
    let access_token: String
    let expires_in: Int
}

private struct FSBarcodeResponse: Decodable {
    let food: FSFood
}

private struct FSFood: Decodable {
    let food_id: String
    let food_name: String
    let brand_name: String?
    let food_type: String?
    let servings: FSServings
}

private struct FSServings: Decodable {
    let serving: [FSServing]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // FatSecret returns either a single object or an array for "serving"
        if let array = try? container.decode([FSServing].self, forKey: .serving) {
            serving = array
        } else if let single = try? container.decode(FSServing.self, forKey: .serving) {
            serving = [single]
        } else {
            serving = []
        }
    }

    enum CodingKeys: String, CodingKey {
        case serving
    }
}

private struct FSServing: Decodable {
    let serving_id: String?
    let serving_description: String?
    let metric_serving_amount: String?
    let metric_serving_unit: String?
    let calories: String?
    let carbohydrate: String?
    let protein: String?
    let fat: String?
    let sugar: String?
    let fiber: String?
    let is_default: String?
}
