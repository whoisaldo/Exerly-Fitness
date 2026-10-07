import Foundation

/// The load steps an exercise's equipment allows, in each unit, and the
/// lightest load it can be set to.
public struct LoadIncrements: Sendable, Codable, Hashable {
    public var kilograms: Double
    public var pounds: Double
    /// The lightest loadable weight, such as an empty barbell. Nil means zero.
    public var minimum: Mass?
    /// The weights the equipment really comes in, such as a gym's dumbbells.
    /// When set, recommendations choose among these instead of stepping.
    public var available: [Mass]?

    public init(kilograms: Double, pounds: Double, minimum: Mass? = nil, available: [Mass]? = nil) {
        self.kilograms = kilograms
        self.pounds = pounds
        self.minimum = minimum
        self.available = available
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
    /// Strength lost by each later set of a slot, as a share of the e1RM: about
    /// a rep at a typical working load with a few minutes' rest.
    static let setFatigue = 0.02

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
        // The session's top set, for "the same load" and "more than last time":
        // the hardest load (least assistance), most reps at it, among sets with
        // an estimate. Not the best estimate, which can come from a lighter
        // later set reported generously.
        let top = records.filter { $0.sessionID == latest.id }.compactMap { record -> (SetRecord, Double)? in
            guard record.set.primary.reps != nil,
                  let load = Volume.effectiveLoad(record.set.primary, exercise: exercise, bodyweight: record.bodyweight)
            else { return nil }
            return (record, load)
        }.max { a, b in a.1 != b.1 ? a.1 < b.1 : (a.0.set.primary.reps ?? 0) < (b.0.set.primary.reps ?? 0) }?.0 ?? latest.set
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
                let effort = Effort(reps: targetReps, load: top.set.primary.load)
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
        let (effort, outside) = prescription(target, exercise: exercise, estimate: estimate, unit: unit, share: share,
                                             increments: increments, expandRepRange: expandRepRange)
        let load = effort.load, count = effort.reps ?? targetReps
        if reason == .progress, let last = top.set.primary.reps {
            // Only call it progress when it asks for more than the last top set did.
            let lastLoad = top.set.primary.load?.kilograms ?? 0
            let newLoad = load?.kilograms ?? 0
            if newLoad < lastLoad - 1e-9 || (abs(newLoad - lastLoad) < 1e-9 && count <= last) { reason = .hold }
        }
        return plan(Effort(reps: count, load: load), reason, e1rm: estimate, basis: latest.set.set.id, outside: outside)
    }

    /// Set-by-set adjustment: once some working sets of a slot are done in
    /// today's session, the plan for the `remaining` ones, from how the last
    /// set went. Each later set is planned a little weaker (`setFatigue`).
    ///
    /// - With `weightMatch`, the remaining sets keep that set's load and their
    ///   reps follow, up to the top of the range; reps below it set `outsideRange`.
    /// - Without it, each set gets the load that leaves the target RIR in range.
    ///
    /// `planned` is the session's recommendation: today's estimate stays within
    /// its never-punitive bounds (no more than 5 % above, 10 % below), and the
    /// reason compares today with it. Without one, or after a first session's
    /// plan, the first set is the assessment and sets the loads.
    public static func adjust(_ target: SlotTarget, exercise: Exercise, done: [PerformedSet], remaining: Int,
                              planned: Recommendation? = nil, bodyweight: Mass?, increments: LoadIncrements? = nil,
                              expandRepRange: Bool = false, weightMatch: Bool = true) -> Recommendation {
        let count = max(0, remaining)
        let fallback = Recommendation(sets: Array((planned?.sets ?? []).suffix(count)), reason: planned?.reason ?? .firstSession,
                                      oneRepMax: planned?.oneRepMax, basisSetID: planned?.basisSetID,
                                      outsideRange: planned?.outsideRange ?? false)
        let working = done.filter { $0.kind != .warmUp }
        guard let last = working.last else { return fallback }
        guard exercise.metric.tracksReps, exercise.metric != .assistedReps else {
            return Recommendation(sets: Array(repeating: PlannedSet(kind: target.kind, effort: last.primary, rir: target.rir), count: count),
                                  reason: .repeatLast, oneRepMax: nil, basisSetID: last.id, outsideRange: false)
        }
        var rated = last
        if rated.rir == nil && rated.kind != .failure { rated.rir = target.rir }
        guard let today = ExerciseStatistics.oneRepMax(rated, exercise: exercise, bodyweight: bodyweight) else { return fallback }
        let baseline = planned?.reason == .firstSession ? nil : planned?.oneRepMax
        let estimate = baseline.map { min(max(today, $0 * (1 - maximumCut)), $0 * (1 + maximumRise)) } ?? today
        var reason = Recommendation.Reason.firstSession
        if let baseline {
            // What the plan predicted for this set, fatigue included, against what was done.
            let index = Double(working.count - 1)
            let load = Volume.effectiveLoad(last.primary, exercise: exercise, bodyweight: bodyweight) ?? 0
            let predicted = OneRepMax.repsToFailure(load: load, oneRepMax: baseline * (1 - setFatigue * index))
            let achieved = Double(last.primary.reps ?? 0) + (rated.effectiveRIR ?? target.rir)
            reason = achieved < predicted - holdBand - 1e-9 ? .reduce : achieved > predicted + holdBand + 1e-9 ? .progress : .hold
        }
        let unit = last.primary.load?.unit ?? planned?.sets.lazy.compactMap(\.effort.load).first?.unit ?? .kilograms
        let share = exercise.metric == .bodyweightReps ? (bodyweight?.kilograms ?? 0) * exercise.bodyweightShare : 0
        let steps = increments ?? .defaults(for: exercise)
        var outside = false
        let sets = (0..<count).map { offset -> PlannedSet in
            let capacity = estimate * (1 - setFatigue * Double(offset + 1))
            let effort: Effort
            if weightMatch {
                let load = (last.primary.load?.kilograms ?? 0) + share
                let reps = Int((OneRepMax.repsToFailure(load: load, oneRepMax: capacity) - target.rir).rounded(.down))
                let range = expandRepRange ? max(1, target.minReps - 2)...(target.maxReps + 2) : target.minReps...target.maxReps
                // Below the range is outside it; above, the reps stop at the top and leave more in reserve.
                if reps < range.lowerBound { outside = true }
                effort = Effort(reps: min(max(reps, 1), range.upperBound), load: last.primary.load)
            } else {
                let chosen = prescription(target, exercise: exercise, estimate: capacity, unit: unit, share: share,
                                          increments: steps, expandRepRange: expandRepRange)
                if chosen.outside { outside = true }
                effort = chosen.effort
            }
            return PlannedSet(kind: target.kind, effort: effort, rir: target.rir)
        }
        return Recommendation(sets: sets, reason: reason, oneRepMax: estimate, basisSetID: last.id, outsideRange: outside)
    }

    /// The load and reps for one set at an estimated `estimate` (e1RM, kg):
    /// the heaviest load the equipment allows that leaves the target RIR
    /// within the rep range. `share` is the bodyweight a lift moves, in kg.
    static func prescription(_ target: SlotTarget, exercise: Exercise, estimate: Double, unit: MassUnit, share: Double,
                             increments: LoadIncrements, expandRepRange: Bool) -> (effort: Effort, outside: Bool) {
        let aim = target.targetReps.rounded(.down) + target.rir
        let ideal = OneRepMax.load(forReps: aim, oneRepMax: estimate) - share
        let step = increments.step(in: unit)
        let minimum = increments.minimum?.value(in: unit) ?? 0
        // Added load for bodyweight lifts is optional: nothing added is a valid choice.
        let floorValue = exercise.metric == .bodyweightReps ? 0 : minimum
        var base = max(floorValue, (ideal / unit.kilogramsPerUnit / step).rounded(.down) * step)
        func reps(_ value: Double) -> Double {
            OneRepMax.repsToFailure(load: value * unit.kilogramsPerUnit + share, oneRepMax: estimate) - target.rir
        }
        var candidates = (-3...3).map { base + Double($0) * step }.filter { $0 >= floorValue }
        // The gym's own weights instead: up to three either side of the ideal.
        if let available = increments.available, !available.isEmpty {
            var listed = available.map { $0.value(in: unit) }
            if exercise.metric == .bodyweightReps { listed.append(0) }
            listed = Set(listed.filter { $0 >= floorValue }).sorted()
            if !listed.isEmpty {
                let below = listed.lastIndex { $0 <= ideal / unit.kilogramsPerUnit + 1e-9 } ?? 0
                base = listed[below]
                candidates = Array(listed[max(0, below - 3)...min(listed.count - 1, below + 3)])
            }
        }
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
        return (Effort(reps: count, load: load), outside)
    }
}
