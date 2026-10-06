import Foundation
import Testing
@testable import ExerlyCore

/// The Foods the API maps from Open Food Facts, in docs/api/golden/foods-v1.json,
/// which apps/api/tests/foods.golden.test.js asserts on the server side. If
/// these decode, the phone can read what the server sends.
@Suite struct FoodsGoldenTests {
    static let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/api/golden/foods-v1.json")

    struct Golden: Decodable {
        /// The server's mapping targets, as [name, factor from grams].
        var nutrients: [[JSONValue]]
        var foods: [Food?]
    }

    @Test func everyMappedFoodDecodesWithItsNutrientsInExerlyCoreUnits() throws {
        let golden = try ExerlyJSON.decoder.decode(Golden.self, from: Data(contentsOf: Self.url))
        let foods = golden.foods.compactMap { $0 }
        for pair in golden.nutrients {
            guard case .string(let name) = pair.first, case .number(let factor) = pair.last,
                  let nutrient = Nutrient(rawValue: name) else {
                Issue.record("\(pair) isn't a nutrient the phone knows")
                continue
            }
            let expected: Double = switch nutrient.unit {
            case .grams, .kilocalories: 1
            case .milligrams: 1e3
            case .micrograms: 1e6
            }
            #expect(factor == expected, "\(name) is in \(nutrient.unit.rawValue)")
        }
        #expect(golden.foods.count == 5 && foods.count == 3)
        #expect(foods.allSatisfy { $0.problems.isEmpty && $0.source == .openFoodFacts && $0.id.hasPrefix("off:") })
        let bar = try #require(foods.first)
        #expect(bar.per100g[.energy] == 412)
        #expect(bar.per100g[.sodium] == 240 && Nutrient.sodium.unit == .milligrams)
        #expect(bar.per100g[.vitaminD] == 2.5 && Nutrient.vitaminD.unit == .micrograms)
        #expect(bar.per100g[.alcohol] == nil)
        #expect(bar.servings == [Serving("1 bar (40 g)", grams: 40)])
        #expect(foods[1].per100g[.energy] == 43.021)
        // The canonical form round-trips, so a saved database food syncs unchanged.
        for food in foods {
            #expect(try ExerlyJSON.decoder.decode(Food.self, from: ExerlyJSON.canonical(food)) == food)
        }
    }
}

@Suite struct FoodDatabaseAPITests {
    let start = Date.milliseconds(1_791_223_200_000)

    func account(_ transport: FakeTransport) async throws -> AccountAPI {
        let store = InMemoryCredentialStore()
        try store.save(Credentials(accessToken: "t", refreshToken: "r", accessExpiresAt: start.addingTimeInterval(600),
                                   sessionID: "s", accountID: "a"))
        return try await ExerlyAPI(baseURL: URL(string: "https://api.exerly.test")!, transport: transport, credentials: store,
                                   now: { start }).account()
    }

    @Test func searchAndBarcodeReturnDatabaseFoodsOrNil() async throws {
        let golden = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: FoodsGoldenTests.url)) as? [String: Any])
        let foods = try #require(golden["foods"] as? [Any]).filter { !($0 is NSNull) }
        let attribution = "Data from Open Food Facts"
        let transport = FakeTransport { request in
            if request.path.hasPrefix("/v1/foods/search") { return (200, ["foods": foods, "attribution": attribution]) }
            if request.path == "/v1/foods/barcode/0012345678905" { return (200, ["food": foods[0], "attribution": attribution]) }
            if request.path == "/v1/foods/barcode/4000000000016" { return (404, ["error": "No food has that barcode"]) }
            return (503, ["error": "The food database is unavailable right now. Try again shortly."])
        }
        let api = try await account(transport)
        let found = try await api.searchFoods("oat bar + nuts", limit: 5)
        #expect(found.foods.map(\.id) == ["off:0012345678905", "off:5000000000017", "off:76543210"])
        #expect(found.attribution == attribution)
        #expect(transport.requests.first?.path == "/v1/foods/search?q=oat%20bar%20%2B%20nuts&limit=5")

        #expect(try await api.food(barcode: "0012345678905")?.foods.first?.name == "Synthetic oat bar")
        #expect(try await api.food(barcode: "4000000000016") == nil)
        await #expect(throws: APIError.self) { try await api.food(barcode: "5000000000017") }
    }
}
