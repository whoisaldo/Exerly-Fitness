import ExerlyCore
import XCTest
@testable import Exerly

@MainActor
final class NutritionQuickAddPresentationTests: XCTestCase {
    func testWholePortionKeepsUnknownMacrosAndCannotSaveTwice() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let date = try XCTUnwrap(LocalDate("2026-10-07"))
        let draft = NutritionQuickAddDraft(store: store, date: date, meal: "Lunch")
        draft.fields[.energy]?.text = "650"
        draft.fields[.fat]?.text = "0"
        let entry = try XCTUnwrap(draft.save(ownerIsActive: true))
        XCTAssertEqual(entry.date, date)
        XCTAssertEqual(entry.meal, "Lunch")
        XCTAssertEqual(entry.food.name, "Quick add")
        XCTAssertEqual(entry.food.unweighed, true)
        XCTAssertEqual(entry.nutrients[.energy], 650)
        XCTAssertEqual(entry.nutrients[.fat], 0)
        XCTAssertNil(entry.nutrients[.protein])
        XCTAssertNil(entry.nutrients[.carbohydrate])
        XCTAssertNil(draft.save(ownerIsActive: true))
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertTrue(store.foods.isEmpty)
        XCTAssertTrue(store.recentFoods().isEmpty)
        XCTAssertFalse(NutritionFormat.portion(entry, unit: .kilograms).contains("100"))
    }

    func testMacrosOnlyAcceptsLocaleDecimalsWithoutInventingCalories() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let draft = NutritionQuickAddDraft(store: store, date: try XCTUnwrap(LocalDate("2026-10-07")), meal: "Dinner")
        draft.name = "  Restaurant dinner  "
        draft.fields[.protein]?.text = "32,5"
        draft.fields[.carbohydrate]?.text = "46,25"
        let entry = try XCTUnwrap(draft.save(ownerIsActive: true, locale: Locale(identifier: "fr_FR")))
        XCTAssertEqual(entry.food.name, "Restaurant dinner")
        XCTAssertEqual(entry.nutrients[.protein], 32.5)
        XCTAssertEqual(entry.nutrients[.carbohydrate], 46.25)
        XCTAssertNil(entry.nutrients[.energy])
        XCTAssertNil(entry.nutrients[.fat])
    }

    func testInvalidInputsAndChangedAccountKeepTheDraftWithoutWriting() throws {
        let store = try NutritionStore(persistence: InMemoryTrainingPersistence())
        let draft = NutritionQuickAddDraft(store: store, date: try XCTUnwrap(LocalDate("2026-10-07")), meal: "Snacks")
        for input in ["", "-2", "NaN", "200 calories", "1e309"] {
            draft.fields[.energy]?.text = input
            XCTAssertNil(draft.save(ownerIsActive: true))
            XCTAssertEqual(draft.fields[.energy]?.text, input)
            XCTAssertFalse(draft.errors.isEmpty)
        }
        draft.fields[.energy]?.text = "350"
        XCTAssertNil(draft.save(ownerIsActive: false))
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertTrue(draft.hasChanges)
        XCTAssertNotNil(draft.save(ownerIsActive: true))
    }

    func testOfflineReopenAndNutrientCorrectionKeepAnUnweighedEntry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let account = UUID().uuidString
        let workspace = try TrainingWorkspace(accountID: account, root: root)
        let draft = NutritionQuickAddDraft(store: workspace.nutrition, date: try XCTUnwrap(LocalDate("2026-10-06")), meal: "Lunch")
        draft.fields[.energy]?.text = "525"
        let entry = try XCTUnwrap(draft.save(ownerIsActive: true))
        await workspace.close()
        let reopened = try TrainingWorkspace(accountID: account, root: root)
        XCTAssertEqual(reopened.nutrition.entries.first, entry)
        let correction = NutritionEntryNutrientsDraft(entry: entry)
        correction.fields[.energy]?.text = "550"
        let corrected = try correction.correctedEntry()
        try reopened.nutrition.saveEntry(corrected)
        XCTAssertEqual(corrected.food.unweighed, true)
        XCTAssertEqual(corrected.nutrients[.energy], 550)
        XCTAssertNil(corrected.nutrients[.protein])
        XCTAssertTrue(reopened.nutrition.foods.isEmpty)
        XCTAssertTrue(reopened.nutrition.recentFoods().isEmpty)
        await reopened.close()
    }
}
