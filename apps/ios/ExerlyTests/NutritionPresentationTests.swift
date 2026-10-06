import ExerlyCore
import XCTest
@testable import Exerly

@MainActor
final class NutritionPresentationTests: XCTestCase {
    func testNutritionStaysInItsAccountAndClosedWorkspacesCannotWrite() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let firstID = UUID().uuidString
        let first = try TrainingWorkspace(accountID: firstID, root: root)
        let date = try XCTUnwrap(LocalDate("2026-10-06"))
        let food = ExerlyCore.Food(name: "Account one oats", per100g: NutrientAmounts([.energy: 380]))
        try first.nutrition.saveFood(food)
        let entry = try first.nutrition.log(food, grams: 40, on: date, meal: "Breakfast")
        await first.close()
        XCTAssertThrowsError(try first.nutrition.saveFood(food))
        let second = try TrainingWorkspace(accountID: UUID().uuidString, root: root)
        XCTAssertTrue(second.nutrition.foods.isEmpty)
        XCTAssertTrue(second.nutrition.entries.isEmpty)
        let reopened = try TrainingWorkspace(accountID: firstID, root: root)
        XCTAssertEqual(reopened.nutrition.entries.first?.id, entry.id)
        XCTAssertEqual(reopened.nutrition.foods.first?.name, food.name)
        await reopened.close()
        try TrainingWorkspace.deleteStorage(accountID: firstID, root: root)
        let removed = try TrainingWorkspace(accountID: firstID, root: root)
        XCTAssertTrue(removed.nutrition.foods.isEmpty)
        XCTAssertTrue(removed.nutrition.entries.isEmpty)
        await removed.close()
        await second.close()
    }

    func testAccountExportIncludesOfflineFoodEntryAndDayNotes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let account = UUID().uuidString
        let first = try TrainingWorkspace(accountID: account, root: root)
        let source = try SQLiteTrainingPersistence(url: first.url)
        let nutrition = try NutritionStore(persistence: source)
        let date = try XCTUnwrap(LocalDate("2026-10-06"))
        let food = ExerlyCore.Food(name: "Synthetic oats", per100g: NutrientAmounts([.energy: 380, .protein: 12, .sodium: 0]))
        try nutrition.saveFood(food)
        let entry = try nutrition.log(food, grams: 42.123456789, on: date, meal: "Breakfast")
        try nutrition.setStatus(.partial, on: date)
        try nutrition.setNotes("Keep this offline note", on: date)
        source.close()
        await first.close()
        let reopened = try TrainingWorkspace(accountID: account, root: root)
        let exported = try XCTUnwrap(JSONSerialization.jsonObject(with: reopened.export(server: nil)) as? [String: Any])
        let documents = try XCTUnwrap(exported["documents"] as? [[String: Any]])
        let foodRow = try XCTUnwrap(documents.first { $0["kind"] as? String == "saved_food" })
        XCTAssertEqual(foodRow["document_id"] as? String, food.id)
        let entryRow = try XCTUnwrap(documents.first { $0["kind"] as? String == "food_entry" })
        XCTAssertEqual(entryRow["document_id"] as? String, entry.id.uuidString)
        XCTAssertEqual(entryRow["pending_sync"] as? Bool, true)
        let payload = try XCTUnwrap(entryRow["payload"] as? [String: Any])
        XCTAssertEqual(payload["grams"] as? Double, 42.123456789)
        let day = try XCTUnwrap(documents.first { $0["kind"] as? String == "nutrition_day" }?["payload"] as? [String: Any])
        XCTAssertEqual(day["status"] as? String, "partial")
        XCTAssertEqual(day["notes"] as? String, "Keep this offline note")
        await reopened.close()
    }

    func testMealProposalUsesTheAccountHostAndUndoRemovesItsEntry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = try TrainingWorkspace(accountID: UUID().uuidString, root: root)
        let date = try XCTUnwrap(LocalDate("2026-10-06"))
        let food = ExerlyCore.Food(name: "Synthetic apple", per100g: NutrientAmounts([.energy: 52, .fiber: 2.4]))
        let entry = FoodEntry(date: date, meal: "Snacks", loggedAt: Date(), food: food.snapshot, grams: 125)
        let proposal = try Proposal(author: AgentIdentity(kind: .mcp, name: "Synthetic meal agent"),
            title: "Review an apple", summary: "Confirm the food and amount before logging.",
            changes: [ProposedChange(kind: "food_entry", id: entry.id.uuidString, before: Optional<FoodEntry>.none, after: entry)],
            evidence: [], confidence: .low, falsifier: "The food or amount is different from what you ate.")
        XCTAssertTrue(workspace.supportsChanges(in: proposal))
        try workspace.agent.file(proposal)
        try workspace.agent.accept(proposal.id)
        let accepted = try XCTUnwrap(JSONSerialization.jsonObject(with: workspace.export(server: nil)) as? [String: Any])
        let records = try XCTUnwrap(accepted["documents"] as? [[String: Any]])
        XCTAssertTrue(records.contains { $0["kind"] as? String == "food_entry" && $0["document_id"] as? String == entry.id.uuidString })
        try workspace.agent.undo(proposal.id)
        XCTAssertEqual(workspace.agent.proposal(proposal.id)?.status, .undone)
        let source = try SQLiteTrainingPersistence(url: workspace.url)
        XCTAssertTrue(try NutritionStore(persistence: source).entries.isEmpty)
        source.close()
        await workspace.close()
    }
}
