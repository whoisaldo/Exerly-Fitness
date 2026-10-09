import Foundation

/// A portion of a food that one tap logs: the amount last logged for it, or a
/// sensible default for a food never logged. It is shown before it is logged,
/// so what a row says is exactly what the tap records.
public struct QuickPortion: Sendable, Hashable, Identifiable {
    public var id: String { food.foodID }
    public var food: FoodSnapshot
    public var grams: Double
    /// The serving it was entered in, and how many.
    public var serving: Serving?
    public var quantity: Double?
    /// True when the amount repeats one logged before.
    public var repeated: Bool

    public init(food: FoodSnapshot, grams: Double, serving: Serving? = nil, quantity: Double? = nil, repeated: Bool) {
        self.food = food
        self.grams = grams
        self.serving = serving
        self.quantity = quantity
        self.repeated = repeated
    }

    /// A time-of-day suggestion's food and amount.
    public init(_ suggestion: FoodSuggestion) {
        self.init(food: suggestion.food, grams: suggestion.grams, serving: suggestion.serving,
                  quantity: suggestion.quantity, repeated: true)
    }

    /// The portion's nutrients. Nutrients the food doesn't report stay missing.
    public var nutrients: NutrientAmounts { food.per100g.scaled(by: grams / 100) }
}

extension NutritionStore {
    /// The portion one tap logs for `food`. With history, the amount last
    /// logged for it; a saved food uses its current label, and a repeated
    /// corrected snapshot keeps its mark, as the portion editor does.
    /// Without history, one of its first named serving (a recipe's serving
    /// when it has none), else 100 g. Nil for a food whose label can't be
    /// logged, or one only ever logged as a whole portion.
    public func quickPortion(for food: Food) -> QuickPortion? {
        let label = self.food(food.id) ?? food
        if let last = lastWeighedEntry(food.id) {
            var snapshot = label.snapshot
            if last.food.edited == true, last.food.per100g == snapshot.per100g { snapshot.edited = true }
            return QuickPortion(food: snapshot, grams: last.grams, serving: last.serving, quantity: last.quantity,
                                repeated: true)
        }
        guard !entries.contains(where: { $0.food.foodID == food.id }) else { return nil }
        let serving = label.servings.first ?? label.recipeServing
        guard let amount = try? Self.preview(label, grams: serving == nil ? 100 : nil, serving: serving,
                                             quantity: serving == nil ? nil : 1) else { return nil }
        return QuickPortion(food: label.snapshot, grams: amount.grams, serving: amount.serving,
                            quantity: amount.quantity, repeated: false)
    }

    /// Foods to log again, most recently logged first, each with the portion
    /// one tap logs. Quick adds, whole portions and archived foods are left out.
    public func recentPortions(limit: Int = 20) -> [QuickPortion] {
        var result: [QuickPortion] = []
        for snapshot in recentFoods(limit: limit) where snapshot.unweighed != true {
            let saved = food(snapshot.foodID)
            guard saved?.archivedAt == nil, let last = lastWeighedEntry(snapshot.foodID) else { continue }
            var food = saved?.snapshot ?? last.food
            if saved != nil, last.food.edited == true, last.food.per100g == food.per100g { food.edited = true }
            result.append(QuickPortion(food: food, grams: last.grams, serving: last.serving,
                                       quantity: last.quantity, repeated: true))
        }
        return result
    }

    /// Logs a portion as a new entry.
    @discardableResult
    public func log(_ portion: QuickPortion, on date: LocalDate, meal: String, at time: Date? = nil) throws -> FoodEntry {
        try log(FoodSuggestion(food: portion.food, meal: meal, grams: portion.grams, serving: portion.serving,
                               quantity: portion.quantity, days: 0), on: date, meal: meal, at: time)
    }

    private func lastWeighedEntry(_ foodID: String) -> FoodEntry? {
        entries.last { $0.food.foodID == foodID && $0.food.unweighed != true }
    }
}

extension NutrientAmounts {
    /// The share of energy from protein, carbohydrate, fat and alcohol, by
    /// Atwater factors. Empty when none is reported or they add up to zero.
    public var macroEnergyShares: [Nutrient: Double] {
        let parts = [Nutrient.protein, .carbohydrate, .fat, .alcohol].compactMap { nutrient -> (Nutrient, Double)? in
            guard let grams = self[nutrient], let factor = nutrient.kilocaloriesPerGram else { return nil }
            return (nutrient, grams * factor)
        }
        let total = parts.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return [:] }
        return Dictionary(uniqueKeysWithValues: parts.map { ($0.0, $0.1 / total) })
    }
}
