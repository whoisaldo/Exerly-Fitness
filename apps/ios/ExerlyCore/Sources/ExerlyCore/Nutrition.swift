import Foundation

public enum FoodSource: String, Sendable, Codable, Hashable, CaseIterable {
    case custom, recipe, usda, openFoodFacts, fatSecret, imported
}

/// A named portion, such as "1 cup" weighing 240 g.
public struct Serving: Sendable, Codable, Hashable {
    public var name: String
    public var grams: Double

    public init(_ name: String, grams: Double) {
        self.name = name
        self.grams = grams
    }
}

/// What a log entry keeps of a food, so editing the food later doesn't
/// rewrite history.
public struct FoodSnapshot: Sendable, Codable, Hashable {
    public var foodID: String
    public var name: String
    public var brand: String?
    public var source: FoodSource
    public var per100g: NutrientAmounts
}

public struct RecipeIngredient: Sendable, Codable, Hashable {
    public var food: FoodSnapshot
    public var grams: Double

    public init(food: FoodSnapshot, grams: Double) {
        self.food = food
        self.grams = grams
    }
}

/// A custom food, a recipe, or a database food the person keeps.
public struct Food: Sendable, Codable, Hashable, Identifiable {
    /// A UUID for custom foods and recipes; "usda:<fdcId>" or "off:<barcode>" for database foods.
    public var id: String
    public var name: String
    public var brand: String?
    public var source: FoodSource
    public var per100g: NutrientAmounts
    public var servings: [Serving]
    public var barcode: String?
    /// For recipes.
    public var ingredients: [RecipeIngredient]?
    /// A recipe's cooked weight, when it differs from its ingredients'.
    public var yieldGrams: Double?
    public var favorite: Bool
    public var createdAt: Date
    public var archivedAt: Date?

    public init(id: String = UUID().uuidString, name: String, brand: String? = nil, source: FoodSource = .custom,
                per100g: NutrientAmounts, servings: [Serving] = [], barcode: String? = nil, favorite: Bool = false,
                createdAt: Date = Date().roundedToMilliseconds) {
        self.id = id
        self.name = name
        self.brand = brand
        self.source = source
        self.per100g = per100g
        self.servings = servings
        self.barcode = barcode
        self.favorite = favorite
        self.createdAt = createdAt
    }

    /// A recipe from ingredients. Its nutrients per 100 g come from their total
    /// over the cooked weight, or over the ingredients' weight without one.
    public static func recipe(id: String = UUID().uuidString, name: String, ingredients: [RecipeIngredient],
                              yieldGrams: Double? = nil, servings: [Serving] = [],
                              createdAt: Date = Date().roundedToMilliseconds) -> Food {
        var food = Food(id: id, name: name, source: .recipe, per100g: Self.per100g(ingredients, yield: yieldGrams),
                        servings: servings, createdAt: createdAt)
        food.ingredients = ingredients
        food.yieldGrams = yieldGrams
        return food
    }

    static func per100g(_ ingredients: [RecipeIngredient], yield: Double?) -> NutrientAmounts {
        let total = ingredients.reduce(NutrientAmounts()) { $0 + $1.food.per100g.scaled(by: $1.grams / 100) }
        let weight = yield ?? ingredients.reduce(0) { $0 + $1.grams }
        return weight > 0 ? total.scaled(by: 100 / weight) : NutrientAmounts()
    }

    public var snapshot: FoodSnapshot {
        FoodSnapshot(foodID: id, name: name, brand: brand, source: source, per100g: per100g)
    }

    var problems: [String] {
        var problems = per100g.problems
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { problems.append("name is empty") }
        if servings.contains(where: { !($0.grams.isFinite && $0.grams > 0) || $0.name.isEmpty }) {
            problems.append("each serving needs a name and a positive weight")
        }
        if let yieldGrams, !(yieldGrams.isFinite && yieldGrams > 0) { problems.append("the yield must be positive") }
        if source == .recipe && (ingredients ?? []).isEmpty { problems.append("a recipe needs ingredients") }
        if (ingredients ?? []).contains(where: { !($0.grams.isFinite && $0.grams > 0) }) {
            problems.append("each ingredient needs a positive weight")
        }
        return problems
    }
}

/// One logged food.
public struct FoodEntry: Sendable, Codable, Hashable, Identifiable {
    public var id: UUID
    /// The day it counts toward, in the person's calendar.
    public var date: LocalDate
    public var meal: String
    public var loggedAt: Date
    public var food: FoodSnapshot
    public var grams: Double
    /// The serving it was entered in, and how many.
    public var serving: Serving?
    public var quantity: Double?

    public init(id: UUID = UUID(), date: LocalDate, meal: String, loggedAt: Date, food: FoodSnapshot, grams: Double,
                serving: Serving? = nil, quantity: Double? = nil) {
        self.id = id
        self.date = date
        self.meal = meal
        self.loggedAt = loggedAt
        self.food = food
        self.grams = grams
        self.serving = serving
        self.quantity = quantity
    }

    public var nutrients: NutrientAmounts { food.per100g.scaled(by: grams / 100) }

    var problems: [String] {
        var problems = food.per100g.problems
        if !(grams.isFinite && grams > 0 && grams <= 100_000) { problems.append("the amount must be a positive weight") }
        if meal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || meal.count > 40 {
            problems.append("the meal needs a name up to 40 characters")
        }
        if let quantity, !(quantity.isFinite && quantity > 0) { problems.append("the quantity must be positive") }
        return problems
    }
}

/// How complete a day's food log is. Expenditure trusts complete and fasting days.
public enum DayStatus: String, Sendable, Codable, Hashable, CaseIterable {
    case unlogged, partial, complete, fasting
}

public struct NutritionDay: Sendable, Codable, Hashable, Identifiable {
    /// The date, `YYYY-MM-DD`, so every device names the same day the same way.
    public var id: String { date.description }
    public var date: LocalDate
    public var status: DayStatus
    public var notes: String

    public init(date: LocalDate, status: DayStatus = .unlogged, notes: String = "") {
        self.date = date
        self.status = status
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey { case id, date, status, notes }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(LocalDate.self, forKey: .date)
        status = try c.decode(DayStatus.self, forKey: .status)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(status, forKey: .status)
        try c.encode(notes, forKey: .notes)
    }
}

public struct WeightEntry: Sendable, Codable, Hashable, Identifiable {
    public var id: UUID
    public var at: Date
    public var date: LocalDate
    public var weight: Mass
    /// Body fat, in percent, when the scale reports it.
    public var bodyFat: Double?

    public init(id: UUID = UUID(), at: Date, date: LocalDate, weight: Mass, bodyFat: Double? = nil) {
        self.id = id
        self.at = at
        self.date = date
        self.weight = weight
        self.bodyFat = bodyFat
    }

    var problems: [String] {
        var problems: [String] = []
        if !(weight.value.isFinite && weight.kilograms >= 20 && weight.kilograms <= 400) {
            problems.append("weight must be 20 to 400 kg")
        }
        if let bodyFat, !(bodyFat.isFinite && bodyFat > 1 && bodyFat < 75) { problems.append("body fat must be 1 to 75 %") }
        return problems
    }
}

/// A day's food in numbers, so screens never add entries up themselves.
public struct NutritionSummary: Sendable, Hashable {
    public var date: LocalDate
    public var status: DayStatus
    public var totals: NutrientAmounts
    public var byMeal: [String: NutrientAmounts]
    public var entries: Int

    /// The share of energy each macro provides, from Atwater factors.
    public var energyShares: [Nutrient: Double] {
        let parts = [Nutrient.protein, .carbohydrate, .fat, .alcohol].compactMap { nutrient -> (Nutrient, Double)? in
            guard let grams = totals[nutrient], let factor = nutrient.kilocaloriesPerGram else { return nil }
            return (nutrient, grams * factor)
        }
        let total = parts.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return [:] }
        return Dictionary(uniqueKeysWithValues: parts.map { ($0.0, $0.1 / total) })
    }
}

/// One food's share of a nutrient on a day.
public struct Contributor: Sendable, Hashable {
    public var entryID: UUID
    public var name: String
    public var amount: Double
    public var share: Double
}
