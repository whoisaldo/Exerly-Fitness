import Foundation
import Testing
@testable import ExerlyCore

@Suite struct RestTests {
    let library = Fixture.library
    let policy = RestPolicy()

    @Test func defaultsFavourLongerRestForCompoundLifts() {
        #expect(policy.compoundLower == 180)
        #expect(policy.compoundUpper == 150)
        #expect(policy.isolation == 90)
        #expect(policy.warmUp == 60)
        #expect(policy.betweenSides == 15)
        #expect(policy.betweenExercises == 120)
    }

    @Test func picksTheRestForTheNextStep() throws {
        var session = WorkoutSession(startedAt: Fixture.instant(), timeZone: Fixture.utc)
        let squat = try session.addExercise("back-squat", library: library)
        try session.addSet(to: squat, kind: .standard)
        session.exercises[0].sets[0].kind = .warmUp
        try session.addExercise("one-arm-dumbbell-row", library: library)
        let bench = try session.addExercise("barbell-bench-press", library: library)
        try session.addSet(to: bench)
        let raise = try session.addExercise("dumbbell-lateral-raise", library: library)
        try session.addSet(to: raise)
        try session.makeSuperset([bench, raise])

        let s = session.exercises.map { $0.sets.map(\.id) }
        #expect(policy.rest(after: s[0][0], in: session, library: library) == 60, "warm-up")
        #expect(policy.rest(after: s[0][1], in: session, library: library) == 120, "last squat set, then rows")
        #expect(policy.rest(after: s[1][0], in: session, library: library) == 15, "left, then right")
        #expect(policy.rest(after: s[1][1], in: session, library: library) == 120, "rows done, then bench")
        #expect(policy.rest(after: s[2][0], in: session, library: library) == 0, "bench, then raise in the superset")
        // The rest before the next round is the rest for the exercise that comes next.
        #expect(policy.rest(after: s[3][0], in: session, library: library) == 150, "end of a superset round")
        // Skipped sets come back, so the last set in order still leads somewhere.
        #expect(policy.rest(after: s[3][1], in: session, library: library) == 120, "back to the skipped squats")

        session.exercises[2].restOverride = 200
        #expect(policy.rest(after: s[3][0], in: session, library: library) == 200)
        #expect(policy.rest(after: s[2][0], in: session, library: library) == 0)

        // With everything else done, the last set gets its own exercise's rest.
        for (e, performed) in session.exercises.enumerated() {
            for (i, set) in performed.sets.enumerated() where set.id != s[3][1] {
                session.exercises[e].sets[i].primary = Effort(reps: 8, load: .kg(20))
                session.exercises[e].sets[i].completedAt = Fixture.instant()
            }
        }
        #expect(policy.rest(after: s[3][1], in: session, library: library) == 90, "last set of the session")
        session.exercises[3].restOverride = 45
        #expect(policy.rest(after: s[3][1], in: session, library: library) == 45)
    }

    @Test func compoundLowerCoversFullBodyLifts() throws {
        var session = WorkoutSession(startedAt: Fixture.instant(), timeZone: Fixture.utc)
        let clean = try session.addExercise("power-clean", library: library)
        try session.addSet(to: clean)
        #expect(policy.rest(after: session.exercises[0].sets[0].id, in: session, library: library) == 180)
    }

    @Test func timerCountsDownFromAClock() {
        var timer = RestTimer(startedAt: Fixture.instant(), duration: 90)
        #expect(timer.endsAt == Fixture.instant(minutes: 1.5))
        #expect(timer.remaining(at: Fixture.instant()) == 90)
        #expect(timer.remaining(at: Fixture.instant(minutes: 1)) == 30)
        #expect(timer.remaining(at: Fixture.instant(minutes: 5)) == 0)
        #expect(!timer.isFinished(at: Fixture.instant(minutes: 1)))
        #expect(timer.isFinished(at: Fixture.instant(minutes: 1.5)))
        timer.extend(by: 30)
        #expect(timer.duration == 120)
        timer.extend(by: -500)
        #expect(timer.duration == 0)
    }
}
