import Combine
import ExerlyCore
import Foundation

/// A recipe being built or edited. Totals come from ExerlyCore's
/// `Food.recipe`, rebuilt from the draft as it changes.
@MainActor
final class RecipeDraft: ObservableObject {
    struct Row: Identifiable, Equatable {
        let id: UUID
        var ingredient: RecipeIngredient

        /// The ingredient as a diary entry, so the portion editor can open it.
        var entry: FoodEntry {
            FoodEntry(id: id, date: LocalDate(Date(timeIntervalSince1970: 0), in: .gmt), meal: "Recipe",
                      loggedAt: Date(timeIntervalSince1970: 0), food: ingredient.food, grams: ingredient.grams,
                      serving: ingredient.serving, quantity: ingredient.quantity)
        }
    }

    @Published var name: String
    @Published private(set) var rows: [Row]
    /// In the person's units: grams, or ounces for pounds.
    @Published var cookedWeight: NutritionNumberField
    @Published var servings: NutritionNumberField
    @Published var preparation: String
    @Published private(set) var errors: [String] = []
    let unit: MassUnit
    let isNew: Bool
    private let store: NutritionStore
    private let template: ExerlyCore.Food
    private var original: ExerlyCore.Food?
    private let initialCooked: NutritionNumberField
    private let initialServings: NutritionNumberField

    /// Edits a saved recipe, or starts a new one, empty or from `start`
    /// (a meal, or a copy of another recipe).
    init(store: NutritionStore, unit: MassUnit, editing: ExerlyCore.Food? = nil, start: ExerlyCore.Food? = nil) {
        self.store = store
        self.unit = unit
        original = editing
        isNew = editing == nil
        let food = editing ?? start ?? ExerlyCore.Food.recipe(name: "", ingredients: [], servingCount: 1)
        template = food
        name = food.name
        rows = (food.ingredients ?? []).map { Row(id: UUID(), ingredient: $0) }
        let cooked = NutritionNumberField(food.yieldGrams.map { unit == .pounds ? USUnits.ounces(grams: $0) : $0 })
        cookedWeight = cooked
        initialCooked = cooked
        let count = NutritionNumberField(food.servingCount ?? 1)
        servings = count
        initialServings = count
        preparation = food.preparation ?? ""
    }

    var hasChanges: Bool {
        (isNew && !rows.isEmpty) || name != template.name || rows.map(\.ingredient) != (template.ingredients ?? [])
            || cookedWeight != initialCooked || servings != initialServings || preparation != (template.preparation ?? "")
    }

    var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !rows.isEmpty }

    /// The recipe as it stands, for live totals; nil while a number is unreadable.
    var preview: ExerlyCore.Food? { try? recipe() }

    func recipe(locale: Locale = .current) throws -> ExerlyCore.Food {
        let typed = try cookedWeight.value(named: "the cooked weight", locale: locale)
        let cooked = cookedWeight == initialCooked ? template.yieldGrams : typed.map { unit == .pounds ? USUnits.grams(ounces: $0) : $0 }
        guard let count = try servings.value(named: "servings", locale: locale) else {
            throw NutritionDraftError.input("Enter how many servings it makes.")
        }
        var food = template.withIngredients(rows.map(\.ingredient), yieldGrams: cooked)
        food.source = .recipe
        food.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        food.servingCount = count
        let note = preparation.trimmingCharacters(in: .whitespacesAndNewlines)
        food.preparation = note.isEmpty ? nil : note
        return food
    }

    /// Adds a food at the portion one tap would log it: the amount last
    /// logged, or its first serving.
    @discardableResult
    func add(_ food: ExerlyCore.Food) -> Bool {
        guard food.id != template.id else { errors = ["A recipe can't include itself."]; return false }
        guard let portion = store.quickPortion(for: food, unit: unit) else {
            errors = ["\(food.name) has no weight, so it can't be an ingredient."]
            return false
        }
        rows.append(Row(id: UUID(), ingredient: RecipeIngredient(food: portion.food, grams: portion.grams,
                                                                 serving: portion.serving, quantity: portion.quantity)))
        errors = []
        return true
    }

    func update(_ id: UUID, to amount: LoggedAmount, food: FoodSnapshot) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[index].ingredient = RecipeIngredient(food: food, grams: amount.grams, serving: amount.serving, quantity: amount.quantity)
    }

    func remove(_ id: UUID) { rows.removeAll { $0.id == id } }

    func move(from source: IndexSet, to destination: Int) { rows.move(fromOffsets: source, toOffset: destination) }

    @discardableResult
    func save(locale: Locale = .current) -> ExerlyCore.Food? {
        errors = []
        guard store.food(template.id) == original else {
            errors = ["This recipe changed while you were editing. Your draft is still here. Reopen the recipe to review the latest version."]
            return nil
        }
        do {
            let food = try recipe(locale: locale)
            try store.saveFood(food)
            original = food
            return food
        } catch { errors = NutritionDraftError.messages(error) }
        return nil
    }
}
