import Foundation

struct OpenFoodItem: Identifiable, Codable {
    var id: String { barcode ?? UUID().uuidString }
    let barcode: String?
    let name: String
    let brand: String?
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let servingSize: String

    func scaled(by factor: Double) -> OpenFoodItem {
        OpenFoodItem(
            barcode: barcode, name: name, brand: brand,
            calories: Int(Double(calories) * factor),
            protein: protein * factor, carbs: carbs * factor,
            fat: fat * factor, fiber: fiber * factor,
            sugar: sugar * factor, servingSize: servingSize
        )
    }
}

actor OpenFoodFactsService {
    static let shared = OpenFoodFactsService()

    private let baseURL = "https://world.openfoodfacts.org"
    private let session: URLSession
    private let decoder = JSONDecoder()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    func search(query: String, page: Int = 1) async -> [OpenFoodItem] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/cgi/search.pl?search_terms=\(encoded)&page=\(page)&page_size=20&json=1") else {
            return []
        }
        do {
            let (data, _) = try await session.data(from: url)
            let response = try decoder.decode(OFFSearchResponse.self, from: data)
            return response.products.compactMap { normalize($0) }
        } catch {
            return []
        }
    }

    func fetchByBarcode(_ barcode: String) async -> OpenFoodItem? {
        guard let url = URL(string: "\(baseURL)/api/v0/product/\(barcode).json") else {
            return nil
        }
        do {
            let (data, _) = try await session.data(from: url)
            let response = try decoder.decode(OFFProductResponse.self, from: data)
            guard response.status == 1, let product = response.product else { return nil }
            return normalize(product)
        } catch {
            return nil
        }
    }

    private func normalize(_ p: OFFProduct) -> OpenFoodItem? {
        let name = p.product_name ?? p.product_name_en ?? ""
        guard !name.isEmpty else { return nil }
        let n = p.nutriments
        return OpenFoodItem(
            barcode: p.code,
            name: name,
            brand: p.brands,
            calories: Int(n?.energy_kcal_100g ?? n?.energy_kcal ?? 0),
            protein: n?.proteins_100g ?? 0,
            carbs: n?.carbohydrates_100g ?? 0,
            fat: n?.fat_100g ?? 0,
            fiber: n?.fiber_100g ?? 0,
            sugar: n?.sugars_100g ?? 0,
            servingSize: p.serving_size ?? "100g"
        )
    }
}

// MARK: - OFF API Models

private struct OFFSearchResponse: Decodable {
    let products: [OFFProduct]
}

private struct OFFProductResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFProduct: Decodable {
    let code: String?
    let product_name: String?
    let product_name_en: String?
    let brands: String?
    let serving_size: String?
    let nutriments: OFFNutriments?
}

private struct OFFNutriments: Decodable {
    let energy_kcal_100g: Double?
    let energy_kcal: Double?
    let proteins_100g: Double?
    let carbohydrates_100g: Double?
    let fat_100g: Double?
    let fiber_100g: Double?
    let sugars_100g: Double?

    enum CodingKeys: String, CodingKey {
        case energy_kcal_100g = "energy-kcal_100g"
        case energy_kcal = "energy-kcal"
        case proteins_100g, carbohydrates_100g, fat_100g
        case fiber_100g, sugars_100g
    }
}
