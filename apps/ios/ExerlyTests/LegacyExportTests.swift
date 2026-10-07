import XCTest
import SwiftData
import ExerlyCore
@testable import Exerly

/// The legacy queue's entries in the account export before they sync. Uses
/// `StubURLProtocol` and `MemoryCredentials` from ProductionTests.swift.
@MainActor
final class LegacyExportTests: XCTestCase {
    func testAnExportHoldsEntriesWaitingToSyncForThisAccountOnly() throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "exerly.tests.\(UUID().uuidString)"))
        let api = APIClient(baseURL: "https://fixture.exerly.test", session: URLSession(configuration: config),
                            keychain: MemoryCredentials(), defaults: defaults)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-22T09:00:00Z"))
        let container = try ModelContainer(for: Schema(versionedSchema: ExerlySchemaV3.self),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let engine = SyncEngine(api: api, monitorNetwork: false, automaticallySync: false, observeClock: false, now: { now })
        engine.configure(container: container, accountID: "a", timeZone: "UTC")
        let day = engine.today
        var food = FoodRequest(name: "Apple", calories: 100, protein: 0, carbs: 25, fat: 0, sugar: nil, mealType: "snack",
                               barcode: nil, brand: nil, fiber: nil, servingSize: nil)
        food.entryDate = day.rawValue
        let foodID = try engine.saveFood(food)
        try engine.saveWeight(.initial(day.rawValue), kilograms: 72, note: "")

        let rows = try engine.pendingExportRows()
        XCTAssertEqual(Set(rows.map(\.table)), ["food", "weights"])
        let server = try JSONSerialization.data(withJSONObject: ["version": 3, "documents": [], "food": [], "weights": []])
        let export = try AccountExport.merging(server: server, hosts: [], state: InMemoryTrainingPersistence(), pending: rows)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: export) as? [String: Any])
        let foods = try XCTUnwrap(json["food"] as? [[String: Any]])
        XCTAssertEqual(foods.count, 1)
        XCTAssertEqual(foods.first?["client_id"] as? String, foodID)
        XCTAssertEqual(foods.first?["pending_sync"] as? Bool, true)
        XCTAssertEqual((json["weights"] as? [[String: Any]])?.count, 1)

        engine.configure(container: container, accountID: "b", timeZone: "UTC")
        XCTAssertTrue(try engine.pendingExportRows().isEmpty, "Another account's queue never appears")
    }
}
