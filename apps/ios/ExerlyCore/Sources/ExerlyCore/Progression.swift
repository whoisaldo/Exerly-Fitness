import Foundation

/// The load steps an exercise's equipment allows, in each unit, and the
/// lightest load it can be set to.
public struct LoadIncrements: Sendable, Codable, Hashable {
    public var kilograms: Double
    public var pounds: Double
    /// The lightest loadable weight, such as an empty barbell. Nil means zero.
    public var minimum: Mass?

    public init(kilograms: Double, pounds: Double, minimum: Mass? = nil) {
        self.kilograms = kilograms
        self.pounds = pounds
        self.minimum = minimum
    }

    public func step(in unit: MassUnit) -> Double { unit == .kilograms ? kilograms : pounds }

    /// Defaults by the exercise's resistance equipment; the person can override them.
    public static func defaults(for exercise: Exercise) -> LoadIncrements {
        let equipment = Set(exercise.equipment)
        if !equipment.isDisjoint(with: [.barbell, .trapBar]) { return LoadIncrements(kilograms: 2.5, pounds: 5, minimum: .kg(20)) }
        if equipment.contains(.ezBar) { return LoadIncrements(kilograms: 2.5, pounds: 5, minimum: .kg(10)) }
        if !equipment.isDisjoint(with: [.smithMachine, .landmine]) { return LoadIncrements(kilograms: 2.5, pounds: 5) }
        if !equipment.isDisjoint(with: [.dumbbell]) { return LoadIncrements(kilograms: 2, pounds: 5) }
        if equipment.contains(.kettlebell) { return LoadIncrements(kilograms: 4, pounds: 10) }
        if !equipment.isDisjoint(with: [.cable, .machine, .sled]) { return LoadIncrements(kilograms: 5, pounds: 10) }
        return LoadIncrements(kilograms: 1.25, pounds: 2.5)
    }
}

/// One set to do.
public struct PlannedSet: Sendable, Codable, Hashable {
    public var kind: SetKind
    /// Reps and load to aim for; the load is nil when none is recommended.
    public var effort: Effort
    public var rir: Double
}

/// What progression recommends for an exercise slot, and why.
public struct Recommendation: Sendable, Hashable {
    public enum Reason: String, Sendable, Hashable {
        /// No earlier sessions: choose a load that leaves the target RIR.
        case firstSession
        /// The last session beat the prediction, so the target goes up.
        case progress
        /// About as predicted, or a small shortfall: the same load again.
        case hold
        /// A clear shortfall: a little lighter, never more than 10 % at once.
        case reduce
        /// The exercise isn't load-based; repeat the last values.
        case repeatLast
    }

    public var sets: [PlannedSet]
    public var reason: Reason
    /// The e1RM it was planned from, in kilograms.
    public var oneRepMax: Double?
    /// The set the estimate came from.
    public var basisSetID: UUID?
    /// The reps had to go outside the slot's range to fit the equipment.
    public var outsideRange: Bool
}

/// RIR-based progression. See docs/design/006-programs-progression.md, which
/// records how it was checked against simulated lifters.
public enum Progression {
    /// How much one session can raise the estimate over the best of the four before it.
    static let maximumRise = 0.05
    /// The largest cut in one step.
    static let maximumCut = 0.10
    /// Falling short of the prediction by up to this many reps to failure holds the load.
    static let holdBand = 1.0
    static let recentSessions = 4

    public static func recommend(_ target: SlotTarget, exercise: Exercise, history: TrainingHistory, before date: Date? = nil,
                                 bodyweight: Mass?, increments: LoadIncrements? = nil,
                                 expandRepRange: Bool = false) -> Recommendation {
        let records = history.sets(of: exercise.id).filter { record in date.map { record.sessionStart < $0 } ?? true }
        return recommendation(target, exercise: exercise, records: records, bodyweight: bodyweight,
                              increments: increments ?? .defaults(for: exercise), expandRepRange: expandRepRange)
    }

    static func recommendation(_ target: SlotTarget, exercise: Exercise, records: [SetRecord], bodyweight: Mass?,
                               increments: LoadIncrements, expandRepRange: Bool) -> Recommendation {
        let targetReps = Int(target.targetReps.rounded(.down))
        func plan(_ effort: Effort, _ reason: Recommendation.Reason, e1rm: Double? = nil, basis: UUID? = nil,
                  outside: Bool = false) -> Recommendation {
            Recommendation(sets: Array(repeating: PlannedSet(kind: target.kind, effort: effort, rir: target.rir), count: target.sets),
                           reason: reason, oneRepMax: e1rm, basisSetID: basis, outsideRange: outside)
        }
        guard exercise.metric.tracksReps else {
            let last = records.last?.set.primary ?? Effort()
            return plan(last, records.isEmpty ? .firstSession : .repeatLast)
        }
        // Sessions, oldest first, with each one's best e1RM.
        var sessions: [(id: UUID, best: Double, set: SetRecord)] = []
        for record in records {
            var rated = record.set
            if rated.rir == nil && rated.kind != .failure { rated.rir = target.rir }
            guard let e1rm = ExerciseStatistics.oneRepMax(rated, exercise: exercise, bodyweight: record.bodyweight) else {
                continue
            }
            if let last = sessions.last, last.id == record.sessionID {
                if e1rm > last.best { sessions[sessions.count - 1] = (record.sessionID, e1rm, record) }
            } else {
                sessions.append((record.sessionID, e1rm, record))
            }
        }
        guard let latest = sessions.last else {
            return plan(Effort(reps: targetReps), .firstSession)
        }
        let unit = latest.set.set.primary.load?.unit ?? records.last(where: { $0.set.primary.load != nil })?.set.primary.load?.unit
            ?? .kilograms
        let earlier = sessions.dropLast().suffix(recentSessions)
        let previous = earlier.last?.best
        var estimate = latest.best
        if let ceiling = earlier.map(\.best).max() { estimate = min(estimate, ceiling * (1 + maximumRise)) }
        var reason = Recommendation.Reason.progress
        if let previous {
            // What the earlier estimate predicted at the latest load, against what was done.
            let latestLoad = Volume.effectiveLoad(latest.set.set.primary, exercise: exercise, bodyweight: latest.set.bodyweight) ?? 0
            let predicted = OneRepMax.repsToFailure(load: latestLoad, oneRepMax: previous)
            let achieved = Double(latest.set.set.primary.reps ?? 0) + (latest.set.set.effectiveRIR ?? target.rir)
            if estimate < previous && achieved < predicted - holdBand - 1e-9 {
                reason = .reduce
                estimate = max(estimate, previous * (1 - maximumCut))
            } else if estimate < previous {
                // A small shortfall: the same load as last time, at the target reps.
                let effort = Effort(reps: targetReps, load: latest.set.set.primary.load)
                return plan(effort, .hold, e1rm: previous, basis: latest.set.set.id)
            } else if estimate == previous {
                reason = .hold
            }
        }

        let share = exercise.metric == .bodyweightReps ? (bodyweight ?? latest.set.bodyweight).map { $0.kilograms * exercise.bodyweightShare } ?? 0 : 0
        guard exercise.metric != .assistedReps else {
            return plan(Effort(reps: targetReps, load: latest.set.set.primary.load), .repeatLast, e1rm: estimate,
                        basis: latest.set.set.id)
        }
        let aim = Double(targetReps) + target.rir
        let ideal = OneRepMax.load(forReps: aim, oneRepMax: estimate) - share
        let step = increments.step(in: unit)
        let minimum = increments.minimum?.value(in: unit) ?? 0
        // Added load for bodyweight lifts is optional: nothing added is a valid choice.
        let floorValue = exercise.metric == .bodyweightReps ? 0 : minimum
        let base = max(floorValue, (ideal / unit.kilogramsPerUnit / step).rounded(.down) * step)
        func reps(_ value: Double) -> Double {
            OneRepMax.repsToFailure(load: value * unit.kilogramsPerUnit + share, oneRepMax: estimate) - target.rir
        }
        let candidates = (-3...3).map { base + Double($0) * step }.filter { $0 >= floorValue }
        func choose(lower: Int, upper: Int) -> (Double, Int)? {
            candidates.compactMap { value -> (Double, Int, Double)? in
                let exact = reps(value)
                let whole = Int(exact.rounded(.down))
                guard (lower...upper).contains(whole) else { return nil }
                return (value, whole, exact - Double(whole))
            }
            // Every candidate leaves the target RIR or up to one more. Prefer reps
            // near the middle of the range, then the closest RIR, then heavier.
            .min { a, b in
                let costA = abs(Double(a.1) - target.targetReps) + a.2 * 0.5
                let costB = abs(Double(b.1) - target.targetReps) + b.2 * 0.5
                return abs(costA - costB) > 1e-9 ? costA < costB : a.0 > b.0
            }
            .map { ($0.0, $0.1) }
        }
        var outside = false
        var choice = choose(lower: target.minReps, upper: target.maxReps)
        if choice == nil && expandRepRange {
            choice = choose(lower: max(1, target.minReps - 2), upper: target.maxReps + 2)
            outside = choice != nil
        }
        let (value, count) = choice ?? {
            outside = true
            let clamped = Int(reps(base).rounded(.down))
            return (base, min(max(clamped, target.minReps), target.maxReps))
        }()
        let load: Mass? = exercise.metric == .bodyweightReps && value == 0 ? nil : Mass(value, unit)
        if reason == .progress, let last = latest.set.set.primary.reps {
            // Only call it progress when it asks for more than the last top set did.
            let lastLoad = latest.set.set.primary.load?.kilograms ?? 0
            let newLoad = load?.kilograms ?? 0
            if newLoad < lastLoad - 1e-9 || (abs(newLoad - lastLoad) < 1e-9 && count <= last) { reason = .hold }
        }
        return plan(Effort(reps: count, load: load), reason, e1rm: estimate, basis: latest.set.set.id, outside: outside)
    }
}
