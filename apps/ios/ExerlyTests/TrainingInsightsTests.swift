import XCTest
import ExerlyCore
@testable import Exerly

@MainActor
final class TrainingInsightsTests: XCTestCase {
    func testOfflineFinishFilesAReviewableCheckWithoutChangingTheWorkout() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = try TrainingWorkspace(accountID: UUID().uuidString, root: root)
        let saved = try finishMistypedWorkout(in: workspace.store)
        await workspace.synchronize()
        XCTAssertEqual(workspace.store.history.sessions, [saved])
        let proposal = try XCTUnwrap(workspace.agent.proposals.first)
        XCTAssertEqual(proposal.author, EntryErrorDetector.author)
        XCTAssertEqual(proposal.status, .pending)
        XCTAssertEqual(proposal.changes.first?.id, saved.id.uuidString)
        XCTAssertTrue(proposal.evidence.first?.claim.contains("other working sets") == true)
        await workspace.synchronize()
        XCTAssertEqual(workspace.agent.proposals.count, 1)
        await workspace.close()
    }

    func testFirstUseDoesNotSuggestCorrectionsForOldWorkouts() async throws {
        let persistence = InMemoryTrainingPersistence()
        let training = try TrainingStore(persistence: persistence)
        let agent = try AgentStore(persistence: persistence, hosts: [training])
        var saved = try finishMistypedWorkout(in: training)
        let start = Date().addingTimeInterval(-Double(EntryErrorDetector.recentDays + 2) * 86400)
        saved.startedAt = start
        saved.endedAt = start.addingTimeInterval(1800)
        for index in saved.exercises[0].sets.indices {
            saved.exercises[0].sets[index].completedAt = start.addingTimeInterval(60)
        }
        try training.saveSession(saved)
        let checks = TrainingEntryChecks(training: training, agent: agent, accountID: UUID().uuidString)
        await checks.refresh()
        XCTAssertTrue(agent.proposals.isEmpty)
        XCTAssertEqual(training.history.sessions, [saved])
        XCTAssertNil(checks.error)
    }

    func testRejectedEntryCheckStaysRejectedAfterOpeningTheAccountAgain() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let account = UUID().uuidString
        let first = try TrainingWorkspace(accountID: account, root: root)
        let saved = try finishMistypedWorkout(in: first.store)
        await first.synchronize()
        let proposal = try XCTUnwrap(first.agent.proposals.first)
        try first.agent.reject(proposal.id)
        await first.close()
        let restored = try TrainingWorkspace(accountID: account, root: root)
        await restored.synchronize()
        XCTAssertEqual(restored.store.history.sessions, [saved])
        XCTAssertEqual(restored.agent.proposals.count, 1)
        XCTAssertEqual(restored.agent.proposal(proposal.id)?.status, .rejected)
        await restored.close()
    }

    func testUndoneEntryCheckDoesNotReturnWhenOriginalTypoReturns() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let account = UUID().uuidString
        let first = try TrainingWorkspace(accountID: account, root: root)
        let saved = try finishMistypedWorkout(in: first.store)
        await first.synchronize()
        let proposal = try XCTUnwrap(first.agent.proposals.first)
        try first.agent.accept(proposal.id)
        XCTAssertNotEqual(first.store.history.sessions, [saved])
        try first.agent.undo(proposal.id)
        await first.close()
        let restored = try TrainingWorkspace(accountID: account, root: root)
        await restored.synchronize()
        XCTAssertEqual(restored.store.history.sessions, [saved])
        XCTAssertEqual(restored.agent.proposals.count, 1)
        XCTAssertEqual(restored.agent.proposal(proposal.id)?.status, .undone)
        await restored.close()
    }

    func testTurningChecksOffIsAccountSpecificAndNeverBlocksFinishing() async throws {
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let persistence = InMemoryTrainingPersistence()
        let training = try TrainingStore(persistence: persistence)
        let agent = try AgentStore(persistence: persistence, hosts: [training])
        let checks = TrainingEntryChecks(training: training, agent: agent, accountID: "first", defaults: defaults)
        checks.setEnabled(false)
        let saved = try finishMistypedWorkout(in: training)
        await checks.refresh()
        XCTAssertEqual(training.history.sessions, [saved])
        XCTAssertTrue(agent.proposals.isEmpty)
        let restored = TrainingEntryChecks(training: training, agent: agent, accountID: "first", defaults: defaults)
        XCTAssertFalse(restored.isEnabled)
        let other = TrainingEntryChecks(training: training, agent: agent, accountID: "second", defaults: defaults)
        XCTAssertTrue(other.isEnabled)
        other.setEnabled(false)
        restored.setEnabled(true)
        await restored.refresh()
        XCTAssertEqual(agent.proposals.count, 1)
        TrainingEntryChecks.removePreference(accountID: "first", defaults: defaults)
        XCTAssertFalse(TrainingEntryChecks(training: training, agent: agent, accountID: "second", defaults: defaults).isEnabled)
    }

    func testAnUncooperativeCheckCannotFileAfterAccountClose() async throws {
        let persistence = InMemoryTrainingPersistence()
        let training = try TrainingStore(persistence: persistence)
        let agent = try AgentStore(persistence: persistence, hosts: [training])
        let saved = try finishMistypedWorkout(in: training)
        let proposal = try XCTUnwrap(EntryErrorDetector.proposal(for: saved, history: training.history, existing: [], now: Date()))
        let started = expectation(description: "Detector started")
        let gate = EntryCheckGate(started: started)
        let checks = TrainingEntryChecks(training: training, agent: agent, accountID: UUID().uuidString,
                                        evaluate: { try await gate.evaluate($0, existing: $1, now: $2) })
        let task = Task { await checks.refresh() }
        await fulfillment(of: [started], timeout: 5)
        checks.stop()
        await gate.release([proposal])
        let filed = await task.value
        XCTAssertFalse(filed)
        XCTAssertFalse(checks.isChecking)
        XCTAssertTrue(agent.proposals.isEmpty)
        XCTAssertEqual(training.history.sessions, [saved])
    }

    func testAWorkoutEditedDuringAnalysisIsCheckedAgainBeforeFiling() async throws {
        let persistence = InMemoryTrainingPersistence()
        let training = try TrainingStore(persistence: persistence)
        let agent = try AgentStore(persistence: persistence, hosts: [training])
        let saved = try finishMistypedWorkout(in: training)
        let proposal = try XCTUnwrap(EntryErrorDetector.proposal(for: saved, history: training.history, existing: [], now: Date()))
        let started = expectation(description: "Detector started")
        let gate = EntryCheckGate(started: started)
        let checks = TrainingEntryChecks(training: training, agent: agent, accountID: UUID().uuidString,
                                        evaluate: { try await gate.evaluate($0, existing: $1, now: $2) })
        let task = Task { await checks.refresh() }
        await fulfillment(of: [started], timeout: 5)
        var corrected = saved
        corrected.exercises[0].sets[2].primary.load = .kg(100)
        try training.saveSession(corrected)
        await gate.release([proposal])
        let filed = await task.value
        XCTAssertFalse(filed)
        XCTAssertTrue(agent.proposals.isEmpty)
        XCTAssertEqual(training.history.sessions, [corrected])
        XCTAssertNil(checks.error)
    }

    func testFailedSuggestionWriteLeavesFinishedWorkoutRecoverable() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("training.sqlite")
        let persistence = try SQLiteTrainingPersistence(url: url)
        let training = try TrainingStore(persistence: persistence)
        let agent = try AgentStore(persistence: persistence, hosts: [training])
        let saved = try finishMistypedWorkout(in: training)
        let account = UUID().uuidString
        let checks = TrainingEntryChecks(training: training, agent: agent, accountID: account)
        persistence.close()
        await checks.refresh()
        XCTAssertNotNil(checks.error)
        XCTAssertFalse(checks.isChecking)
        XCTAssertTrue(agent.proposals.isEmpty)
        XCTAssertEqual(training.history.sessions, [saved])
        let recovered = try SQLiteTrainingPersistence(url: url)
        defer { recovered.close() }
        let restored = try TrainingStore(persistence: recovered)
        let restoredAgent = try AgentStore(persistence: recovered, hosts: [restored])
        let retried = TrainingEntryChecks(training: restored, agent: restoredAgent, accountID: account)
        await retried.refresh()
        XCTAssertNil(retried.error)
        XCTAssertEqual(restoredAgent.proposals.count, 1)
        XCTAssertEqual(restored.history.sessions, [saved])
    }

    func testOneInvalidSuggestionDoesNotBlockLaterChecksOrRepeatAutomatically() async throws {
        let persistence = InMemoryTrainingPersistence()
        let training = try TrainingStore(persistence: persistence)
        let agent = try AgentStore(persistence: persistence, hosts: [training])
        let saved = try finishMistypedWorkout(in: training)
        let valid = try XCTUnwrap(EntryErrorDetector.proposal(for: saved, history: training.history, existing: [], now: Date()))
        var invalid = valid
        invalid.id = UUID()
        invalid.changes[0].after = .object([:])
        let sequence = EntryCheckSequence([invalid, valid])
        let checks = TrainingEntryChecks(training: training, agent: agent, accountID: UUID().uuidString,
                                        evaluate: { _, _, _ in await sequence.next() })
        let filed = await checks.refresh()
        XCTAssertTrue(filed, "Later valid suggestions still need syncing.")
        XCTAssertEqual(agent.proposals.map(\.id), [valid.id])
        XCTAssertNotNil(checks.error)
        XCTAssertFalse(checks.isChecking)
        XCTAssertEqual(training.history.sessions, [saved])
        await checks.refresh()
        let attempts = await sequence.calls
        XCTAssertEqual(attempts, 1, "A background refresh must not loop on the same invalid proposal.")
        XCTAssertNotNil(checks.error, "Keep the retry explanation until the person acts.")
        await sequence.replace(with: [valid])
        await checks.retry()
        let retriedAttempts = await sequence.calls
        XCTAssertEqual(retriedAttempts, 2)
        XCTAssertNil(checks.error)
        XCTAssertEqual(agent.proposals.map(\.id), [valid.id])
    }

    func testObservationsUseTheAccountDateAndKeepSparseDataAndEvidenceHonest() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-01T01:00:00Z"))
        let zone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let base = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-01T12:00:00Z"))
        let sessions = (0..<6).map { observationSession(at: base.addingTimeInterval(Double($0 * 5 * 86400)), load: 100) }
        let history = TrainingHistory(sessions: sessions, library: .bundled)
        let model = TrainingObservationsModel()
        await model.refresh(history: history, now: now, timeZone: zone, unit: .pounds)
        XCTAssertEqual(model.through, LocalDate("2026-09-30"))
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.findings.count, 2)
        XCTAssertTrue(model.findings.allSatisfy { $0.kind == .stall })
        XCTAssertTrue(model.findings.flatMap(\.evidence).flatMap(\.caveats).contains { $0.contains("RIR not recorded") })
        let metrics = model.findings.flatMap(\.evidence).compactMap(\.metric)
        XCTAssertFalse(metrics.isEmpty)
        XCTAssertTrue(metrics.allSatisfy { MetricPresentation(metric: $0, history: history, unit: .pounds).status == .verified })
        await model.refresh(history: TrainingHistory(sessions: Array(sessions.prefix(2)), library: .bundled), now: now, timeZone: zone, unit: .pounds)
        XCTAssertTrue(model.findings.isEmpty)
    }

    func testDecliningLiftsProduceCoreDeloadEvidenceWithoutAProposal() async throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-01T12:00:00Z"))
        let sessions = [30, 24, 18, 13, 6, 2].map { days in
            observationSession(at: now.addingTimeInterval(Double(-days * 86400)), load: days < 10 ? 85 : 100)
        }
        let history = TrainingHistory(sessions: sessions, library: .bundled)
        let model = TrainingObservationsModel()
        await model.refresh(history: history, now: now, timeZone: TimeZone(secondsFromGMT: 0)!, unit: .pounds)
        let deload = try XCTUnwrap(model.findings.first { $0.kind == .deload })
        XCTAssertEqual(Set(deload.exerciseIDs), ["deadlift", "barbell-bench-press"])
        XCTAssertFalse(deload.evidence.isEmpty)
        XCTAssertEqual(history.sessions.count, 6)
    }

    private func observationSession(at date: Date, load: Double) -> WorkoutSession {
        WorkoutSession(name: "Synthetic strength", startedAt: date, endedAt: date.addingTimeInterval(1800),
                       timeZone: TimeZone(secondsFromGMT: 0)!, exercises: ["deadlift", "barbell-bench-press"].map { id in
            PerformedExercise(exerciseID: ExerciseID(id), sets: [PerformedSet(efforts: [Effort(reps: 5, load: .kg(load))],
                                                                             completedAt: date.addingTimeInterval(60))])
        })
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    private func finishMistypedWorkout(in store: TrainingStore) throws -> WorkoutSession {
        try store.startSession(name: "Synthetic pull", bodyweight: .kg(80))
        let exercise = try store.addExercise("deadlift")
        for (index, load) in [100.0, 100, 1000].enumerated() {
            if index > 0 { try store.addSet(to: exercise) }
            var set = try XCTUnwrap(store.activeSession?.exercises.first?.sets.last)
            set.primary = Effort(reps: 5, load: .kg(load))
            try store.updateSet(set, in: exercise)
            try store.completeSet(set.id)
        }
        return try store.finishSession().session
    }
}

private actor EntryCheckSequence {
    var proposals: [Proposal]
    private(set) var calls = 0
    init(_ proposals: [Proposal]) { self.proposals = proposals }
    func next() -> [Proposal] { calls += 1; return proposals }
    func replace(with proposals: [Proposal]) { self.proposals = proposals }
}

private actor EntryCheckGate {
    let started: XCTestExpectation
    private var waiting: CheckedContinuation<[Proposal], Never>?
    private var calls = 0

    init(started: XCTestExpectation) { self.started = started }

    func evaluate(_ history: TrainingHistory, existing: [Proposal], now: Date) async throws -> [Proposal] {
        calls += 1
        if calls == 1 {
            return await withCheckedContinuation { continuation in
                waiting = continuation
                started.fulfill()
            }
        }
        return try history.sessions.compactMap { try EntryErrorDetector.proposal(for: $0, history: history, existing: existing, now: now) }
    }

    func release(_ proposals: [Proposal]) { waiting?.resume(returning: proposals); waiting = nil }
}
