import ExerlyCore
import XCTest
@testable import Exerly

@MainActor
final class NutritionPresentationTests: XCTestCase {
    func testEmptyDiaryShowsZeroLoggedButMissingLabelValuesStayUnknown() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let date = try XCTUnwrap(LocalDate("2026-10-07"))
        func amount(_ nutrient: Nutrient) -> Double? {
            NutritionFormat.summaryAmount(nutrient, amounts: store.summary(on: date).totals, progress: store.progress(on: date))
        }
        for nutrient in [Nutrient.energy, .protein, .carbohydrate, .fat] { XCTAssertEqual(amount(nutrient), 0) }
        let food = ExerlyCore.Food(name: "Incomplete label", per100g: NutrientAmounts([.energy: 120, .fat: 0]))
        _ = try store.log(food, grams: 100, on: date, meal: "Lunch")
        XCTAssertEqual(amount(.energy), 120)
        XCTAssertEqual(amount(.fat), 0)
        XCTAssertNil(amount(.protein))
        XCTAssertNil(amount(.carbohydrate))
        XCTAssertNil(amount(.sodium))
    }

    func testWaterEntryUsesUSFluidOuncesAndRejectsInvalidOrUnboundedAmounts() {
        XCTAssertEqual(WaterDisplay.milliliters("8", imperial: true), 237)
        XCTAssertEqual(WaterDisplay.milliliters("12.5", imperial: true), 370)
        XCTAssertEqual(WaterDisplay.amount(237, imperial: true), "8 fl oz")
        XCTAssertEqual(WaterDisplay.amount(607, imperial: true), "20.5 fl oz")
        for text in ["", "0", "-1", "170", "nan", "1e999"] {
            XCTAssertNil(WaterDisplay.milliliters(text, imperial: true))
        }
        XCTAssertEqual(WaterDisplay.milliliters("250", imperial: false), 250)
        XCTAssertNil(WaterDisplay.milliliters("250.5", imperial: false))
        XCTAssertEqual(WaterDisplay.amount(250, imperial: false), "250 ml")
    }

    func testEditingAnEntryKeepsItsVolumeLabelAndEstimatedDensity() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let date = try XCTUnwrap(LocalDate("2026-10-06"))
        var oil = ExerlyCore.Food(name: "Synthetic oil", source: .openFoodFacts,
                                 per100g: NutrientAmounts([.energy: 900]))
        oil.volume = VolumeBasis(density: 0.92, assumed: true, note: "Typical for oils")
        let entry = try store.log(oil, grams: 13.8, on: date, meal: "Dinner")
        let draft = NutritionEntryDraft(store: store, food: oil, date: date, meal: "Dinner", editing: entry)
        XCTAssertEqual(draft.food.volume, oil.volume)
        draft.amount.text = "27.6"
        let saved = try XCTUnwrap(draft.save())
        XCTAssertEqual(saved.food.volume, oil.volume)
        XCTAssertEqual(saved.food.per100g, entry.food.per100g)
        XCTAssertEqual(saved.grams, 27.6)
    }

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

    func testRepeatingAFoodPrefillsItsPrecisePortionButKeepsTheChosenDateAndMeal() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let oldDate = try XCTUnwrap(LocalDate("2026-10-05"))
        let today = try XCTUnwrap(LocalDate("2026-10-06"))
        var food = ExerlyCore.Food(name: "Synthetic cereal", per100g: NutrientAmounts([.energy: 370]),
                                   servings: [Serving("bowl", grams: 41.123456789)])
        let previous = try store.log(food, serving: food.servings[0], quantity: 1.123456789, on: oldDate, meal: "Breakfast")
        food.per100g[.energy] = 380
        let now = Date(timeIntervalSince1970: 1_791_326_400)
        let draft = NutritionEntryDraft(store: store, food: food, date: today, meal: "Dinner", repeating: previous, now: now)
        let entry = try XCTUnwrap(draft.save())
        XCTAssertNotEqual(entry.id, previous.id)
        XCTAssertEqual(entry.date, today)
        XCTAssertEqual(entry.meal, "Dinner")
        XCTAssertEqual(entry.loggedAt, now)
        XCTAssertEqual(entry.grams, previous.grams)
        XCTAssertEqual(entry.quantity, previous.quantity)
        XCTAssertEqual(entry.serving, previous.serving)
        XCTAssertEqual(entry.food.per100g[.energy], 380)
        XCTAssertEqual(store.entries.first, previous)
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

    func testEntryDeletionAndUndoRefuseToOverwriteChangesAfterReview() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let date = try XCTUnwrap(LocalDate("2026-10-06"))
        let food = ExerlyCore.Food(name: "Synthetic pear", per100g: NutrientAmounts([.energy: 57, .sodium: 0]))
        var entry = try store.log(food, grams: 125.123456789, on: date, meal: "Snacks")
        let actions = NutritionDiaryActions(store: store)
        let reviewed = entry
        entry.meal = "Lunch"
        try store.saveEntry(entry)
        XCTAssertFalse(actions.delete(reviewed))
        XCTAssertEqual(store.entries.first, entry)
        XCTAssertNil(actions.deleted)
        XCTAssertTrue(actions.delete(entry))
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(actions.deleted, entry)
        XCTAssertTrue(actions.undoDeletion())
        XCTAssertEqual(store.entries.first, entry)
        XCTAssertNil(actions.deleted)
        XCTAssertTrue(actions.delete(entry))
        entry.grams = 40
        try store.saveEntry(entry)
        XCTAssertFalse(actions.undoDeletion())
        XCTAssertEqual(store.entries.first, entry)
        XCTAssertNotNil(actions.error)
    }

    func testFailedDeletionKeepsTheEntryAndDoesNotOfferUndo() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = try TrainingWorkspace(accountID: UUID().uuidString, root: root)
        let date = try XCTUnwrap(LocalDate("2026-10-06"))
        let food = ExerlyCore.Food(name: "Synthetic pear", per100g: NutrientAmounts([.energy: 57]))
        let entry = try workspace.nutrition.log(food, grams: 125, on: date, meal: "Snacks")
        let actions = NutritionDiaryActions(store: workspace.nutrition)
        await workspace.close()
        XCTAssertFalse(actions.delete(entry))
        XCTAssertEqual(workspace.nutrition.entries.first, entry)
        XCTAssertNil(actions.deleted)
        XCTAssertNotNil(actions.error)
    }
}

@MainActor
final class NutritionDiaryPresentationTests: XCTestCase {
    func testKeepingADatabaseFavoriteDoesNotOverwriteANewerSavedLabel() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let food = ExerlyCore.Food(id: "off:0012345678905", name: "Synthetic oat bar", source: .openFoodFacts,
                                  per100g: NutrientAmounts([.energy: 410, .sodium: 0]))
        let actions = NutritionLibraryActions(store: store)
        XCTAssertTrue(actions.keepFavorite(food, reviewed: nil))
        var saved = try XCTUnwrap(store.food(food.id))
        XCTAssertTrue(saved.favorite)
        XCTAssertEqual(saved.source, .openFoodFacts)
        XCTAssertEqual(saved.per100g, food.per100g)
        let reviewed = saved
        saved.name = "Newer saved label"
        try store.saveFood(saved)
        XCTAssertFalse(actions.keepFavorite(food, reviewed: nil))
        XCTAssertFalse(actions.keepFavorite(food, reviewed: reviewed))
        XCTAssertEqual(store.food(food.id), saved)
    }

    func testLibraryActionsPreserveLoggedSnapshotsAndCanRestoreAnArchivedFood() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let date = try XCTUnwrap(LocalDate("2026-10-06"))
        let food = ExerlyCore.Food(name: "Synthetic pear", per100g: NutrientAmounts([.energy: 57, .sodium: 0]))
        try store.saveFood(food)
        let entry = try store.log(food, grams: 123.25, on: date, meal: "Dinner")
        let actions = NutritionLibraryActions(store: store)
        XCTAssertTrue(actions.setFavorite(true, reviewed: food))
        let favorite = try XCTUnwrap(store.food(food.id))
        XCTAssertTrue(favorite.favorite)
        XCTAssertTrue(actions.archive(reviewed: favorite))
        let archived = try XCTUnwrap(store.food(food.id))
        XCTAssertNotNil(archived.archivedAt)
        XCTAssertEqual(store.entries, [entry])
        XCTAssertTrue(actions.restore(reviewed: archived))
        XCTAssertNil(store.food(food.id)?.archivedAt)
        XCTAssertEqual(store.entries, [entry])
    }

    func testLibraryActionsRefuseStaleFavoriteArchiveAndRestoreReviews() throws {
        let persistence = InMemoryTrainingPersistence()
        let store = try NutritionStore(persistence: persistence)
        let food = ExerlyCore.Food(name: "Synthetic pear", per100g: NutrientAmounts([.energy: 57]))
        try store.saveFood(food)
        let actions = NutritionLibraryActions(store: store)
        var updated = food
        updated.name = "Updated pear label"
        try store.saveFood(updated)
        XCTAssertFalse(actions.archive(reviewed: food))
        XCTAssertFalse(actions.setFavorite(true, reviewed: food))
        XCTAssertEqual(store.food(food.id), updated)
        XCTAssertNotNil(actions.error)
        try store.archiveFood(food.id)
        let archived = try XCTUnwrap(store.food(food.id))
        var newer = archived
        newer.name = "New archived label"
        try store.saveFood(newer)
        XCTAssertFalse(actions.restore(reviewed: archived))
        XCTAssertEqual(store.food(food.id), newer)
    }

    func testNotesSaveKeepsStatusAndRefusesToOverwriteANewerNote() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let date = try XCTUnwrap(LocalDate("2026-10-06"))
        try store.setNotes("Original note", on: date)
        let draft = NutritionDayNotesDraft(store: store, date: date)
        draft.text = "Lunch after training"
        try store.setStatus(.partial, on: date)
        XCTAssertTrue(draft.save())
        XCTAssertEqual(store.day(date).notes, "Lunch after training")
        XCTAssertEqual(store.day(date).status, .partial)
        let stale = NutritionDayNotesDraft(store: store, date: date)
        stale.text = "My unsaved note"
        try store.setNotes("Note from another device", on: date)
        XCTAssertFalse(stale.save())
        XCTAssertEqual(stale.text, "My unsaved note")
        XCTAssertEqual(store.day(date).notes, "Note from another device")
    }

    func testDayStatusRefusesAChangedReviewAndNeverDeletesFood() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let date = try XCTUnwrap(LocalDate("2026-10-06"))
        let food = ExerlyCore.Food(name: "Synthetic apple", per100g: NutrientAmounts([.energy: 52]))
        let entry = try store.log(food, grams: 110, on: date, meal: "Lunch")
        let actions = NutritionDiaryActions(store: store)
        let reviewed = store.day(date)
        XCTAssertTrue(actions.setStatus(.complete, reviewed: reviewed, entries: [entry]))
        XCTAssertEqual(store.entries, [entry])
        XCTAssertFalse(actions.setStatus(.fasting, reviewed: reviewed, entries: [entry]))
        XCTAssertEqual(store.day(date).status, .complete)
        let latest = store.day(date)
        _ = try store.log(food, grams: 20, on: date, meal: "Dinner")
        XCTAssertFalse(actions.setStatus(.fasting, reviewed: latest, entries: [entry]))
        XCTAssertEqual(store.entries.count, 2)
    }

    func testCopyPreservesSnapshotsAndCannotDuplicateOnRepeatedConfirmation() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let source = try XCTUnwrap(LocalDate("2026-10-05"))
        let target = try XCTUnwrap(LocalDate("2026-10-06"))
        let food = ExerlyCore.Food(name: "Synthetic cereal", per100g: NutrientAmounts([.energy: 360, .sodium: 0]))
        let original = try store.log(food, grams: 42.123456789, on: source, meal: "Breakfast")
        let draft = NutritionCopyDraft(store: store, source: source, meal: "Breakfast", target: target)
        draft.targetMeal = "Dinner"
        let copies = try XCTUnwrap(draft.copy())
        XCTAssertEqual(copies.count, 1)
        XCTAssertEqual(copies.first?.food, original.food)
        XCTAssertEqual(copies.first?.grams, original.grams)
        XCTAssertEqual(copies.first?.date, target)
        XCTAssertEqual(copies.first?.meal, "Dinner")
        XCTAssertNotEqual(copies.first?.id, original.id)
        XCTAssertNil(draft.copy())
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.entries(on: source), [original])
    }

    func testCopyRefusesChangedSourceEntriesAndKeepsTheDestination() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let source = try XCTUnwrap(LocalDate("2026-10-05"))
        let target = try XCTUnwrap(LocalDate("2026-10-06"))
        let food = ExerlyCore.Food(name: "Synthetic cereal", per100g: NutrientAmounts([.energy: 360]))
        var original = try store.log(food, grams: 40, on: source, meal: "Breakfast")
        let existing = try store.log(food, grams: 80, on: target, meal: "Dinner")
        let draft = NutritionCopyDraft(store: store, source: source, meal: nil, target: target)
        original.grams = 50
        try store.saveEntry(original)
        XCTAssertNil(draft.copy())
        XCTAssertNotNil(draft.error)
        XCTAssertEqual(store.entries(on: target), [existing])
        XCTAssertEqual(draft.entries.first?.grams, 40)
    }
}

@MainActor
final class NutritionSearchTests: XCTestCase {
    func testSubmittedSearchKeepsSourceAndUnknownNutrientsAndSkipsBlankQueries() async throws {
        let transport = NutritionSearchTransport()
        let model = NutritionSearchModel(api: AccountAPI(accountID: "food-account", transport: transport))
        await model.search("  \n ")
        let emptyRequests = await transport.requests()
        XCTAssertTrue(emptyRequests.isEmpty)
        XCTAssertNil(model.request)
        await model.search("  pear + oats  ")
        let requests = await transport.requests()
        XCTAssertEqual(requests.first?.accountID, "food-account")
        XCTAssertEqual(requests.first?.path, "/v1/foods/search?q=pear%20%2B%20oats&limit=20")
        XCTAssertEqual(model.result?.foods.first?.source, .openFoodFacts)
        XCTAssertEqual(model.result?.foods.first?.per100g[.sodium], 0)
        XCTAssertNil(model.result?.foods.first?.per100g[.iron])
        XCTAssertEqual(model.result?.attribution, "Synthetic Open Food Facts attribution")
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.error)
    }

    func testOlderSearchCannotReplaceANewerResult() async throws {
        let began = expectation(description: "First search began")
        let transport = NutritionSearchTransport(onFirstRequest: { began.fulfill() }, holdFirst: true)
        let model = NutritionSearchModel(api: AccountAPI(accountID: "food-account", transport: transport))
        let first = Task { await model.search("old") }
        await fulfillment(of: [began], timeout: 3)
        await model.search("new")
        XCTAssertEqual(model.result?.foods.first?.name, "Synthetic new food")
        await transport.finishFirst()
        await first.value
        XCTAssertEqual(model.result?.foods.first?.name, "Synthetic new food")
        XCTAssertFalse(model.isLoading)
    }

    func testClosedSearchCannotRepopulateAfterAnAccountSwitch() async throws {
        let began = expectation(description: "Search began")
        let transport = NutritionSearchTransport(onFirstRequest: { began.fulfill() }, holdFirst: true)
        let model = NutritionSearchModel(api: AccountAPI(accountID: "old-account", transport: transport))
        let pending = Task { await model.search("old") }
        await fulfillment(of: [began], timeout: 3)
        model.close()
        await transport.finishFirst()
        await pending.value
        XCTAssertNil(model.result)
        XCTAssertNil(model.error)
        XCTAssertFalse(model.isLoading)
        await model.search("new")
        let requests = await transport.requests()
        XCTAssertEqual(requests.count, 1)
    }

    func testCompactBarcodeKeepsTheCameraFormatAndDoesNotGuessManualDigits() async throws {
        let transport = NutritionSearchTransport()
        let model = NutritionSearchModel(api: AccountAPI(accountID: "food-account", transport: transport))
        await model.lookup(" 04252614 ", symbology: .upcE)
        await model.lookup("04252614", symbology: .ean8)
        await model.lookup("04252614")
        let paths = await transport.requests().map(\.path)
        XCTAssertEqual(paths, ["/v1/foods/barcode/04252614?symbology=upce",
                               "/v1/foods/barcode/04252614?symbology=ean8",
                               "/v1/foods/barcode/04252614"])
    }

    func testBarcodeNotFoundIsDifferentFromUnavailableAndCanBeRetried() async throws {
        let transport = NutritionSearchTransport()
        let model = NutritionSearchModel(api: AccountAPI(accountID: "food-account", transport: transport))
        await model.lookup("00000000")
        XCTAssertNotNil(model.request)
        XCTAssertNil(model.result)
        XCTAssertNil(model.error)
        XCTAssertFalse(model.isLoading)
        await model.lookup("11111111")
        XCTAssertNotNil(model.error)
        XCTAssertNil(model.result)
        await model.lookup("22222222")
        XCTAssertNil(model.error)
        XCTAssertEqual(model.result?.foods.count, 1)
        model.clear()
        XCTAssertNil(model.request)
        XCTAssertNil(model.result)
    }

    func testInvalidBarcodeAndBusyProviderKeepTheirActionableMessages() async throws {
        let model = NutritionSearchModel(api: AccountAPI(accountID: "food-account", transport: NutritionSearchTransport()))
        await model.lookup("33333333")
        XCTAssertEqual(model.error, "Choose EAN-8 or UPC-E for an eight-digit code.")
        await model.lookup("44444444")
        XCTAssertEqual(model.error, "Food lookups are busy. Try again shortly.")
        XCTAssertFalse(model.isLoading)
    }
}

private actor NutritionSearchTransport: SessionTransport {
    struct Request: Sendable {
        let accountID: String
        let path: String
    }
    private var received: [Request] = []
    private let onFirstRequest: @Sendable () -> Void
    private var holdFirst: Bool
    private var pending: CheckedContinuation<Void, Never>?

    init(onFirstRequest: @escaping @Sendable () -> Void = {}, holdFirst: Bool = false) {
        self.onFirstRequest = onFirstRequest
        self.holdFirst = holdFirst
    }
    func requests() -> [Request] { received }
    func finishFirst() { holdFirst = false; pending?.resume(); pending = nil }

    func send(_ method: String, path: String, body: Data?, headers: [String: String],
              as accountID: String) async throws -> (status: Int, data: Data) {
        received.append(Request(accountID: accountID, path: path))
        if received.count == 1 {
            onFirstRequest()
            if holdFirst { await withCheckedContinuation { pending = $0 } }
        }
        if path.hasSuffix("00000000") { return (404, Data("{}".utf8)) }
        if path.hasSuffix("11111111") { throw URLError(.notConnectedToInternet) }
        if path.hasSuffix("33333333") {
            return (400, Data(#"{"message":"Choose EAN-8 or UPC-E for an eight-digit code."}"#.utf8))
        }
        if path.hasSuffix("44444444") {
            return (429, Data(#"{"message":"Food lookups are busy. Try again shortly."}"#.utf8))
        }
        let name = path.contains("q=old") ? "Synthetic old food" : "Synthetic new food"
        let food = ExerlyCore.Food(id: "off:22222222", name: name, source: .openFoodFacts,
                                   per100g: NutrientAmounts([.energy: 55, .sodium: 0]))
        let row = try JSONSerialization.jsonObject(with: ExerlyJSON.canonical(food))
        let payload: [String: Any] = path.contains("/barcode/")
            ? ["food": row, "attribution": "Synthetic Open Food Facts attribution"]
            : ["foods": [row], "attribution": "Synthetic Open Food Facts attribution"]
        return (200, try JSONSerialization.data(withJSONObject: payload))
    }
}
