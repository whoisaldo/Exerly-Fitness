import Foundation
@testable import ExerlyCore

/// Synthetic lifters whose truth is known: progression, noise, plateaus,
/// fatigue blocks and typing mistakes injected at known sets. Detectors are
/// scored against it (docs/design/005-training-detectors.md). No real data.
struct TrainingSimulator {
    struct Lift {
        var id: ExerciseID
        /// Estimated 1RM at the start, in kilograms (effective load for bodyweight lifts).
        var oneRepMax: Double
    }

    struct Injection: Hashable {
        var sessionID: UUID
        var setID: UUID
        var kind: EntryErrorDetector.Finding.Kind
        var truth: Effort
    }

    struct Profile {
        var seed: UInt64
        var weeks = 16
        var unit: MassUnit = .kilograms
        /// Weekly e1RM gain as a fraction, such as 0.006 for 0.6 % a week.
        var weeklyGain = 0.006
        /// Session-to-session noise in strength, as a fraction.
        var noise = 0.025
        /// Share of working sets with a typing mistake.
        var errorRate = 0.0
        /// From this week on, strength stops growing.
        var plateauFromWeek: Int?
        /// Weeks in which strength drops by `fatigueDrop`.
        var fatigueWeeks: ClosedRange<Int>?
        var fatigueDrop = 0.07
        var bodyweight = 80.0
    }

    struct Result {
        var sessions: [WorkoutSession]
        var injections: [Injection]
        /// The strength multiplier on each session's local date, for scoring trends.
        var strength: [UUID: Double]
    }

    static let lifts = [
        Lift(id: "barbell-bench-press", oneRepMax: 100), Lift(id: "back-squat", oneRepMax: 140),
        Lift(id: "deadlift", oneRepMax: 170), Lift(id: "overhead-press", oneRepMax: 60),
        Lift(id: "barbell-row", oneRepMax: 95), Lift(id: "pull-up", oneRepMax: 105),
    ]
    static let plans: [[Int]] = [[0, 1, 4], [3, 2, 5], [1, 0, 4], [2, 3, 5]]
    static let repTargets = [3, 5, 6, 8, 10, 12]

    struct Random {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state >> 11
        }
        mutating func unit() -> Double { Double(next() % 1_000_000) / 1_000_000 }
        mutating func int(_ range: ClosedRange<Int>) -> Int { range.lowerBound + Int(next() % UInt64(range.count)) }
        mutating func chance(_ p: Double) -> Bool { unit() < p }
        /// Roughly normal, from the sum of uniforms.
        mutating func normal() -> Double { (0..<6).reduce(0) { total, _ in total + unit() } - 3 }
    }

    static func run(_ profile: Profile) -> Result {
        var random = Random(state: profile.seed &+ 0x9E37_79B9)
        var sessions: [WorkoutSession] = []
        var injections: [Injection] = []
        var strength: [UUID: Double] = [:]
        let step = profile.unit == .kilograms ? 2.5 : 5
        let start = Date.milliseconds(1_783_339_200_000) // 2026-07-06 12:00 UTC, a Monday.
        var planIndex = 0
        for week in 0..<profile.weeks {
            for day in [0, 2, 4] {
                let growthWeeks = Double(min(week, profile.plateauFromWeek ?? week))
                var multiplier = 1 + profile.weeklyGain * growthWeeks
                if let fatigue = profile.fatigueWeeks, fatigue.contains(week) { multiplier *= 1 - profile.fatigueDrop }
                let dayNoise = 1 + profile.noise * random.normal()
                let startedAt = start.addingTimeInterval(Double(week * 7 + day) * 86_400 + Double(random.int(0...600)) * 60)
                var clock = startedAt
                var exercises: [PerformedExercise] = []
                let reps = repTargets[random.int(0...repTargets.count - 1)]
                for liftIndex in plans[planIndex % plans.count] {
                    let lift = lifts[liftIndex]
                    let today = lift.oneRepMax * multiplier * dayNoise
                    var sets: [PerformedSet] = []
                    func entered(_ kilograms: Double, bodyweightShare: Double) -> Mass? {
                        let added = kilograms - profile.bodyweight * bodyweightShare
                        if bodyweightShare > 0 && added < step / 2 { return nil }
                        let value = (added / profile.unit.kilogramsPerUnit / step).rounded() * step
                        return Mass(value, profile.unit)
                    }
                    let share = lift.id == "pull-up" ? 0.95 : 0
                    if share == 0 {
                        for fraction in [0.5, 0.7] {
                            clock = clock.addingTimeInterval(120)
                            sets.append(PerformedSet(kind: .warmUp, efforts: [Effort(reps: 5, load: entered(today * fraction * 0.8,
                                                                                                         bodyweightShare: 0))],
                                                     completedAt: clock))
                        }
                    }
                    for index in 0..<random.int(3...4) {
                        clock = clock.addingTimeInterval(Double(random.int(90...240)))
                        let rir = Double(random.int(0...3))
                        let backOff = index == 3 && random.chance(0.5)
                        let target = OneRepMax.load(forReps: Double(reps) + rir, oneRepMax: today) * (backOff ? 0.85 : 1)
                        let load = entered(target, bodyweightShare: share)
                        let effective = (load?.kilograms ?? 0) + profile.bodyweight * share
                        // Reps the load actually allows today, minus the reserve.
                        let capacity = max(1, Int((repsToFailure(load: effective, oneRepMax: today) - rir).rounded(.down)))
                        let done = max(1, min(capacity, reps + random.int(-1...1)))
                        var set = PerformedSet(efforts: [Effort(reps: done, load: load)], rir: rir, completedAt: clock)
                        if random.chance(profile.errorRate), let injection = inject(&set, unit: profile.unit, random: &random) {
                            injections.append(Injection(sessionID: UUID(), setID: set.id, kind: injection.kind, truth: injection.truth))
                        }
                        sets.append(set)
                    }
                    exercises.append(PerformedExercise(exerciseID: lift.id, sets: sets))
                }
                planIndex += 1
                let session = WorkoutSession(name: "Day \(planIndex)", startedAt: startedAt.roundedToMilliseconds,
                                             endedAt: clock.addingTimeInterval(300).roundedToMilliseconds,
                                             timeZone: TimeZone(identifier: "America/New_York")!,
                                             bodyweight: .kg(profile.bodyweight), exercises: exercises)
                for index in injections.indices where session.set(injections[index].setID) != nil {
                    injections[index].sessionID = session.id
                }
                strength[session.id] = multiplier
                sessions.append(session)
            }
        }
        return Result(sessions: sessions, injections: injections, strength: strength)
    }

    /// The reps to failure a load allows, the inverse of the e1RM formula.
    static func repsToFailure(load: Double, oneRepMax: Double) -> Double {
        guard load > 0 else { return 30 }
        let brzycki = 37 - 36 * load / oneRepMax
        return brzycki <= 10 ? max(1, brzycki) : (oneRepMax / load - 1) * 30
    }

    /// Mistypes one set the way people do. Returns what it should have been.
    static func inject(_ set: inout PerformedSet, unit: MassUnit, random: inout Random)
        -> (kind: EntryErrorDetector.Finding.Kind, truth: Effort)? {
        let truth = set.primary
        guard let load = truth.load, let reps = truth.reps else { return nil }
        switch random.int(0...3) {
        case 0:
            set.primary.load = Mass(load.value * 10, load.unit) // An extra zero.
            return (.loadDigit, truth)
        case 1:
            guard load.value >= 40, load.value.truncatingRemainder(dividingBy: 10) == 0 else { return nil }
            set.primary.load = Mass(load.value / 10, load.unit) // A missing zero.
            return (.loadDigit, truth)
        case 2:
            set.primary.load = Mass(load.value, unit == .kilograms ? .pounds : .kilograms) // The wrong unit.
            return (.unitSwap, truth)
        default:
            guard reps <= 9 else { return nil }
            set.primary.reps = reps * 11 // A doubled digit, such as 55 for 5.
            return (.repsDigit, truth)
        }
    }
}
