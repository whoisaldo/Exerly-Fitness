import Combine
import ExerlyCore
import Foundation

@MainActor
final class NutritionPlateDraft: ObservableObject {
    struct Row: Identifiable, Equatable {
        let id: UUID
        let food: ExerlyCore.Food
        let amount: LoggedAmount

        func entry(on date: LocalDate, meal: String, at time: Date) -> FoodEntry {
            FoodEntry(id: id, date: date, meal: meal, loggedAt: time, food: food.snapshot,
                      grams: amount.grams, serving: amount.serving, quantity: amount.quantity)
        }

        var item: NutritionStore.PlateItem {
            NutritionStore.PlateItem(food, grams: amount.grams, serving: amount.serving, quantity: amount.quantity)
        }
    }

    @Published private(set) var rows: [Row] = []
    @Published private(set) var summary: NutritionSummary?
    @Published private(set) var progress: DayProgress?
    @Published private(set) var error: String?
    @Published var date: LocalDate
    @Published var meal: String
    @Published var loggedAt: Date
    let unit: MassUnit
    private let store: NutritionStore
    private let previewDate: LocalDate
    private var saved: [FoodEntry]?

    init(store: NutritionStore, date: LocalDate, meal: String, unit: MassUnit = .pounds, now: Date = Date()) {
        self.store = store
        self.date = date
        self.meal = meal
        self.unit = unit
        self.previewDate = date
        loggedAt = now.roundedToMilliseconds
    }

    @discardableResult
    func add(_ food: ExerlyCore.Food) -> Bool {
        let draft = NutritionEntryDraft(store: store, food: food, date: date, meal: meal,
                                       repeating: store.entries.last { $0.food.foodID == food.id }, preferredUnit: unit)
        guard let entry = draft.reviewNutrition() else { error = draft.errors.joined(separator: " "); return false }
        do {
            let amount = try NutritionStore.preview(food, grams: entry.grams, serving: entry.serving,
                quantity: entry.quantity ?? entry.serving?.quantity(grams: entry.grams))
            return stage(food, amount: amount)
        } catch { self.error = NutritionDraftError.messages(error).joined(separator: " "); return false }
    }

    @discardableResult
    func stage(_ food: ExerlyCore.Food, amount: LoggedAmount, replacing reviewed: Row? = nil) -> Bool {
        guard saved == nil else { error = "This meal is already logged. Start a new meal to add more foods."; return false }
        let row = Row(id: reviewed?.id ?? UUID(), food: food, amount: amount)
        var updated = rows
        if let reviewed {
            guard let index = rows.firstIndex(of: reviewed) else {
                error = "This portion changed after you opened it. Reopen it to review the current amount."
                return false
            }
            updated[index] = row
        } else { updated.append(row) }
        return update(updated)
    }

    @discardableResult
    func remove(_ row: Row) -> Bool {
        guard saved == nil, rows.contains(row) else {
            error = "This meal changed. Review the current foods before removing a portion."
            return false
        }
        return update(rows.filter { $0.id != row.id })
    }

    @discardableResult
    func save() -> [FoodEntry]? {
        if let saved { return saved }
        error = nil
        guard !rows.isEmpty else { error = "Add at least one food to your meal."; return nil }
        do {
            let entries = try store.log(rows.map(\.item), on: date,
                                        meal: meal.trimmingCharacters(in: .whitespacesAndNewlines), at: loggedAt)
            saved = entries
            return entries
        } catch { self.error = NutritionDraftError.messages(error).joined(separator: " "); return nil }
    }

    private func update(_ proposed: [Row]) -> Bool {
        do {
            // Core validates and totals the complete draft without writing any
            // account records. Reuse the same path that will log the final meal.
            let preview = try NutritionStore(persistence: InMemoryTrainingPersistence())
            try preview.log(proposed.map(\.item), on: previewDate, meal: "Meal preview")
            rows = proposed
            summary = preview.summary(on: previewDate)
            progress = preview.progress(on: previewDate)
            error = nil
            return true
        } catch { self.error = NutritionDraftError.messages(error).joined(separator: " "); return false }
    }
}
