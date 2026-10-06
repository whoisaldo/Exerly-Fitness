import Foundation
import Testing
@testable import ExerlyCore

/// Findings from the app agent's review of the first training interface.
@MainActor
@Suite struct ReviewFindingsTests {
    func storeWithBench(_ persistence: InMemoryTrainingPersistence = InMemoryTrainingPersistence(),
                        now: Date = Fixture.instant()) throws -> (TrainingStore, UUID, PerformedSet) {
        let store = try TrainingStore(persistence: persistence, now: { now })
        try store.startSession(name: "Push", bodyweight: .kg(80), timeZone: Fixture.utc)
        let bench = try store.addExercise("barbell-bench-press")
        var set = store.activeSession!.exercises[0].sets[0]
        set.primary = Effort(reps: 5, load: .kg(100))
        try store.updateSet(set, in: bench)
        try store.completeSet(set.id)
        return (store, bench, store.activeSession!.exercises[0].sets[0])
    }

    // MARK: High: validation at the store boundary

    @Test func aCompletedSetCannotLoseItsRequiredFields() throws {
        let persistence = InMemoryTrainingPersistence()
        let (store, bench, completed) = try storeWithBench(persistence)
        var broken = completed
        broken.primary.reps = nil
        #expect(throws: TrainingStore.StoreError.self) { try store.updateSet(broken, in: bench) }
        #expect(store.activeSession?.exercises[0].sets[0] == completed)
        #expect(persistence.sessions.values.first?.exercises[0].sets[0] == completed)
    }

    @Test func draftsMayBePartialButNeverNonsense() throws {
        let (store, bench, _) = try storeWithBench()
        let draftID = try store.addSet(to: bench)
        var draft = store.activeSession!.set(draftID)!.set
        draft.primary = Effort(reps: nil, load: .kg(60))
        try store.updateSet(draft, in: bench)

        for bad in [Effort(reps: -1), Effort(load: .kg(-5)), Effort(load: Mass(.nan, .kilograms)), Effort(duration: -3)] {
            var invalid = draft
            invalid.primary = bad
            #expect(throws: TrainingStore.StoreError.self) { try store.updateSet(invalid, in: bench) }
        }
        var noEfforts = draft
        noEfforts.efforts = []
        #expect(throws: TrainingStore.StoreError.self) { try store.updateSet(noEfforts, in: bench) }
        var badRIR = draft
        badRIR.rir = 9
        #expect(throws: TrainingStore.StoreError.self) { try store.updateSet(badRIR, in: bench) }
    }

    @Test func wholeSessionEditsKeepIdentityAndValidity() throws {
        let persistence = InMemoryTrainingPersistence()
        let (store, _, _) = try storeWithBench(persistence)
        let before = try #require(store.activeSession)

        #expect(throws: TrainingStore.StoreError.self) { try store.updateActiveSession { $0.id = UUID() } }
        #expect(throws: TrainingStore.StoreError.self) {
            try store.updateActiveSession { $0.exercises[0].sets[0].primary.load = nil }
        }
        #expect(throws: TrainingStore.StoreError.self) {
            try store.updateActiveSession { $0.exercises.append($0.exercises[0]) }
        }
        #expect(throws: TrainingStore.StoreError.self) {
            try store.updateActiveSession { $0.exercises[0].exerciseID = "no-such-exercise" }
        }
        #expect(throws: TrainingStore.StoreError.self) {
            try store.updateActiveSession { $0.timeZoneID = "Mars/Olympus" }
        }
        #expect(store.activeSession == before)
        #expect(persistence.sessions[before.id] == before)

        try store.updateActiveSession { $0.notes = "Felt strong" }
        #expect(store.activeSession?.notes == "Felt strong")
    }

    @Test func pastSessionCorrectionsAreValidatedToo() throws {
        let (store, _, _) = try storeWithBench()
        let finished = try store.finishSession().session
        var broken = finished
        broken.exercises[0].sets[0].primary.reps = 0
        #expect(throws: TrainingStore.StoreError.self) { try store.saveSession(broken) }
        var reopened = finished
        reopened.endedAt = nil
        #expect(throws: TrainingStore.StoreError.self) { try store.saveSession(reopened) }
    }

    @Test func aSetWithNoEffortsNeverCrashes() {
        var set = PerformedSet()
        set.efforts = []
        #expect(set.primary == Effort())
        set.primary = Effort(reps: 3)
        #expect(set.efforts == [Effort(reps: 3)])
    }

    // MARK: Medium: rest timer and policy survive termination

    @Test func restTimerAndPolicyPersistAcrossRelaunch() throws {
        let persistence = InMemoryTrainingPersistence()
        do {
            let (store, _, _) = try storeWithBench(persistence)
            var policy = RestPolicy()
            policy.isolation = 75
            try store.setRestPolicy(policy)
            try store.extendRest(by: 30)
        }
        let relaunched = try TrainingStore(persistence: persistence, now: { Fixture.instant(minutes: 1) })
        #expect(relaunched.restTimer == RestTimer(startedAt: Fixture.instant(), duration: 150 + 30))
        #expect(relaunched.restPolicy.isolation == 75)

        try relaunched.skipRest()
        let again = try TrainingStore(persistence: persistence)
        #expect(again.restTimer == nil)
        #expect(again.restPolicy.isolation == 75)
    }

    @Test func finishingClearsTheStoredTimer() throws {
        let persistence = InMemoryTrainingPersistence()
        let (store, _, _) = try storeWithBench(persistence)
        try store.finishSession()
        #expect(try TrainingStore(persistence: persistence).restTimer == nil)
    }

    @Test func anAccountsDatabaseCanBeRemoved() throws {
        let account = "4f9e1c3a-0000-4000-8000-\(String(UInt64.random(in: 0..<1_000_000_000_000), radix: 10))"
        let url = try SQLiteTrainingPersistence.defaultURL(accountID: account)
        do {
            let persistence = try SQLiteTrainingPersistence(url: url)
            try persistence.save(Fixture.session([("deadlift", [Fixture.set(3, 150)])]))
        }
        #expect(FileManager.default.fileExists(atPath: url.path))
        try SQLiteTrainingPersistence.deleteDatabase(accountID: account)
        #expect(!FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
        try SQLiteTrainingPersistence.deleteDatabase(accountID: account)
    }

    @Test func eachAccountHasItsOwnDatabase() throws {
        let a = try SQLiteTrainingPersistence.defaultURL(accountID: "4f9e1c3a-0000-4000-8000-000000000001")
        let b = try SQLiteTrainingPersistence.defaultURL(accountID: "4f9e1c3a-0000-4000-8000-000000000002")
        #expect(a != b)
        #expect(a.deletingLastPathComponent().lastPathComponent == "4f9e1c3a-0000-4000-8000-000000000001")
        #expect(throws: SQLiteTrainingPersistence.PersistenceError.self) {
            try SQLiteTrainingPersistence.defaultURL(accountID: "../escape")
        }
    }

    // MARK: Medium: statistics say when volume is incomplete

    @Test func statisticsReportIncompleteVolume() throws {
        let known = Fixture.session(days: 0, [("pull-up", [Fixture.set(8)])])
        let unknown = Fixture.session(days: 1, bodyweight: nil, [("pull-up", [Fixture.set(8)])])
        let complete = TrainingHistory(sessions: [known], library: Fixture.library)
        let partial = TrainingHistory(sessions: [known, unknown], library: Fixture.library)
        #expect(complete.statistics(of: "pull-up")?.isVolumeComplete == true)
        #expect(partial.statistics(of: "pull-up")?.isVolumeComplete == false)
    }

    // MARK: Request: a session summary and display conversion

    @Test func summarisesASessionWithoutUIArithmetic() throws {
        var session = Fixture.session([
            ("barbell-bench-press", [Fixture.set(5, 60, kind: .warmUp), Fixture.set(5, 100), Fixture.set(5, 100, done: false)]),
            ("pull-up", [Fixture.set(8)]),
        ])
        session.endedAt = nil
        let summary = WorkoutSummary(session: session, library: Fixture.library, at: Fixture.instant(minutes: 42))
        #expect(summary.exerciseCount == 2)
        #expect(summary.totalSets == 4)
        #expect(summary.completedSets == 3)
        #expect(summary.workingSets == 2)
        #expect(summary.duration == 42 * 60)
        #expect(summary.tonnage.resistance == 500)
        #expect(close(summary.tonnage.bodyweight, 8 * 76))
        #expect(summary.tonnage.isComplete)
        #expect(summary.muscles[.chest]?.sets == 1)
        #expect(summary.muscles[.lats]?.sets == 1)

        session.endedAt = Fixture.instant(minutes: 50)
        #expect(WorkoutSummary(session: session, library: Fixture.library, at: Fixture.instant(minutes: 90)).duration == 50 * 60)
    }

    @Test func convertsVolumeForDisplay() {
        let tonnage = Tonnage(resistance: 453.592_37, bodyweight: 0)
        #expect(close(tonnage.total(in: .pounds), 1000))
        #expect(tonnage.total(in: .kilograms) == 453.592_37)
        #expect(close(tonnage.resistance(in: .pounds), 1000))
        #expect(tonnage.bodyweight(in: .pounds) == 0)
    }
}
