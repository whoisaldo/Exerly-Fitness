import Foundation
import Testing
@testable import ExerlyCore

@Suite struct SessionEditingTests {
    let library = Fixture.library

    func emptySession() -> WorkoutSession {
        WorkoutSession(name: "Push", startedAt: Fixture.instant(), timeZone: Fixture.utc)
    }

    @Test func addingAnExerciseWithoutHistoryCreatesOneEmptySet() throws {
        var session = emptySession()
        let id = try session.addExercise("barbell-bench-press", library: library)
        let performed = try #require(session.exercises.first)
        #expect(performed.id == id)
        #expect(performed.sets.count == 1)
        #expect(performed.sets[0].primary == Effort())
        #expect(!performed.sets[0].isCompleted)
    }

    @Test func aUnilateralExerciseStartsWithALeftAndRightSet() throws {
        var session = emptySession()
        try session.addExercise("one-arm-dumbbell-row", library: library)
        #expect(session.exercises[0].sets.map(\.side) == [.left, .right])
    }

    @Test func addingAnExercisePrefillsFromTheLastPerformance() throws {
        var previous = PerformedExercise(exerciseID: "back-squat", sets: [
            Fixture.set(5, 60, kind: .warmUp),
            Fixture.set(5, 100, rir: 2),
            Fixture.set(5, 100, rir: 1),
        ])
        previous.notes = "Belt on top sets"
        var session = emptySession()
        try session.addExercise("back-squat", previous: previous, library: library)
        let sets = session.exercises[0].sets
        #expect(sets.map(\.kind) == [.warmUp, .standard, .standard])
        #expect(sets.map(\.primary.load) == [.kg(60), .kg(100), .kg(100)])
        #expect(sets.allSatisfy { !$0.isCompleted && $0.rir == nil })
        #expect(Set(sets.map(\.id)).isDisjoint(with: previous.sets.map(\.id)))
        #expect(session.exercises[0].notes.isEmpty)
    }

    @Test func rejectsUnknownExercises() {
        var session = emptySession()
        #expect(throws: WorkoutSession.EditError.self) { try session.addExercise("nope", library: library) }
    }

    @Test func addingASetCopiesThePreviousSetAndAlternatesSides() throws {
        var session = emptySession()
        let row = try session.addExercise("one-arm-dumbbell-row", library: library)
        var left = session.exercises[0].sets[0]
        left.primary = Effort(reps: 10, load: .kg(30))
        try session.updateSet(left, in: row)
        let added = try session.addSet(to: row)
        let set = try #require(session.exercises[0].sets.last)
        #expect(set.id == added)
        // A new left set copies the last left set.
        #expect(set.side == .left)
        #expect(set.primary == Effort(reps: 10, load: .kg(30)))

        var session2 = emptySession()
        let bench = try session2.addExercise("barbell-bench-press", library: library)
        var first = session2.exercises[0].sets[0]
        first.primary = Effort(reps: 8, load: .kg(80))
        first.rir = 2
        try session2.updateSet(first, in: bench)
        try session2.addSet(to: bench)
        #expect(session2.exercises[0].sets[1].primary == Effort(reps: 8, load: .kg(80)))
        #expect(session2.exercises[0].sets[1].rir == nil)
        try session2.addSet(to: bench, kind: .drop)
        #expect(session2.exercises[0].sets[2].kind == .drop)
    }

    @Test func propagatesChangedFieldsToLaterUntouchedSets() throws {
        var session = emptySession()
        let previous = PerformedExercise(exerciseID: "back-squat", sets: [
            Fixture.set(5, 100), Fixture.set(5, 100), Fixture.set(8, 100), Fixture.set(5, 90),
        ])
        let id = try session.addExercise("back-squat", previous: previous, library: library)
        var first = session.exercises[0].sets[0]
        first.primary.load = .kg(102.5)
        try session.updateSet(first, in: id, propagate: true)
        #expect(session.exercises[0].sets.map(\.primary.load) == [.kg(102.5), .kg(102.5), .kg(102.5), .kg(90)])
        #expect(session.exercises[0].sets.map(\.primary.reps) == [5, 5, 8, 5])

        // Completed sets keep their values, and a differing value ends the run:
        // the 90 kg back-off set keeps 5 reps because the 8-rep set breaks the run.
        try session.completeSet(session.exercises[0].sets[1].id, at: Fixture.instant(), library: library)
        var changed = session.exercises[0].sets[0]
        changed.primary.reps = 6
        try session.updateSet(changed, in: id, propagate: true)
        #expect(session.exercises[0].sets.map(\.primary.reps) == [6, 5, 8, 5])
    }

    @Test func completingASetRequiresTheMetricsFields() throws {
        var session = emptySession()
        let bench = try session.addExercise("barbell-bench-press", library: library)
        let setID = session.exercises[0].sets[0].id
        #expect(throws: WorkoutSession.EditError.incomplete(setID)) {
            try session.completeSet(setID, at: Fixture.instant(), library: library)
        }
        var set = session.exercises[0].sets[0]
        set.primary = Effort(reps: 5, load: .kg(100))
        try session.updateSet(set, in: bench)
        try session.completeSet(setID, at: Fixture.instant(minutes: 5), library: library)
        #expect(session.exercises[0].sets[0].completedAt == Fixture.instant(minutes: 5))
        try session.reopenSet(setID)
        #expect(!session.exercises[0].sets[0].isCompleted)
    }

    @Test func validatesEffortsPerMetric() throws {
        let pullUp = try #require(library.exercise("pull-up"))
        let plank = try #require(library.exercise("plank"))
        let run = try #require(library.exercise("running"))
        let carry = try #require(library.exercise("farmers-carry"))
        #expect(PerformedSet(efforts: [Effort(reps: 8)]).isLoggable(for: pullUp))
        #expect(!PerformedSet(efforts: [Effort(reps: 0)]).isLoggable(for: pullUp))
        #expect(PerformedSet(efforts: [Effort(duration: 60)]).isLoggable(for: plank))
        #expect(!PerformedSet(efforts: [Effort(reps: 10)]).isLoggable(for: plank))
        #expect(PerformedSet(efforts: [Effort(duration: 1200)]).isLoggable(for: run))
        #expect(PerformedSet(efforts: [Effort(distance: 5000)]).isLoggable(for: run))
        #expect(!PerformedSet(efforts: [Effort(load: .kg(40))]).isLoggable(for: carry))
        #expect(!PerformedSet(efforts: [Effort(reps: 8)], rir: 7).isLoggable(for: pullUp))
        #expect(!PerformedSet(efforts: [Effort(reps: 8, load: .kg(-5))]).isLoggable(for: pullUp))
        #expect(!PerformedSet(kind: .standard, efforts: [Effort(reps: 8), Effort(reps: 4)]).isLoggable(for: pullUp))
        #expect(PerformedSet(kind: .myo, efforts: [Effort(reps: 8), Effort(reps: 4)]).isLoggable(for: pullUp))
    }

    @Test func removesAndReordersExercisesAndSets() throws {
        var session = emptySession()
        let a = try session.addExercise("barbell-bench-press", library: library)
        let b = try session.addExercise("barbell-row", library: library)
        let c = try session.addExercise("dumbbell-lateral-raise", library: library)
        try session.moveExercise(c, to: 0)
        #expect(session.exercises.map(\.id) == [c, a, b])
        try session.removeExercise(a)
        #expect(session.exercises.map(\.id) == [c, b])
        let extra = try session.addSet(to: b)
        try session.removeSet(extra)
        #expect(session.exercises[1].sets.count == 1)
        #expect(throws: WorkoutSession.EditError.self) { try session.removeSet(extra) }
    }

    @Test func supersetsGroupAdjacentExercisesAndDissolveBelowTwo() throws {
        var session = emptySession()
        let a = try session.addExercise("barbell-bench-press", library: library)
        let b = try session.addExercise("barbell-row", library: library)
        let c = try session.addExercise("dumbbell-lateral-raise", library: library)
        let group = try session.makeSuperset([a, c])
        #expect(session.exercises.map(\.id) == [a, c, b])
        #expect(session.exercises[0].supersetID == group && session.exercises[1].supersetID == group)
        #expect(session.exercises[2].supersetID == nil)
        try session.removeFromSuperset(c)
        #expect(session.exercises.allSatisfy { $0.supersetID == nil })
        #expect(throws: WorkoutSession.EditError.self) { try session.makeSuperset([a]) }
    }

    @Test func nextSetWalksExercisesInOrderAndRoundRobinsSupersets() throws {
        var session = emptySession()
        let bench = try session.addExercise("barbell-bench-press", library: library)
        try session.addSet(to: bench)
        let row = try session.addExercise("barbell-row", library: library)
        try session.addSet(to: row)
        let raise = try session.addExercise("dumbbell-lateral-raise", library: library)
        try session.makeSuperset([row, raise])
        try session.addSet(to: raise)

        let b = session.exercises[0].sets.map(\.id)
        let r = session.exercises[1].sets.map(\.id)
        let l = session.exercises[2].sets.map(\.id)

        #expect(session.nextSet(after: nil)?.setID == b[0])
        #expect(session.nextSet(after: b[0])?.setID == b[1])
        #expect(session.nextSet(after: b[1])?.setID == r[0])
        #expect(session.nextSet(after: r[0])?.setID == l[0])
        #expect(session.nextSet(after: l[0])?.setID == r[1])
        #expect(session.nextSet(after: r[1])?.setID == l[1])

        // Completed sets are skipped; skipped earlier sets come back at the end.
        for id in [b[1], r[0], r[1], l[0], l[1]] {
            var set = session.set(id)!.set
            set.primary = Effort(reps: 10, load: .kg(20))
            try session.updateSet(set, in: session.set(id)!.performedID)
            try session.completeSet(id, at: Fixture.instant(), library: library)
        }
        #expect(session.nextSet(after: l[1])?.setID == b[0])
        #expect(session.nextSet(after: nil)?.setID == b[0])
    }

    @Test func finishingStampsTheEndAndCanDropIncompleteSets() throws {
        var session = emptySession()
        let bench = try session.addExercise("barbell-bench-press", library: library)
        try session.addSet(to: bench)
        var set = session.exercises[0].sets[0]
        set.primary = Effort(reps: 5, load: .kg(100))
        try session.updateSet(set, in: bench)
        try session.completeSet(set.id, at: Fixture.instant(minutes: 3), library: library)
        try session.addExercise("barbell-row", library: library)

        var kept = session
        kept.finish(at: Fixture.instant(minutes: 60), discardIncompleteSets: false)
        #expect(kept.endedAt == Fixture.instant(minutes: 60))
        #expect(kept.exercises.count == 2)

        session.finish(at: Fixture.instant(minutes: 60), discardIncompleteSets: true)
        #expect(session.exercises.count == 1)
        #expect(session.exercises[0].sets.count == 1)
    }
}
