import Foundation
import Testing
@testable import ExerlyCore

@Suite struct JSONValueTests {
    @Test func roundTripsAnyJSONCanonically() throws {
        let text = #"{"b":[1,2.5,true,null,"x"],"a":{"z":-3e-7,"y":"é"}}"#
        let value = try ExerlyJSON.decoder.decode(JSONValue.self, from: Data(text.utf8))
        let canonical = try ExerlyJSON.canonical(value)
        #expect(String(bytes: canonical, encoding: .utf8) == #"{"a":{"y":"é","z":-3e-07},"b":[1,2.5,true,null,"x"]}"#)
        #expect(try ExerlyJSON.decoder.decode(JSONValue.self, from: canonical) == value)
    }

    @Test func convertsToAndFromTypedValues() throws {
        let session = Fixture.session([("deadlift", [Fixture.set(3, 150)])])
        let value = try JSONValue(encoding: session)
        #expect(try value.decode(WorkoutSession.self) == session)
        #expect(try ExerlyJSON.canonical(value) == ExerlyJSON.canonical(session))
    }

    @Test func diffsListFieldPathsWithOldAndNewValues() throws {
        var before = Fixture.session([("deadlift", [Fixture.set(3, 150)])])
        before.notes = "old"
        var after = before
        after.notes = "new"
        after.exercises[0].sets[0].primary.load = .kg(15)
        let changes = JSONValue.diff(try JSONValue(encoding: before), try JSONValue(encoding: after))
        #expect(changes.map(\.path) == ["exercises[0].sets[0].efforts[0].load.value", "notes"])
        #expect(changes.first?.before == .number(150))
        #expect(changes.first?.after == .number(15))
        #expect(JSONValue.diff(nil, .string("x")).map(\.path) == [""])
    }
}

@MainActor
@Suite struct ProposalTests {
    @MainActor
    struct Workspace {
        let persistence: InMemoryTrainingPersistence
        let training: TrainingStore
        let agent: AgentStore

        init() throws {
            let persistence = InMemoryTrainingPersistence()
            self.persistence = persistence
            training = try TrainingStore(persistence: persistence, now: { Fixture.instant() })
            agent = try AgentStore(persistence: persistence, hosts: [training], now: { Fixture.instant(minutes: 30) })
        }
    }

    /// A finished session with a 1500 kg deadlift typo, and a proposal to fix it.
    func typoWorkspace() throws -> (Workspace, Proposal) {
        let workspace = try Workspace()
        try workspace.training.startSession(name: "Pull", bodyweight: .kg(80))
        let deadlift = try workspace.training.addExercise("deadlift")
        var set = workspace.training.activeSession!.exercises[0].sets[0]
        set.primary = Effort(reps: 3, load: .kg(1500))
        try workspace.training.updateSet(set, in: deadlift)
        try workspace.training.completeSet(set.id)
        let session = try workspace.training.finishSession().session
        var fixed = session
        fixed.exercises[0].sets[0].primary.load = .kg(150)
        let proposal = try Proposal(
            author: AgentIdentity(kind: .builtIn, name: "Exerly"),
            title: "Did you mean 150 kg?",
            summary: "1500 kg is ten times every other deadlift you've logged.",
            changes: [ProposedChange(kind: "workout_session", id: session.id.uuidString, before: session, after: fixed)],
            evidence: [Evidence(claim: "Your heaviest earlier deadlift is far lower.", level: .personalData,
                                caveats: ["n=1"], dataRefs: [DataRef(kind: "workout_session", id: session.id.uuidString)])],
            confidence: .high,
            falsifier: "You really lifted 1500 kg."
        )
        return (workspace, proposal)
    }

    @Test func filingAProposalChangesNothingAndIsAudited() throws {
        let (workspace, proposal) = try typoWorkspace()
        let before = workspace.training.history.sessions
        try workspace.agent.file(proposal)
        #expect(workspace.training.history.sessions == before)
        #expect(workspace.agent.proposals.map(\.status) == [.pending])
        #expect(workspace.agent.auditLog.map(\.action) == [.proposalFiled])
        #expect(workspace.agent.auditLog[0].proposalID == proposal.id)
    }

    @Test func acceptingAppliesTheChangeAndUndoRestoresIt() throws {
        let (workspace, proposal) = try typoWorkspace()
        let original = workspace.training.history.sessions[0]
        try workspace.agent.file(proposal)
        try workspace.agent.accept(proposal.id)
        #expect(workspace.training.history.sessions[0].exercises[0].sets[0].primary.load == .kg(150))
        #expect(workspace.persistence.sessions[original.id]?.exercises[0].sets[0].primary.load == .kg(150))
        #expect(workspace.agent.proposal(proposal.id)?.status == .accepted)
        #expect(workspace.agent.proposal(proposal.id)?.decidedAt == Fixture.instant(minutes: 30))

        try workspace.agent.undo(proposal.id)
        #expect(workspace.training.history.sessions[0] == original)
        #expect(workspace.agent.proposal(proposal.id)?.status == .undone)
        #expect(workspace.agent.auditLog.map(\.action) == [.proposalFiled, .proposalAccepted, .proposalUndone])
    }

    @Test func aChangedTargetMakesTheProposalStaleAndNothingIsApplied() throws {
        let (workspace, proposal) = try typoWorkspace()
        try workspace.agent.file(proposal)
        var edited = workspace.training.history.sessions[0]
        edited.notes = "Edited by hand"
        try workspace.training.saveSession(edited)

        #expect(throws: AgentStore.AgentError.stale) { try workspace.agent.accept(proposal.id) }
        #expect(workspace.agent.proposal(proposal.id)?.status == .stale)
        #expect(workspace.training.history.sessions[0] == edited)
        #expect(workspace.agent.auditLog.last?.action == .proposalStale)
    }

    @Test func undoIsRefusedOnceTheDataMovedOn() throws {
        let (workspace, proposal) = try typoWorkspace()
        try workspace.agent.file(proposal)
        try workspace.agent.accept(proposal.id)
        var later = workspace.training.history.sessions[0]
        later.notes = "Later edit"
        try workspace.training.saveSession(later)
        #expect(throws: AgentStore.AgentError.stale) { try workspace.agent.undo(proposal.id) }
        #expect(workspace.training.history.sessions[0] == later)
        #expect(workspace.agent.proposal(proposal.id)?.status == .accepted)
    }

    @Test func rejectingIsRecordedAndDecisionsAreFinal() throws {
        let (workspace, proposal) = try typoWorkspace()
        try workspace.agent.file(proposal)
        try workspace.agent.reject(proposal.id)
        #expect(workspace.agent.proposal(proposal.id)?.status == .rejected)
        #expect(throws: AgentStore.AgentError.alreadyDecided) { try workspace.agent.accept(proposal.id) }
        #expect(throws: AgentStore.AgentError.notAccepted) { try workspace.agent.undo(proposal.id) }
        #expect(throws: AgentStore.AgentError.duplicate) { try workspace.agent.file(proposal) }
    }

    @Test func proposalsMustBeComplete() throws {
        let (workspace, proposal) = try typoWorkspace()
        var noFalsifier = proposal
        noFalsifier.id = UUID()
        noFalsifier.falsifier = " "
        #expect(throws: AgentStore.AgentError.self) { try workspace.agent.file(noFalsifier) }
        var noChanges = proposal
        noChanges.id = UUID()
        noChanges.changes = []
        #expect(throws: AgentStore.AgentError.self) { try workspace.agent.file(noChanges) }
        var unknownKind = proposal
        unknownKind.id = UUID()
        unknownKind.changes[0].kind = "nutrition_target"
        #expect(throws: AgentStore.AgentError.self) { try workspace.agent.file(unknownKind) }
        var invalidAfter = proposal
        invalidAfter.id = UUID()
        invalidAfter.changes[0].after = .object(["id": .string("nope")])
        #expect(throws: AgentStore.AgentError.self) { try workspace.agent.file(invalidAfter) }
    }

    @Test func aFailureMidAcceptLeavesEverythingAsItWas() throws {
        let (workspace, proposal) = try typoWorkspace()
        let original = workspace.training.history.sessions[0]
        var twoChanges = proposal
        // The second change targets a session that doesn't exist: it can't apply.
        var phantom = original
        phantom.id = UUID()
        twoChanges.changes.append(ProposedChange(kind: "workout_session", id: phantom.id.uuidString,
                                                 before: try JSONValue(encoding: phantom), after: try JSONValue(encoding: phantom)))
        try workspace.agent.file(twoChanges)
        #expect(throws: AgentStore.AgentError.stale) { try workspace.agent.accept(twoChanges.id) }
        #expect(workspace.training.history.sessions == [original])
        #expect(workspace.persistence.sessions[original.id] == original)
    }

    @Test func diffsAreComputedForTheUI() throws {
        let (workspace, proposal) = try typoWorkspace()
        try workspace.agent.file(proposal)
        let diff = workspace.agent.diff(proposal.id)
        #expect(diff.count == 1)
        #expect(diff[0].fields.map(\.path) == ["exercises[0].sets[0].efforts[0].load.value"])
    }

    @Test func proposalsAndTheAuditLogSurviveRelaunch() throws {
        let (workspace, proposal) = try typoWorkspace()
        try workspace.agent.file(proposal)
        try workspace.agent.accept(proposal.id)
        let training = try TrainingStore(persistence: workspace.persistence)
        let agent = try AgentStore(persistence: workspace.persistence, hosts: [training])
        #expect(agent.proposal(proposal.id)?.status == .accepted)
        #expect(agent.auditLog.count == 2)
    }
}

@Suite struct MetricVerificationTests {
    let history = TrainingHistory(sessions: [
        Fixture.session(days: 0, [("back-squat", [Fixture.set(5, 100, rir: 2)])]),
        Fixture.session(days: 7, [("back-squat", [Fixture.set(3, 110, rir: 2)])]),
    ], library: Fixture.library)

    @Test func confirmsAClaimTheCodeAgreesWith() {
        let metric = MetricReference.bestOneRepMax(exercise: "back-squat", from: LocalDate("2026-10-01")!,
                                                   through: LocalDate("2026-10-31")!, claimedKilograms: 123.75)
        #expect(metric.verify(against: history) == .verified(actual: 123.75))
    }

    @Test func flagsAnInventedNumber() {
        let metric = MetricReference.bestOneRepMax(exercise: "back-squat", from: LocalDate("2026-10-01")!,
                                                   through: LocalDate("2026-10-31")!, claimedKilograms: 140)
        #expect(metric.verify(against: history) == .mismatch(actual: 123.75))
    }

    @Test func weeklySetsAndTotalVolumeAreCheckable() {
        let sets = MetricReference.weeklySets(muscle: .quads, weekStarting: LocalDate("2026-10-05")!, firstWeekday: .monday, claimed: 1)
        #expect(sets.verify(against: history) == .verified(actual: 1))
        let volume = MetricReference.totalVolume(exercise: "back-squat", from: LocalDate("2026-10-01")!,
                                                 through: LocalDate("2026-10-31")!, claimedKilogramReps: 830)
        #expect(volume.verify(against: history) == .verified(actual: 830))
    }

    @Test func unknownMetricsAreUnverifiable() {
        let metric = MetricReference(name: "sleep.hours.mean", parameters: [:], claimed: 7)
        #expect(metric.verify(against: history) == .unverifiable)
    }
}
