import Foundation

/// What a MacroFactor import adds: before saving, as a preview, and after.
public struct MacroFactorImportSummary: Sendable, Hashable {
    /// The kinds of document, in the order they're saved.
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        case foods, entries, dayTotals, days, weights, plans, workouts
    }

    public struct Count: Sendable, Hashable {
        /// Documents the import adds, or days whose status or notes it sets.
        public var new = 0
        /// Already in Exerly, from an earlier import or as the same reading,
        /// and left as they are.
        public var existing = 0
    }

    public var counts: [Kind: Count] = [:]
    public var dateRange: ClosedRange<LocalDate>?
    /// Day totals from an earlier import that this file's food log replaces.
    public var replacedDayTotals = 0
    public var report: MacroFactorReport
    /// Kinds that failed to save, with why. Nothing of a failed kind was saved.
    public var failures: [Kind: String] = [:]

    public subscript(_ kind: Kind) -> Count { counts[kind] ?? Count() }
    /// Everything the import adds or sets.
    public var additions: Int { counts.values.reduce(0) { $0 + $1.new } + replacedDayTotals }
}

/// A `MacroFactorExport` checked against what Exerly already has, ready to
/// save through the stores so it syncs like anything logged in Exerly.
///
/// Documents already in Exerly are left as they are, so importing a file
/// twice changes nothing, and an imported entry edited or deleted since stays
/// that way until the file is imported again. Also kept: a day's status or
/// notes once set, a weigh-in within 0.1 kg of one on the same day (from
/// Apple Health, say), food on days Exerly already has food for, and Exerly's
/// own targets: plan versions start only before Exerly's first one.
@MainActor
public struct MacroFactorImport {
    public typealias Kind = MacroFactorImportSummary.Kind

    public let export: MacroFactorExport
    public private(set) var summary: MacroFactorImportSummary
    private var foods: [Food] = []
    private var entries: [FoodEntry] = []
    private var removedTotals: [UUID] = []
    private var totals: [FoodEntry] = []
    private var days: [NutritionDay] = []
    private var weights: [WeightEntry] = []
    private var plans: [NutritionPlan] = []
    private var sessions: [WorkoutSession] = []

    public init(_ export: MacroFactorExport, nutrition: NutritionStore, training: TrainingStore) {
        self.export = export
        summary = MacroFactorImportSummary(dateRange: export.dateRange, report: export.report)
        func count(_ kind: Kind, new: Bool) {
            if new { summary.counts[kind, default: .init()].new += 1 } else { summary.counts[kind, default: .init()].existing += 1 }
        }

        let foodIDs = Set(nutrition.foods.map(\.id))
        for food in export.foods {
            let new = !foodIDs.contains(food.id)
            if new { foods.append(food) }
            count(.foods, new: new)
        }

        let entryIDs = Set(nutrition.entries.map(\.id))
        for entry in export.entries {
            let new = !entryIDs.contains(entry.id)
            if new { entries.append(entry) }
            count(.entries, new: new)
        }
        removedTotals = Set(export.entries.map(\.date)).sorted().map(MacroFactorExport.dayTotalID).filter(entryIDs.contains)
        summary.replacedDayTotals = removedTotals.count

        var covered = 0
        let logged = Dictionary(grouping: nutrition.entries, by: \.date)
        for total in export.dayTotals {
            let others = (logged[total.date] ?? []).contains { $0.id != total.id }
            let new = !entryIDs.contains(total.id) && !others
            if new { totals.append(total) }
            if others && !entryIDs.contains(total.id) { covered += 1 }
            count(.dayTotals, new: new)
        }
        if covered > 0 {
            summary.report.assumptions.append("\(covered) \(covered == 1 ? "day" : "days") already had food in Exerly, so MacroFactor's totals for them were left out.")
        }

        for record in export.days {
            let current = nutrition.day(record.date)
            var day = current
            if let status = record.status, current.status == .unlogged { day.status = status }
            if let notes = record.notes, current.notes.isEmpty { day.notes = notes }
            let new = day != current
            if new { days.append(day) }
            count(.days, new: new)
        }

        let weightIDs = Set(nutrition.weights.map(\.id))
        let weighed = Dictionary(grouping: nutrition.weights, by: \.date)
        for weight in export.weights {
            let new = !weightIDs.contains(weight.id)
                && !(weighed[weight.date] ?? []).contains { abs($0.weight.kilograms - weight.weight.kilograms) < 0.1 }
            if new { weights.append(weight) }
            count(.weights, new: new)
        }

        let planIDs = Set(export.plans.map(\.id))
        let ownStart = nutrition.plans.filter { !planIDs.contains($0.id) }.map(\.startDate).min()
        for plan in export.plans {
            if nutrition.plans.contains(where: { $0.id == plan.id }) {
                count(.plans, new: false)
            } else if let ownStart, plan.startDate >= ownStart {
                summary.report.skipped.append(.init(sheet: "Nutrition program", row: nil,
                    reason: "The program from \(plan.startDate) starts after your Exerly targets do (\(ownStart)), so Exerly's are kept"))
            } else {
                plans.append(plan)
                count(.plans, new: true)
            }
        }

        for session in export.sessions {
            let new = training.history.session(session.id) == nil && training.activeSession?.id != session.id
            if new { sessions.append(session) }
            count(.workouts, new: new)
        }
    }

    /// The kinds with something to save, in saving order.
    public var steps: [Kind] {
        Kind.allCases.filter { kind in
            switch kind {
            case .foods: !foods.isEmpty
            case .entries: !entries.isEmpty || !removedTotals.isEmpty
            case .dayTotals: !totals.isEmpty
            case .days: !days.isEmpty
            case .weights: !weights.isEmpty
            case .plans: !plans.isEmpty
            case .workouts: !sessions.isEmpty
            }
        }
    }

    /// Saves one kind as one unit: every document is checked, then all are
    /// saved or none are.
    public func save(_ kind: Kind, nutrition: NutritionStore, training: TrainingStore) throws {
        switch kind {
        case .foods: try write(nutrition, NutritionStore.foodKind, foods.map { ($0.id, try ExerlyJSON.canonical($0)) })
        case .entries:
            try write(nutrition, NutritionStore.entryKind, try entries.map { ($0.id.uuidString, try ExerlyJSON.canonical($0)) }
                + removedTotals.map { ($0.uuidString, nil) })
        case .dayTotals: try write(nutrition, NutritionStore.entryKind, try totals.map { ($0.id.uuidString, try ExerlyJSON.canonical($0)) })
        case .days: try write(nutrition, NutritionStore.dayKind, try days.map { ($0.id, try ExerlyJSON.canonical($0)) })
        case .weights: try write(nutrition, NutritionStore.weightKind, try weights.map { ($0.id.uuidString, try ExerlyJSON.canonical($0)) })
        case .plans: try write(nutrition, NutritionStore.planKind, try plans.map { ($0.id.uuidString, try ExerlyJSON.canonical($0)) })
        case .workouts: try training.importSessions(sessions)
        }
    }

    /// Saves every kind. A kind that fails is reported in `failures`, and the
    /// others still save.
    @discardableResult
    public func save(nutrition: NutritionStore, training: TrainingStore) -> MacroFactorImportSummary {
        var result = summary
        for kind in steps {
            do { try save(kind, nutrition: nutrition, training: training) } catch { result.failures[kind] = Self.describe(error) }
        }
        return result
    }

    public static func describe(_ error: Error) -> String {
        switch error {
        case let error as DocumentError: error.message
        case NutritionStore.StoreError.invalid(let problems): problems.joined(separator: "; ")
        case TrainingStore.StoreError.edit(let problem): "A workout isn't valid: \(problem)"
        default: "\(error)"
        }
    }

    private func write(_ nutrition: NutritionStore, _ kind: String, _ documents: [(id: String, payload: Data?)]) throws {
        for document in documents {
            if let payload = document.payload { try nutrition.validate(kind: kind, id: document.id, payload: payload) }
        }
        try nutrition.writeAll(kind: kind, documents)
    }
}
