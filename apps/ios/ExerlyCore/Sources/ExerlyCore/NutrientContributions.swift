import Foundation

/// One food's part of a nutrient over a span of days.
public struct FoodContribution: Sendable, Hashable, Identifiable {
    /// The food's ID; quick adds, which have none, go by name.
    public var id: String
    /// The name it was last logged under.
    public var name: String
    public var brand: String?
    /// The total over the span, in the nutrient's unit.
    public var amount: Double
    /// Of the nutrient's total over the span.
    public var share: Double
    /// `amount` over the counted days.
    public var perDay: Double
    public var entries: Int
    /// Days it was logged on.
    public var days: Int
}

/// Which foods supplied a nutrient over the counted days of a span.
public struct NutrientContributions: Sendable, Hashable {
    /// `NutritionStore.quickAddPrefix`, readable off the main actor.
    static let quickAddPrefix = "quick:"

    public var nutrient: Nutrient
    /// What every reporting entry added up to.
    public var total: Double
    /// Foods that supplied some, largest first.
    public var foods: [FoodContribution]
    /// The counted days' entries.
    public var entries: Int
    /// Of those, the entries whose food doesn't report the nutrient, so the
    /// total may be low.
    public var unreported: Int
    public var countedDays: Int

    /// Adds each food's share up over `entries`, the counted days' entries,
    /// as `NutritionStore.contributors(of:on:)` does for a day.
    public static func aggregate(_ entries: [FoodEntry], of nutrient: Nutrient, countedDays: Int) -> NutrientContributions {
        struct Running {
            var name: String
            var brand: String?
            var amount = 0.0
            var entries = 0
            var days = Set<LocalDate>()
        }
        var foods: [String: Running] = [:]
        var unreported = 0
        let quickAddPrefix = Self.quickAddPrefix
        for entry in entries {
            guard let amount = entry.nutrients[nutrient] else {
                unreported += 1
                continue
            }
            guard amount > 0 else { continue }
            let key = entry.food.foodID.hasPrefix(quickAddPrefix) ? quickAddPrefix + entry.food.name : entry.food.foodID
            var running = foods[key] ?? Running(name: entry.food.name, brand: entry.food.brand)
            running.name = entry.food.name
            running.brand = entry.food.brand
            running.amount += amount
            running.entries += 1
            running.days.insert(entry.date)
            foods[key] = running
        }
        let total = foods.values.reduce(0) { $0 + $1.amount }
        let ranked = foods.map { key, food in
            FoodContribution(id: key, name: food.name, brand: food.brand, amount: food.amount,
                             share: total > 0 ? food.amount / total : 0,
                             perDay: countedDays > 0 ? food.amount / Double(countedDays) : 0,
                             entries: food.entries, days: food.days.count)
        }.sorted { ($0.amount, $1.name, $1.id) > ($1.amount, $0.name, $0.id) }
        return NutrientContributions(nutrient: nutrient, total: total, foods: ranked, entries: entries.count,
                                     unreported: unreported, countedDays: countedDays)
    }
}

extension NutritionStore {
    /// The foods behind a nutrient over the days from `start` through `end`
    /// that count, the same days `overview` averages.
    public func contributions(of nutrient: Nutrient, from start: LocalDate, through end: LocalDate) -> NutrientContributions {
        let series = intakeSeries(from: start, through: end)
        let counted = Set(series.days.filter(\.counted).map(\.date))
        return NutrientContributions.aggregate(entries.filter { counted.contains($0.date) }, of: nutrient,
                                               countedDays: counted.count)
    }
}

extension IntakeTiming {
    /// A stretch of the day, from `start` up to `end` o'clock; it may run past midnight.
    public struct Window: Sendable, Hashable {
        public var start: Int
        public var end: Int
        public var energy: Double
        /// Of the timed energy; 0 when nothing is timed.
        public var share: Double
    }

    public var timedEnergy: Double { hours.reduce(0) { $0 + $1.energy } }
    public var timedEntries: Int { hours.reduce(0) { $0 + $1.entries } }

    /// Each hour's share of the timed energy, midnight first.
    public var shares: [Double] {
        let total = timedEnergy
        return hours.map { total > 0 ? $0.energy / total : 0 }
    }

    /// The day cut at `bounds` (hours, ascending); the last window wraps
    /// round to the first bound. The default is morning, midday, evening and night.
    public func windows(_ bounds: [Int] = [5, 11, 16, 21]) -> [Window] {
        guard !bounds.isEmpty else { return [] }
        let total = timedEnergy
        return bounds.indices.map { index in
            let start = bounds[index], end = bounds[(index + 1) % bounds.count]
            let span = end > start ? Array(start..<end) : Array(start..<24) + Array(0..<end)
            let energy = span.reduce(0) { $0 + hours[$1].energy }
            return Window(start: start, end: end, energy: energy, share: total > 0 ? energy / total : 0)
        }
    }

    /// The hour with the most energy; nil when nothing is timed.
    public var peakHour: Int? {
        guard timedEnergy > 0 else { return nil }
        return hours.max { ($0.energy, -$0.hour) < ($1.energy, -$1.hour) }?.hour
    }
}
