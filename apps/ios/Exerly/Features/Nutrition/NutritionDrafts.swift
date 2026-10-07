import Combine
import ExerlyCore
import Foundation

/// The text shown for an existing value may be rounded, but leaving it alone
/// must not round the stored value as a side effect of editing another field.
struct NutritionNumberField: Equatable {
    var text: String
    private let initialText: String
    private let original: Double?

    init(_ value: Double? = nil) {
        original = value
        text = value.map(TrainingFormat.number) ?? ""
        initialText = text
    }

    func value(named name: String, locale: Locale) throws -> Double? {
        if text == initialText { return original }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        guard let value = TrainingInput.number(text, locale: locale) else {
            throw NutritionDraftError.input("Enter a number for \(name), or leave it blank if unknown.")
        }
        return value
    }
}

enum NutritionDraftError: LocalizedError {
    case input(String)
    var errorDescription: String? {
        switch self {
        case .input(let message): message
        }
    }

    static func messages(_ error: Error) -> [String] {
        if case NutritionStore.StoreError.invalid(let messages) = error { return messages }
        if let error = error as? NutritionDraftError { return [error.localizedDescription] }
        return ["Could not save. Your draft is still here. Try again."]
    }
}

struct NutritionServingFields: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var grams: NutritionNumberField

    init(_ serving: Serving? = nil) {
        name = serving?.name ?? ""
        grams = NutritionNumberField(serving?.grams)
    }

    func value(locale: Locale) throws -> Serving {
        guard let amount = try grams.value(named: "serving weight", locale: locale) else {
            throw NutritionDraftError.input("Enter the serving's weight in grams.")
        }
        return Serving(name.trimmingCharacters(in: .whitespacesAndNewlines), grams: amount)
    }
}

@MainActor
final class NutritionFoodDraft: ObservableObject {
    enum Basis: String, CaseIterable { case per100g = "Per 100 g", perServing = "Per serving" }
    @Published var name: String
    @Published var brand: String
    @Published var nutrients: [Nutrient: NutritionNumberField]
    @Published var servings: [NutritionServingFields]
    @Published var basis = Basis.per100g
    @Published var labelGrams = NutritionNumberField()
    @Published var favorite: Bool
    @Published private(set) var errors: [String] = []
    private let store: NutritionStore
    private var original: ExerlyCore.Food?
    private let template: ExerlyCore.Food
    private let initialNutrients: [Nutrient: NutritionNumberField]
    private let initialServings: [NutritionServingFields]

    init(store: NutritionStore, editing: ExerlyCore.Food? = nil) {
        self.store = store
        original = editing
        let food = editing ?? ExerlyCore.Food(name: "", per100g: NutrientAmounts())
        template = food
        name = food.name
        brand = food.brand ?? ""
        favorite = food.favorite
        let fields = Dictionary(uniqueKeysWithValues: Nutrient.allCases.map { ($0, NutritionNumberField(food.per100g[$0])) })
        nutrients = fields
        initialNutrients = fields
        let portions = food.servings.map { NutritionServingFields($0) }
        servings = portions
        initialServings = portions
    }

    var hasChanges: Bool {
        name != template.name || brand != (template.brand ?? "") || favorite != template.favorite ||
            nutrients != initialNutrients || servings != initialServings || basis != .per100g || !labelGrams.text.isEmpty
    }

    func food(locale: Locale = .current) throws -> ExerlyCore.Food {
        var amounts = NutrientAmounts()
        for nutrient in Nutrient.allCases {
            amounts[nutrient] = try nutrients[nutrient]?.value(named: nutrient.name, locale: locale)
        }
        if basis == .perServing {
            guard let weight = try labelGrams.value(named: "label serving weight", locale: locale) else {
                throw NutritionDraftError.input("Enter the weight for the label's serving.")
            }
            amounts = try ExerlyCore.Food.per100g(fromLabel: amounts, servingGrams: weight)
        }
        var food = template
        food.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        food.brand = cleanBrand.isEmpty ? nil : cleanBrand
        food.per100g = amounts
        food.servings = try servings.map { try $0.value(locale: locale) }
        food.favorite = favorite
        return food
    }

    @discardableResult
    func save(locale: Locale = .current) -> ExerlyCore.Food? {
        errors = []
        guard store.food(template.id) == original else {
            errors = ["This food changed while you were editing. Your draft is still here. Reopen the food to review the latest version."]
            return nil
        }
        do {
            let food = try food(locale: locale)
            try store.saveFood(food)
            original = food
            return food
        } catch { errors = NutritionDraftError.messages(error) }
        return nil
    }
}

@MainActor
final class NutritionEntryDraft: ObservableObject {
    @Published var amount: NutritionNumberField
    @Published var serving: Serving?
    @Published var date: LocalDate
    @Published var meal: String
    @Published var loggedAt: Date
    @Published private(set) var errors: [String] = []
    let food: ExerlyCore.Food
    private let store: NutritionStore
    private var original: FoodEntry?
    private let entryID: UUID
    private let initialAmount: NutritionNumberField
    private let initialServing: Serving?
    private let initialDate: LocalDate
    private let initialMeal: String
    private let initialTime: Date
    private let initialPortion: FoodEntry?

    init(store: NutritionStore, food: ExerlyCore.Food, date: LocalDate, meal: String,
         editing: FoodEntry? = nil, repeating: FoodEntry? = nil, now: Date = Date()) {
        self.store = store
        if let editing {
            let snapshot = editing.food
            self.food = ExerlyCore.Food(id: snapshot.foodID, name: snapshot.name, brand: snapshot.brand,
                                       source: snapshot.source, per100g: snapshot.per100g,
                                       servings: editing.serving.map { [$0] } ?? [])
        } else { self.food = food }
        original = editing
        entryID = editing?.id ?? UUID()
        let previous = editing ?? repeating.flatMap { $0.food.foodID == food.id ? $0 : nil }
        initialPortion = previous
        serving = previous?.serving
        initialServing = previous?.serving
        let field = NutritionNumberField(previous.map { $0.serving == nil ? $0.grams : ($0.quantity ?? 1) } ?? 100)
        amount = field
        initialAmount = field
        self.date = editing?.date ?? date
        initialDate = editing?.date ?? date
        self.meal = editing?.meal ?? meal
        initialMeal = editing?.meal ?? meal
        loggedAt = editing?.loggedAt ?? now.roundedToMilliseconds
        initialTime = editing?.loggedAt ?? now.roundedToMilliseconds
    }

    var hasChanges: Bool {
        amount != initialAmount || serving != initialServing || date != initialDate || meal != initialMeal || loggedAt != initialTime
    }

    func preview(locale: Locale = .current) throws -> LoggedAmount {
        guard let value = try amount.value(named: serving == nil ? "grams" : "quantity", locale: locale) else {
            throw NutritionDraftError.input("Enter an amount to log.")
        }
        if let initialPortion, amount == initialAmount, serving == initialServing {
            return try NutritionStore.preview(food, grams: initialPortion.grams, serving: initialPortion.serving, quantity: initialPortion.quantity)
        }
        return try NutritionStore.preview(food, grams: serving == nil ? value : nil,
                                          serving: serving, quantity: serving == nil ? nil : value)
    }

    @discardableResult
    func save(locale: Locale = .current) -> FoodEntry? {
        errors = []
        guard store.entries.first(where: { $0.id == entryID }) == original else {
            errors = ["This entry changed while you were editing. Your draft is still here. Reopen the entry to review the latest version."]
            return nil
        }
        do {
            let portion = try preview(locale: locale)
            var entry = FoodEntry(id: entryID, date: date, meal: meal.trimmingCharacters(in: .whitespacesAndNewlines),
                                  loggedAt: loggedAt.roundedToMilliseconds, food: original?.food ?? food.snapshot,
                                  grams: portion.grams, serving: portion.serving, quantity: portion.quantity)
            if let original, amount == initialAmount, serving == initialServing {
                entry.grams = original.grams
                entry.serving = original.serving
                entry.quantity = original.quantity
            }
            try store.saveEntry(entry)
            original = entry
            return entry
        } catch { errors = NutritionDraftError.messages(error) }
        return nil
    }
}

@MainActor
final class NutritionDiaryActions: ObservableObject {
    @Published private(set) var deleted: FoodEntry?
    @Published private(set) var error: String?
    private let store: NutritionStore

    init(store: NutritionStore) { self.store = store }

    func clearError() { error = nil }

    @discardableResult
    func setStatus(_ status: DayStatus, reviewed: NutritionDay, entries: [FoodEntry]) -> Bool {
        error = nil
        guard store.day(reviewed.date) == reviewed, store.entries(on: reviewed.date) == entries else {
            error = "This day's log changed after you opened the review. Review the latest entries before changing its status."
            return false
        }
        do {
            try store.setStatus(status, on: reviewed.date)
            return true
        } catch {
            self.error = "Could not change the logging status. Your saved status is unchanged. Try again."
            return false
        }
    }

    @discardableResult
    func delete(_ reviewed: FoodEntry) -> Bool {
        error = nil
        guard store.entries.first(where: { $0.id == reviewed.id }) == reviewed else {
            error = "This entry changed after you opened it. Reopen it to review the latest version before deleting."
            return false
        }
        do {
            try store.deleteEntry(reviewed.id)
            deleted = reviewed
            return true
        } catch {
            self.error = "Could not delete this entry. It is still saved. Try again."
            return false
        }
    }

    @discardableResult
    func undoDeletion() -> Bool {
        error = nil
        guard let deleted else { return false }
        guard !store.entries.contains(where: { $0.id == deleted.id }) else {
            error = "This entry was restored or changed elsewhere. Undo would overwrite it. Review the saved entry instead."
            return false
        }
        do {
            try store.saveEntry(deleted)
            self.deleted = nil
            return true
        } catch {
            self.error = "Could not undo the deletion. Try again."
            return false
        }
    }
}

@MainActor
final class NutritionDayNotesDraft: ObservableObject {
    @Published var text: String
    @Published private(set) var error: String?
    private let store: NutritionStore
    private let date: LocalDate
    private var original: String

    init(store: NutritionStore, date: LocalDate) {
        self.store = store
        self.date = date
        original = store.day(date).notes
        text = original
    }

    var hasChanges: Bool { text != original }

    @discardableResult
    func save() -> Bool {
        error = nil
        guard store.day(date).notes == original else {
            error = "This note changed on another screen or device. Your draft is still here. Reopen the note to review the latest version."
            return false
        }
        do {
            try store.setNotes(text, on: date)
            original = text
            return true
        } catch {
            self.error = "Could not save the note. Your draft is still here. Try again."
            return false
        }
    }
}

@MainActor
final class NutritionCopyDraft: ObservableObject {
    let source: LocalDate
    let sourceMeal: String?
    let entries: [FoodEntry]
    @Published var target: LocalDate
    @Published var targetMeal: String?
    @Published private(set) var error: String?
    @Published private(set) var completed = false
    private let store: NutritionStore

    init(store: NutritionStore, source: LocalDate, meal: String?, target: LocalDate) {
        self.store = store
        self.source = source
        sourceMeal = meal
        self.target = target
        targetMeal = meal
        entries = store.entries(on: source).filter { meal == nil || $0.meal == meal }
    }

    @discardableResult
    func copy() -> [FoodEntry]? {
        guard !completed else { return nil }
        error = nil
        guard store.entries(on: source).filter({ sourceMeal == nil || $0.meal == sourceMeal }) == entries else {
            error = "The source log changed after you opened this review. Reopen Copy to review the latest entries."
            return nil
        }
        guard !entries.isEmpty else { error = "There are no entries to copy."; return nil }
        do {
            let copied = try store.copy(from: source, meal: sourceMeal, to: target, meal: targetMeal)
            completed = true
            return copied
        } catch {
            self.error = "Could not copy these entries. No copies were saved. Try again."
            return nil
        }
    }
}
