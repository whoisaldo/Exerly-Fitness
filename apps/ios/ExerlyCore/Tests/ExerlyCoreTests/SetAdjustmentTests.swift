import Foundation
import Testing
@testable import ExerlyCore

/// Set-by-set adjustment (PARITY P08): after a set is logged, the rest of the
/// slot is planned from it. docs/design/006-programs-progression.md.
@Suite struct SetAdjustmentTests {
    let bench = ExerciseLibrary.bundled.exercise("barbell-bench-press")!
    let target = SlotTarget(sets: 3, minReps: 6, maxReps: 8, rir: 2)

    func set(_ reps: Int, _ kilograms: Double, rir: Double?) -> PerformedSet {
        PerformedSet(efforts: [Effort(reps: reps, load: .kg(kilograms))], rir: rir)
    }

    func today(_ set: PerformedSet) -> Double {
        ExerciseStatistics.oneRepMax(set, exercise: bench, bodyweight: nil)!
    }

    @Test func aFirstSessionsFirstSetIsTheAssessmentForTheRest() {
        let first = Progression.recommendation(target, exercise: bench, records: [], bodyweight: nil,
                                               increments: .defaults(for: bench), expandRepRange: false)
        #expect(first.reason == .firstSession && first.sets.allSatisfy { $0.effort.load == nil })
        let done = set(8, 80, rir: 2)
        let matched = Progression.adjust(target, exercise: bench, done: [done], remaining: 2, planned: first, bodyweight: nil)
        #expect(matched.reason == .firstSession && matched.basisSetID == done.id)
        #expect(matched.oneRepMax == today(done))
        #expect(matched.sets.map(\.effort.load) == [.kg(80), .kg(80)], "weight match keeps the load")
        let reps = matched.sets.compactMap(\.effort.reps)
        #expect(reps.count == 2 && reps[0] <= 8 && reps[1] <= reps[0] && reps[1] >= 6, "\(reps)")
        for (offset, planned) in matched.sets.enumerated() {
            let capacity = today(done) * (1 - Progression.setFatigue * Double(offset + 1))
            let reserve = OneRepMax.repsToFailure(load: 80, oneRepMax: capacity) - Double(planned.effort.reps!)
            #expect(reserve >= 2 - 1e-9 && reserve < 3, "set \(offset + 2) leaves the target RIR: \(reserve)")
        }

        let free = Progression.adjust(target, exercise: bench, done: [done], remaining: 2, planned: first, bodyweight: nil,
                                      weightMatch: false)
        #expect(!free.outsideRange)
        for planned in free.sets {
            #expect((6...8).contains(planned.effort.reps!) && planned.effort.load!.kilograms <= 80)
        }
    }

    @Test func todaysSetMovesThePlanWithinTheNeverPunitiveBounds() {
        let planned = Recommendation(sets: Array(repeating: PlannedSet(kind: .standard, effort: Effort(reps: 7, load: .kg(100)), rir: 2),
                                                 count: 3),
                                     reason: .progress, oneRepMax: today(set(7, 100, rir: 2)), basisSetID: nil, outsideRange: false)
        let base = planned.oneRepMax!
        let asPlanned = Progression.adjust(target, exercise: bench, done: [set(7, 100, rir: 2)], remaining: 2,
                                           planned: planned, bodyweight: nil)
        #expect(asPlanned.reason == .hold && asPlanned.sets.count == 2)

        let strong = Progression.adjust(target, exercise: bench, done: [set(10, 100, rir: 2)], remaining: 2,
                                        planned: planned, bodyweight: nil)
        #expect(strong.reason == .progress && strong.oneRepMax == base * 1.05, "a rise is capped at 5 %")

        let typo = Progression.adjust(target, exercise: bench, done: [set(7, 1000, rir: 2)], remaining: 1,
                                      planned: planned, bodyweight: nil, weightMatch: false)
        #expect(typo.oneRepMax == base * 1.05 && typo.sets[0].effort.load!.kilograms < 110, "a mistyped load can't jump the plan")

        let weak = Progression.adjust(target, exercise: bench, done: [set(3, 100, rir: 0)], remaining: 2,
                                      planned: planned, bodyweight: nil, weightMatch: false)
        #expect(weak.reason == .reduce && weak.oneRepMax == base * 0.9, "never more than 10 % lighter")
        #expect(weak.sets.allSatisfy { $0.effort.load!.kilograms < 100 && (6...8).contains($0.effort.reps!) })

        let matched = Progression.adjust(target, exercise: bench, done: [set(3, 100, rir: 0)], remaining: 2,
                                         planned: planned, bodyweight: nil)
        #expect(matched.outsideRange && matched.sets.allSatisfy { $0.effort.load == .kg(100) && $0.effort.reps! >= 1 })
    }

    @Test func warmUpsDontCountAndNothingDoneKeepsThePlan() {
        var warmUp = set(10, 40, rir: 5)
        warmUp.kind = .warmUp
        let planned = Recommendation(sets: Array(repeating: PlannedSet(kind: .standard, effort: Effort(reps: 7, load: .kg(100)), rir: 2),
                                                 count: 3),
                                     reason: .hold, oneRepMax: 125, basisSetID: nil, outsideRange: false)
        let unchanged = Progression.adjust(target, exercise: bench, done: [warmUp], remaining: 3, planned: planned, bodyweight: nil)
        #expect(unchanged.sets == planned.sets && unchanged.reason == .hold)
        #expect(Progression.adjust(target, exercise: bench, done: [set(7, 100, rir: 2)], remaining: 0, planned: planned,
                                   bodyweight: nil).sets.isEmpty)

        let plank = ExerciseLibrary.bundled.exercises.first { !$0.metric.tracksReps }!
        let held = PerformedSet(efforts: [Effort(duration: 60)])
        let timed = Progression.adjust(target, exercise: plank, done: [held], remaining: 2, bodyweight: nil)
        #expect(timed.reason == .repeatLast && timed.sets.map(\.effort) == [held.primary, held.primary])
    }
}
