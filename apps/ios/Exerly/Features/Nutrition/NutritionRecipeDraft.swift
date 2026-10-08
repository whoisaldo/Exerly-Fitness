import Combine
import ExerlyCore
import Foundation

@MainActor
final class NutritionRecipeDraft: ObservableObject {
    struct Row: Identifiable, Equatable {
        let id: UUID
        let food: ExerlyCore.Food
        let ingredient: RecipeIngredient
        let serving: Serving?
        let quantity: Double?

        func entry(on date: LocalDate) -> FoodEntry {
            FoodEntry(id: id, date: date, meal: "Recipe", loggedAt: .now, food: ingredient.food,
                      grams: ingredient.grams, serving: serving, quantity: quantity)
        }
    }

    @Published var name: String
    @Published var preparation: String
    @Published var servingCount: NutritionNumberField
    @Published var cookedWeight: NutritionNumberField
    @Published private(set) var rows: [Row]
    @Published private(set) var errors: [String] = []
    @Published private(set) var saved: ExerlyCore.Food?
    let unit: MassUnit
    private let store: NutritionStore
    private let original: ExerlyCore.Food?
    private let template: ExerlyCore.Food
    private let initialRows: [Row]
    private let initialWeight: NutritionNumberField
    private let initialCount: NutritionNumberField

    init(store: NutritionStore, editing: ExerlyCore.Food? = nil, unit: MassUnit = .pounds) {
        self.store = store
        self.unit = unit
        original = editing
        let food = editing ?? ExerlyCore.Food.recipe(name: "", ingredients: [], servingCount: 1)
        template = food
        name = food.name
        preparation = food.preparation ?? ""
        let weight = NutritionNumberField(food.yieldGrams.map { unit == .pounds ? USUnits.ounces(grams: $0) : $0 })
        cookedWeight = weight
        initialWeight = weight
        let count = NutritionNumberField(food.servingCount)
        servingCount = count
        initialCount = count
        let ingredients = (food.ingredients ?? []).map {
            Row(id: UUID(), food: $0.food.foodForLogging(), ingredient: $0, serving: nil, quantity: nil)
        }
        rows = ingredients
        initialRows = ingredients
    }

    var hasChanges: Bool {
        name != template.name || preparation != (template.preparation ?? "") || rows != initialRows ||
            cookedWeight != initialWeight || servingCount != initialCount
    }

    var weightUnit: String { unit == .pounds ? "oz" : "g" }

    var summary: LoggedAmount? {
        guard let food = try? recipe(preview: true) else { return nil }
        return Self.summary(food)
    }

    static func summary(_ food: ExerlyCore.Food) -> LoggedAmount? {
        if let serving = food.recipeServing { return try? NutritionStore.preview(food, serving: serving, quantity: 1) }
        guard let whole = food.recipeGrams else { return nil }
        return try? NutritionStore.preview(food, grams: whole)
    }

    @discardableResult
    func add(_ food: ExerlyCore.Food) -> Bool {
        let date = LocalDate(.now, in: .current)
        let portion = NutritionEntryDraft(store: store, food: food, date: date, meal: "Recipe",
            repeating: store.entries.last { $0.food.foodID == food.id }, preferredUnit: unit)
        do { return stage(food, amount: try portion.preview()) } catch { errors = NutritionDraftError.messages(error); return false }
    }

    @discardableResult
    func stage(_ food: ExerlyCore.Food, amount: LoggedAmount, replacing reviewed: Row? = nil) -> Bool {
        guard saved == nil else { return false }
        do {
            // Validate the chosen amount through Core. An edited ingredient keeps
            // its reviewed snapshot even if the reusable food changed elsewhere.
            let snapshot = reviewed?.ingredient.food ?? food.snapshot
            let checked = try NutritionStore.preview(snapshot.foodForLogging(serving: amount.serving),
                grams: amount.grams, serving: amount.serving, quantity: amount.quantity)
            let row = Row(id: reviewed?.id ?? UUID(), food: reviewed?.food ?? food,
                          ingredient: RecipeIngredient(food: snapshot, grams: checked.grams),
                          serving: checked.serving, quantity: checked.quantity)
            if let reviewed {
                guard let index = rows.firstIndex(of: reviewed) else {
                    throw NutritionDraftError.input("This ingredient changed. Reopen it to review the current portion.")
                }
                rows[index] = row
            } else { rows.append(row) }
            errors = []
            return true
        } catch { errors = NutritionDraftError.messages(error); return false }
    }

    @discardableResult
    func remove(_ row: Row) -> Bool {
        guard saved == nil, rows.contains(row) else { return false }
        rows.removeAll { $0.id == row.id }
        errors = []
        return true
    }

    @discardableResult
    func move(_ row: Row, by offset: Int) -> Bool {
        guard saved == nil, let index = rows.firstIndex(of: row), rows.indices.contains(index + offset) else { return false }
        rows.remove(at: index)
        rows.insert(row, at: index + offset)
        errors = []
        return true
    }

    func recipe(locale: Locale = .current, preview: Bool = false) throws -> ExerlyCore.Food {
        let yield: Double?
        if cookedWeight == initialWeight { yield = template.yieldGrams } else {
            yield = try cookedWeight.value(named: "finished weight", locale: locale)
                .map { unit == .pounds ? USUnits.grams(ounces: $0) : $0 }
        }
        var food = template.withIngredients(rows.map(\.ingredient), yieldGrams: yield)
        food.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if preview && food.name.isEmpty { food.name = "Recipe preview" }
        food.servingCount = try servingCount.value(named: "servings", locale: locale)
        let notes = preparation.trimmingCharacters(in: .whitespacesAndNewlines)
        food.preparation = notes.isEmpty ? nil : notes
        // Use the same domain validation as the eventual write without changing
        // this account's foods or diary while someone is still reviewing.
        let validation = try NutritionStore(persistence: InMemoryTrainingPersistence())
        try validation.saveFood(food)
        return food
    }

    @discardableResult
    func save(ownerIsActive: Bool, locale: Locale = .current) -> ExerlyCore.Food? {
        guard ownerIsActive else { errors = ["Sign in again before saving. Your recipe draft is still here."]; return nil }
        if let saved { return saved }
        guard store.food(template.id) == original else {
            errors = ["This recipe changed while you were editing. Reopen it to review the latest version."]
            return nil
        }
        do {
            let food = try recipe(locale: locale)
            try store.saveFood(food)
            saved = food
            errors = []
            return food
        } catch { errors = NutritionDraftError.messages(error); return nil }
    }
}
