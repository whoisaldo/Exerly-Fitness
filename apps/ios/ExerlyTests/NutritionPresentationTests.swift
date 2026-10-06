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

    func testEditingFoodMetadataKeepsEveryUnchangedNutrientAndServingExactly() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let amounts = NutrientAmounts(Dictionary(uniqueKeysWithValues: Nutrient.allCases.map { ($0, 12.123456789) }))
        let food = ExerlyCore.Food(name: "Precise food", per100g: amounts, servings: [Serving("Scoop", grams: 33.123456789)])
        try store.saveFood(food)
        let draft = NutritionFoodDraft(store: store, editing: food)
        draft.name = "Renamed food"
        let saved = try XCTUnwrap(draft.save())
        XCTAssertEqual(saved.per100g, amounts)
        XCTAssertEqual(saved.servings, food.servings)
        XCTAssertEqual(saved.id, food.id)
    }

    func testManualLabelUsesCoreConversionAndDistinguishesBlankFromZero() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let draft = NutritionFoodDraft(store: store)
        draft.name = "Synthetic label"
        draft.basis = .perServing
        draft.labelGrams.text = "42,5"
        draft.nutrients[.energy]?.text = "123,75"
        draft.nutrients[.sodium]?.text = "0"
        let saved = try XCTUnwrap(draft.save(locale: Locale(identifier: "de_DE")))
        let expected = try ExerlyCore.Food.per100g(fromLabel: NutrientAmounts([.energy: 123.75, .sodium: 0]), servingGrams: 42.5)
        XCTAssertEqual(saved.per100g, expected)
        XCTAssertNil(saved.per100g[.protein])
        XCTAssertEqual(saved.per100g[.sodium], 0)
        let invalid = NutritionFoodDraft(store: store)
        invalid.name = "Invalid label"
        invalid.nutrients[.energy]?.text = "several"
        XCTAssertNil(invalid.save())
        XCTAssertEqual(store.foods.count, 1)
        XCTAssertEqual(invalid.name, "Invalid label")
        XCTAssertTrue(invalid.errors.first?.contains("Energy") == true)
    }

    func testFoodDraftRefusesToOverwriteAnUpdatedOrArchivedFood() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        var food = ExerlyCore.Food(name: "Original", per100g: NutrientAmounts([.energy: 120]))
        try store.saveFood(food)
        let draft = NutritionFoodDraft(store: store, editing: food)
        draft.name = "My draft"
        food.name = "Updated elsewhere"
        try store.saveFood(food)
        XCTAssertNil(draft.save())
        XCTAssertEqual(store.food(food.id)?.name, "Updated elsewhere")
        XCTAssertEqual(draft.name, "My draft")
        let archivedDraft = NutritionFoodDraft(store: store, editing: food)
        try store.archiveFood(food.id)
        XCTAssertNil(archivedDraft.save())
        XCTAssertNotNil(store.food(food.id)?.archivedAt)
    }

    func testEntryMetadataEditUsesItsSnapshotAndKeepsExactPortion() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let date = try XCTUnwrap(LocalDate("2026-10-06"))
        var food = ExerlyCore.Food(name: "Original oats", per100g: NutrientAmounts([.energy: 380.123456789, .sodium: 0]))
        var entry = try store.log(food, serving: Serving("Scoop", grams: 33.123456789), quantity: 1.23456789, on: date, meal: "Breakfast")
        // Imported records can have a separately precise gram amount.
        entry.grams = 40.123456789
        try store.saveEntry(entry)
        food.name = "Updated library oats"
        food.per100g[.energy] = 999
        try store.saveFood(food)
        let draft = NutritionEntryDraft(store: store, food: food, date: date, meal: "Breakfast", editing: entry)
        draft.meal = "Lunch"
        XCTAssertEqual(draft.food.snapshot, entry.food)
        XCTAssertEqual(try draft.preview().nutrients, entry.nutrients)
        let saved = try XCTUnwrap(draft.save())
        XCTAssertEqual(saved.id, entry.id)
        XCTAssertEqual(saved.food, entry.food)
        XCTAssertEqual(saved.grams, entry.grams)
        XCTAssertEqual(saved.quantity, entry.quantity)
        XCTAssertEqual(saved.loggedAt, entry.loggedAt)
        XCTAssertEqual(saved.meal, "Lunch")
    }

    func testServingPreviewMatchesTheSavedEntryWithoutInventingUnknownNutrients() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let date = try XCTUnwrap(LocalDate("2026-10-06"))
        let food = ExerlyCore.Food(name: "Measured food", per100g: NutrientAmounts([.energy: 380, .sodium: 0]))
        let draft = NutritionEntryDraft(store: store, food: food, date: date, meal: "Lunch")
        draft.serving = Serving("Cup", grams: 42.123456789)
        draft.amount.text = "1,25"
        let preview = try draft.preview(locale: Locale(identifier: "de_DE"))
        XCTAssertTrue(store.entries.isEmpty)
        let saved = try XCTUnwrap(draft.save(locale: Locale(identifier: "de_DE")))
        XCTAssertEqual(saved.grams, preview.grams)
        XCTAssertEqual(saved.nutrients, preview.nutrients)
        XCTAssertEqual(saved.quantity, 1.25)
        XCTAssertNil(saved.nutrients[.protein])
        XCTAssertEqual(saved.nutrients[.sodium], 0)
        XCTAssertNotNil(draft.save(locale: Locale(identifier: "de_DE")))
        XCTAssertEqual(store.entries.count, 1)
    }

    func testInvalidAndStaleEntryDraftsKeepTheirInputAndDoNotWrite() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let date = try XCTUnwrap(LocalDate("2026-10-06"))
        let food = ExerlyCore.Food(name: "Synthetic food", per100g: NutrientAmounts([.energy: 250]))
        let draft = NutritionEntryDraft(store: store, food: food, date: date, meal: "Lunch")
        draft.amount.text = "0"
        XCTAssertNil(draft.save())
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(draft.amount.text, "0")
        var entry = try store.log(food, grams: 25, on: date, meal: "Lunch")
        let stale = NutritionEntryDraft(store: store, food: food, date: date, meal: "Lunch", editing: entry)
        stale.amount.text = "60"
        entry.grams = 40
        try store.saveEntry(entry)
        XCTAssertNil(stale.save())
        XCTAssertEqual(store.entries.first?.grams, 40)
        XCTAssertEqual(stale.amount.text, "60")
        let deleted = NutritionEntryDraft(store: store, food: food, date: date, meal: "Lunch", editing: entry)
        try store.deleteEntry(entry.id)
        XCTAssertNil(deleted.save())
        XCTAssertTrue(store.entries.isEmpty)
    }

}
