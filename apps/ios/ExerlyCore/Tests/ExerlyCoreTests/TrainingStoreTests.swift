import Foundation
import Testing
@testable import ExerlyCore

@MainActor
@Suite struct TrainingStoreTests {
    final class Clock: @unchecked Sendable {
        var now = Fixture.instant()
        func advance(minutes: Double) { now = now.addingTimeInterval(minutes * 60) }
    }

    func makeStore(_ persistence: InMemoryTrainingPersistence = InMemoryTrainingPersistence(), clock: Clock = Clock()) throws -> TrainingStore {
        try TrainingStore(persistence: persistence, now: { clock.now })
    }

    func log(_ store: TrainingStore, _ setID: UUID, reps: Int, kg: Double, rir: Double? = nil) throws {
        let (performedID, set) = try #require(store.activeSession?.set(setID))
        var updated = set
        updated.primary = Effort(reps: reps, load: .kg(kg))
        updated.rir = rir
        try store.updateSet(updated, in: performedID)
        try store.completeSet(setID)
    }

    @Test func runsAWholeSessionAndPersistsEveryStep() throws {
        let persistence = InMemoryTrainingPersistence()
        let clock = Clock()
        let store = try makeStore(persistence, clock: clock)
        #expect(store.activeSession == nil)

        try store.startSession(name: "Lower", bodyweight: .kg(80), timeZone: Fixture.utc)
        let squat = try store.addExercise("back-squat")
        let first = try #require(store.activeSession?.exercises[0].sets[0].id)
        try log(store, first, reps: 5, kg: 100, rir: 2)
        #expect(persistence.sessions.values.first?.exercises[0].sets[0].isCompleted == true)

        // Completing a set starts the rest timer from the policy.
        #expect(store.restTimer?.duration == 180)
        #expect(store.restTimer?.startedAt == clock.now)

        clock.advance(minutes: 3)
        let second = try store.addSet(to: squat)
        try log(store, second, reps: 5, kg: 100, rir: 1)

        clock.advance(minutes: 30)
        let summary = try store.finishSession()
        #expect(store.activeSession == nil)
        #expect(store.restTimer == nil)
        #expect(summary.session.endedAt == clock.now)
        #expect(summary.records.isEmpty)
        #expect(store.history.sessions.count == 1)
        #expect(persistence.sessions.count == 1)
        #expect(persistence.sessions.values.first?.isFinished == true)
    }

    @Test func prefillsFromTheLastSessionAndReportsRecords() throws {
        let clock = Clock()
        let store = try makeStore(clock: clock)
        try store.startSession(name: "A", bodyweight: .kg(80))
        try store.addExercise("barbell-bench-press")
        try log(store, store.activeSession!.exercises[0].sets[0].id, reps: 5, kg: 100, rir: 1)
        try store.finishSession()

        clock.advance(minutes: 60 * 48)
        try store.startSession(name: "B", bodyweight: .kg(80))
        let bench = try store.addExercise("barbell-bench-press")
        let prefilled = try #require(store.activeSession?.exercises[0].sets[0])
        #expect(prefilled.primary == Effort(reps: 5, load: .kg(100)))
        #expect(!prefilled.isCompleted)
        #expect(store.previousSets(for: bench).map(\.primary) == [Effort(reps: 5, load: .kg(100))])

        try log(store, prefilled.id, reps: 5, kg: 105, rir: 1)
        let summary = try store.finishSession()
        #expect(Set(summary.records.map(\.kind)) == [.heaviestLoad, .oneRepMax, .setVolume])
    }

    @Test func restoresAnUnfinishedSessionAfterRelaunch() throws {
        let persistence = InMemoryTrainingPersistence()
        let store = try makeStore(persistence)
        try store.startSession(name: "Interrupted", bodyweight: nil)
        try store.addExercise("deadlift")

        let relaunched = try makeStore(persistence)
        #expect(relaunched.activeSession?.name == "Interrupted")
        #expect(relaunched.activeSession?.exercises.count == 1)
        #expect(relaunched.history.sessions.isEmpty)
    }

    @Test func refusesASecondActiveSession() throws {
        let store = try makeStore()
        try store.startSession(name: "One", bodyweight: nil)
        #expect(throws: TrainingStore.StoreError.sessionInProgress) {
            try store.startSession(name: "Two", bodyweight: nil)
        }
        #expect(throws: TrainingStore.StoreError.self) { try store.addSet(to: UUID()) }
    }

    @Test func discardingRemovesTheSessionEverywhere() throws {
        let persistence = InMemoryTrainingPersistence()
        let store = try makeStore(persistence)
        try store.startSession(name: "Oops", bodyweight: nil)
        try store.discardSession()
        #expect(store.activeSession == nil)
        #expect(persistence.sessions.isEmpty)
        #expect(throws: TrainingStore.StoreError.noActiveSession) { try store.addExercise("deadlift") }
    }

    @Test func editsAndDeletesPastSessions() throws {
        let persistence = InMemoryTrainingPersistence()
        let store = try makeStore(persistence)
        try store.startSession(name: "Past", bodyweight: .kg(80))
        try store.addExercise("deadlift")
        try log(store, store.activeSession!.exercises[0].sets[0].id, reps: 3, kg: 180)
        let finished = try store.finishSession().session

        var edited = finished
        edited.notes = "Felt quick"
        try store.saveSession(edited)
        #expect(store.history.session(finished.id)?.notes == "Felt quick")
        #expect(persistence.sessions[finished.id]?.notes == "Felt quick")

        try store.deleteSession(finished.id)
        #expect(store.history.sessions.isEmpty)
        #expect(persistence.sessions.isEmpty)
    }

    @Test func restTimerCanBeExtendedAndSkipped() throws {
        let clock = Clock()
        let store = try makeStore(clock: clock)
        try store.startSession(name: "Arms", bodyweight: nil)
        try store.addExercise("dumbbell-curl")
        try log(store, store.activeSession!.exercises[0].sets[0].id, reps: 12, kg: 14)
        #expect(store.restTimer?.duration == 90)
        store.extendRest(by: 30)
        #expect(store.restTimer?.duration == 120)
        store.skipRest()
        #expect(store.restTimer == nil)
        store.startRest(seconds: 45)
        #expect(store.restTimer == RestTimer(startedAt: clock.now, duration: 45))
    }

    @Test func customExercisesPersistAndCanBeLogged() throws {
        let persistence = InMemoryTrainingPersistence()
        let store = try makeStore(persistence)
        let custom = Exercise(
            id: .custom(), name: "Zercher Squat", metric: .weightReps, mechanics: .compound,
            region: .lower, muscles: [.quads: 1, .glutes: 1, .midBack: 0.5], equipment: [.barbell]
        )
        try store.addCustomExercise(custom)
        #expect(store.library.exercise(custom.id) == custom)
        #expect(throws: TrainingStore.StoreError.self) {
            try store.addCustomExercise(Exercise(id: "plain-id", name: "X", metric: .weightReps, mechanics: .isolation,
                                                 region: .upper, muscles: [.biceps: 1], equipment: [.cable]))
        }

        let relaunched = try makeStore(persistence)
        #expect(relaunched.library.exercise(custom.id)?.name == "Zercher Squat")
        try relaunched.startSession(name: "Custom", bodyweight: nil)
        try relaunched.addExercise(custom.id)
    }
}
