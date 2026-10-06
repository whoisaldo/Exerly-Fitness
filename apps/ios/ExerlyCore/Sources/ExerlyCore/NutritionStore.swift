import Foundation
import Observation

/// Foods, the food log, day statuses and weigh-ins. Every change is validated,
/// saved, then published, and everything syncs as documents. See
/// docs/design/007-nutrition.md.
@MainActor
@Observable
public final class NutritionStore {
    public enum StoreError: Error, Equatable {
        case invalid([String])
        case notFound
    }

    public static let defaultMeals = ["Breakfast", "Lunch", "Dinner", "Snacks"]

    public private(set) var foods: [Food] = []
    /// Oldest first.
    public private(set) var entries: [FoodEntry] = []
    public private(set) var days: [LocalDate: NutritionDay] = [:]
    /// Oldest first.
    public private(set) var weights: [WeightEntry] = []
    /// Plan versions, the earliest in force first.
    public private(set) var plans: [NutritionPlan] = []

    static let foodKind = "saved_food"
    static let entryKind = "food_entry"
    static let dayKind = "nutrition_day"
    static let weightKind = "weight_entry"
    nonisolated static let planKind = "nutrition_plan"

    @ObservationIgnored private let persistence: TrainingPersistence & DocumentPersistence
    @ObservationIgnored private let now: () -> Date

    public init(persistence: TrainingPersistence & DocumentPersistence, now: @escaping () -> Date = Date.init) throws {
        self.persistence = persistence
        self.now = { now().roundedToMilliseconds }
        let decoder = ExerlyJSON.decoder
        foods = try persistence.loadDocuments(kind: Self.foodKind).map { try decoder.decode(Food.self, from: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        entries = try persistence.loadDocuments(kind: Self.entryKind).map { try decoder.decode(FoodEntry.self, from: $0) }
            .sorted(by: Self.entryOrder)
        days = Dictionary(try persistence.loadDocuments(kind: Self.dayKind)
            .map { try decoder.decode(NutritionDay.self, from: $0) }.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
        weights = try persistence.loadDocuments(kind: Self.weightKind).map { try decoder.decode(WeightEntry.self, from: $0) }
            .sorted { $0.at < $1.at }
        plans = try persistence.loadDocuments(kind: Self.planKind).map { try decoder.decode(NutritionPlan.self, from: $0) }
            .sorted(by: Self.planOrder)
    }

    static func planOrder(_ a: NutritionPlan, _ b: NutritionPlan) -> Bool {
        (a.startDate, a.createdAt, a.id.uuidString) < (b.startDate, b.createdAt, b.id.uuidString)
    }

    static func entryOrder(_ a: FoodEntry, _ b: FoodEntry) -> Bool {
        (a.date, a.loggedAt, a.id.uuidString) < (b.date, b.loggedAt, b.id.uuidString)
    }

    // MARK: Foods

    public func food(_ id: String) -> Food? { foods.first { $0.id == id } }

    public func saveFood(_ food: Food) throws {
        let problems = food.problems
        guard problems.isEmpty else { throw StoreError.invalid(problems) }
        try commit(Self.foodKind, food.id, food)
    }

    public func setFavorite(_ id: String, _ favorite: Bool) throws {
        guard var food = food(id) else { throw StoreError.notFound }
        food.favorite = favorite
        try commit(Self.foodKind, id, food)
    }

    /// Hides a food from search; entries that used it keep their snapshot.
    public func archiveFood(_ id: String) throws {
        guard var food = food(id) else { throw StoreError.notFound }
        food.archivedAt = now()
        try commit(Self.foodKind, id, food)
    }

    // MARK: Log

    public func entries(on date: LocalDate) -> [FoodEntry] { entries.filter { $0.date == date } }

    /// Logs a food by weight, or by a number of servings.
    @discardableResult
    /// `at` is when it was eaten, for timing; now when nil.
    public func log(_ food: Food, grams: Double? = nil, serving: Serving? = nil, quantity: Double? = nil,
                    on date: LocalDate, meal: String, at time: Date? = nil) throws -> FoodEntry {
        let weight = grams ?? (serving.map { $0.grams * (quantity ?? 1) })
        guard let weight else { throw StoreError.invalid(["give a weight or a serving"]) }
        let entry = FoodEntry(date: date, meal: meal, loggedAt: time?.roundedToMilliseconds ?? now(), food: food.snapshot,
                              grams: weight,
                              serving: serving, quantity: serving == nil ? nil : (quantity ?? 1))
        try saveEntry(entry)
        return entry
    }

    public func saveEntry(_ entry: FoodEntry) throws {
        let problems = entry.problems
        guard problems.isEmpty else { throw StoreError.invalid(problems) }
        try commit(Self.entryKind, entry.id.uuidString, entry)
    }

    public func deleteEntry(_ id: UUID) throws {
        guard entries.contains(where: { $0.id == id }) else { throw StoreError.notFound }
        let publish = try prepareWrite(kind: Self.entryKind, id: id.uuidString, payload: nil)
        publish()
    }

    /// Copies a day's entries (or one meal's) to another day, as new entries.
    @discardableResult
    public func copy(from source: LocalDate, meal: String? = nil, to target: LocalDate, meal newMeal: String? = nil) throws
        -> [FoodEntry] {
        let copies = entries(on: source).filter { meal == nil || $0.meal == meal }.map { original in
            FoodEntry(date: target, meal: newMeal ?? original.meal, loggedAt: now(), food: original.food,
                      grams: original.grams, serving: original.serving, quantity: original.quantity)
        }
        var publish: [() -> Void] = []
        try persistence.performAtomically {
            publish = try copies.map { try prepareWrite(kind: Self.entryKind, id: $0.id.uuidString, payload: ExerlyJSON.canonical($0)) }
        }
        publish.forEach { $0() }
        return copies
    }

    /// Foods logged most recently first, one row each, for "recent" and quick re-logging.
    public func recentFoods(limit: Int = 20) -> [FoodSnapshot] {
        var seen = Set<String>()
        var result: [FoodSnapshot] = []
        for entry in entries.reversed() where seen.insert(entry.food.foodID).inserted {
            result.append(entry.food)
            if result.count == limit { break }
        }
        return result
    }

    // MARK: Days

    public func day(_ date: LocalDate) -> NutritionDay { days[date] ?? NutritionDay(date: date) }

    public func setStatus(_ status: DayStatus, on date: LocalDate) throws {
        var day = day(date)
        day.status = status
        try commit(Self.dayKind, day.id, day)
    }

    public func setNotes(_ notes: String, on date: LocalDate) throws {
        var day = day(date)
        day.notes = notes
        try commit(Self.dayKind, day.id, day)
    }

    public func summary(on date: LocalDate) -> NutritionSummary {
        let logged = entries(on: date)
        var byMeal: [String: NutrientAmounts] = [:]
        for entry in logged { byMeal[entry.meal, default: NutrientAmounts()] += entry.nutrients }
        return NutritionSummary(date: date, status: day(date).status,
                                totals: logged.reduce(NutrientAmounts()) { $0 + $1.nutrients },
                                byMeal: byMeal, entries: logged.count)
    }

    /// Each entry's share of a nutrient on a day, largest first.
    public func contributors(of nutrient: Nutrient, on date: LocalDate) -> [Contributor] {
        let amounts = entries(on: date).compactMap { entry -> (FoodEntry, Double)? in
            entry.nutrients[nutrient].map { (entry, $0) }
        }
        let total = amounts.reduce(0) { $0 + $1.1 }
        return amounts.filter { $0.1 > 0 }
            .map { Contributor(entryID: $0.0.id, name: $0.0.food.name, amount: $0.1, share: total > 0 ? $0.1 / total : 0) }
            .sorted { $0.amount > $1.amount }
    }

    // MARK: Weight

    @discardableResult
    public func logWeight(_ weight: Mass, bodyFat: Double? = nil, at instant: Date? = nil, timeZone: TimeZone) throws -> WeightEntry {
        let at = (instant ?? now()).roundedToMilliseconds
        let entry = WeightEntry(at: at, date: LocalDate(at, in: timeZone), weight: weight, bodyFat: bodyFat)
        let problems = entry.problems
        guard problems.isEmpty else { throw StoreError.invalid(problems) }
        try commit(Self.weightKind, entry.id.uuidString, entry)
        return entry
    }

    public func deleteWeight(_ id: UUID) throws {
        guard weights.contains(where: { $0.id == id }) else { throw StoreError.notFound }
        let publish = try prepareWrite(kind: Self.weightKind, id: id.uuidString, payload: nil)
        publish()
    }

    // MARK: Plans

    /// The version in force on a date: the latest to start on or before it.
    public func plan(on date: LocalDate) -> NutritionPlan? { plans.last { $0.startDate <= date } }

    public func targets(on date: LocalDate) -> DailyTargets? { plan(on: date)?.targets(on: date) }

    /// Saves a version that starts today or later. Versions already in force
    /// can't change, so past days keep their targets; start a new one instead.
    public func savePlan(_ plan: NutritionPlan, timeZone: TimeZone) throws {
        let today = LocalDate(now(), in: timeZone)
        var problems = plan.validationErrors
        if plan.startDate < today { problems.append("A plan can't start in the past") }
        if let saved = plans.first(where: { $0.id == plan.id }), saved.startDate <= today {
            problems.append("This version is already in force; start a new one")
        }
        guard problems.isEmpty else { throw StoreError.invalid(problems) }
        try commit(Self.planKind, plan.id.uuidString, plan)
    }

    // MARK: Private

    private func commit<T: Encodable>(_ kind: String, _ id: String, _ value: T) throws {
        let publish = try prepareWrite(kind: kind, id: id, payload: ExerlyJSON.canonical(value))
        publish()
    }
}

extension NutritionStore: DocumentHost {
    public var documentKinds: [String] { [Self.foodKind, Self.entryKind, Self.dayKind, Self.weightKind, Self.planKind] }

    public func documentIDs(kind: String) -> [String] {
        switch kind {
        case Self.foodKind: foods.map(\.id)
        case Self.entryKind: entries.map(\.id.uuidString)
        case Self.dayKind: days.values.map(\.id)
        case Self.weightKind: weights.map(\.id.uuidString)
        case Self.planKind: plans.map(\.id.uuidString)
        default: []
        }
    }

    public func payload(kind: String, id: String) throws -> Data? {
        switch kind {
        case Self.foodKind: return try food(id).map(ExerlyJSON.canonical)
        case Self.entryKind: return try entries.first { $0.id.uuidString == id }.map(ExerlyJSON.canonical)
        case Self.dayKind: return try LocalDate(id).flatMap { days[$0] }.map(ExerlyJSON.canonical)
        case Self.weightKind: return try weights.first { $0.id.uuidString == id }.map(ExerlyJSON.canonical)
        case Self.planKind: return try plans.first { $0.id.uuidString == id }.map(ExerlyJSON.canonical)
        default: return nil
        }
    }

    public func canonicalize(kind: String, payload: Data) throws -> Data {
        let decoder = ExerlyJSON.decoder
        switch kind {
        case Self.foodKind: return try ExerlyJSON.canonical(decoder.decode(Food.self, from: payload))
        case Self.entryKind: return try ExerlyJSON.canonical(decoder.decode(FoodEntry.self, from: payload))
        case Self.dayKind: return try ExerlyJSON.canonical(decoder.decode(NutritionDay.self, from: payload))
        case Self.weightKind: return try ExerlyJSON.canonical(decoder.decode(WeightEntry.self, from: payload))
        case Self.planKind: return try ExerlyJSON.canonical(decoder.decode(NutritionPlan.self, from: payload))
        default: throw DocumentError(message: "Unknown kind \(kind)")
        }
    }

    public func validate(kind: String, id: String, payload: Data) throws {
        let decoder = ExerlyJSON.decoder
        let problems: [String]
        switch kind {
        case Self.foodKind:
            let food = try decoder.decode(Food.self, from: payload)
            problems = (food.id == id ? [] : ["the ID doesn't match"]) + food.problems
        case Self.entryKind:
            let entry = try decoder.decode(FoodEntry.self, from: payload)
            problems = (entry.id.uuidString == id ? [] : ["the ID doesn't match"]) + entry.problems
        case Self.dayKind:
            let day = try decoder.decode(NutritionDay.self, from: payload)
            problems = day.id == id ? [] : ["the ID doesn't match"]
        case Self.weightKind:
            let weight = try decoder.decode(WeightEntry.self, from: payload)
            problems = (weight.id.uuidString == id ? [] : ["the ID doesn't match"]) + weight.problems
        case Self.planKind:
            let plan = try decoder.decode(NutritionPlan.self, from: payload)
            problems = (plan.id.uuidString == id ? [] : ["the ID doesn't match"]) + plan.validationErrors
        default:
            throw DocumentError(message: "Unknown kind \(kind)")
        }
        guard problems.isEmpty else { throw DocumentError(message: problems.joined(separator: "; ")) }
    }

    /// Foods, entries, weigh-ins and plans merge as whole values. A day merges field by field.
    public func merge(kind: String, base: Data?, local: Data, remote: Data) throws -> Data {
        let decoder = ExerlyJSON.decoder
        func whole<T: Codable & Equatable>(_ type: T.Type) throws -> Data {
            try ExerlyJSON.canonical(Merge.value(try base.map { try decoder.decode(type, from: $0) },
                                                 try decoder.decode(type, from: local), try decoder.decode(type, from: remote)))
        }
        switch kind {
        case Self.foodKind: return try whole(Food.self)
        case Self.entryKind: return try whole(FoodEntry.self)
        case Self.weightKind: return try whole(WeightEntry.self)
        case Self.planKind: return try whole(NutritionPlan.self)
        case Self.dayKind:
            let original = try base.map { try decoder.decode(NutritionDay.self, from: $0) }
            var merged = try decoder.decode(NutritionDay.self, from: local)
            let other = try decoder.decode(NutritionDay.self, from: remote)
            merged.status = Merge.value(original?.status, merged.status, other.status)
            merged.notes = Merge.value(original?.notes, merged.notes, other.notes)
            return try ExerlyJSON.canonical(merged)
        default:
            throw DocumentError(message: "Unknown kind \(kind)")
        }
    }

    public func prepareWrite(kind: String, id: String, payload: Data?) throws -> () -> Void {
        let decoder = ExerlyJSON.decoder
        guard let payload else {
            try persistence.deleteDocument(kind: kind, id: id)
            return { [self] in
                switch kind {
                case Self.foodKind: foods.removeAll { $0.id == id }
                case Self.entryKind: entries.removeAll { $0.id.uuidString == id }
                case Self.dayKind: if let date = LocalDate(id) { days[date] = nil }
                case Self.weightKind: weights.removeAll { $0.id.uuidString == id }
                case Self.planKind: plans.removeAll { $0.id.uuidString == id }
                default: break
                }
            }
        }
        let canonical = try canonicalize(kind: kind, payload: payload)
        try persistence.saveDocument(kind: kind, id: id, payload: canonical)
        switch kind {
        case Self.foodKind:
            let food = try decoder.decode(Food.self, from: canonical)
            return { [self] in
                foods = (foods.filter { $0.id != id } + [food])
                    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
        case Self.entryKind:
            let entry = try decoder.decode(FoodEntry.self, from: canonical)
            return { [self] in entries = (entries.filter { $0.id != entry.id } + [entry]).sorted(by: Self.entryOrder) }
        case Self.dayKind:
            let day = try decoder.decode(NutritionDay.self, from: canonical)
            return { [self] in days[day.date] = day }
        case Self.weightKind:
            let weight = try decoder.decode(WeightEntry.self, from: canonical)
            return { [self] in weights = (weights.filter { $0.id != weight.id } + [weight]).sorted { $0.at < $1.at } }
        default:
            let plan = try decoder.decode(NutritionPlan.self, from: canonical)
            return { [self] in plans = (plans.filter { $0.id != plan.id } + [plan]).sorted(by: Self.planOrder) }
        }
    }
}
