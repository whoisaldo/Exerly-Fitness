import Foundation
import Testing
@testable import ExerlyCore

/// Proposals that reach the phone by sync are checked as strictly as ones
/// filed on it, and a proposal's changes apply as one consistent unit.
/// The first two tests are the app agent's reproductions (to-logic.md).
@MainActor
@Suite struct ProposalValidationTests {
    typealias Workspace = ProposalTests.Workspace

    func finishedBench(_ workspace: Workspace) throws -> WorkoutSession {
        try workspace.training.startSession(name: "Push", bodyweight: .kg(80))
        let bench = try workspace.training.addExercise("barbell-bench-press")
        var set = workspace.training.activeSession!.exercises[0].sets[0]
        set.primary = Effort(reps: 8, load: .kg(40))
        try workspace.training.updateSet(set, in: bench)
        try workspace.training.completeSet(set.id)
        return try workspace.training.finishSession().session
    }

    func proposal(_ changes: [ProposedChange]) -> Proposal {
        Proposal(author: AgentIdentity(kind: .api, name: "Synthetic agent"), title: "Change", summary: "Synthetic",
                 changes: changes, evidence: [], confidence: .low, falsifier: "You disagree.")
    }

    /// Delivers a proposal the way sync does, skipping `file`.
    func receive(_ proposal: Proposal, into workspace: Workspace) throws {
        let publish = try workspace.agent.prepareWrite(kind: "proposal", id: proposal.id.uuidString,
                                                       payload: ExerlyJSON.canonical(proposal))
        publish()
    }

    func customExercise(_ name: String) -> Exercise {
        Exercise(id: .custom(), name: name, metric: .weightReps, mechanics: .compound, region: .upper,
                 muscles: [.chest: 1], equipment: [.barbell])
    }

    @Test func anInvalidSessionInASyncedProposalIsRefusedAtAccept() throws {
        let workspace = try Workspace()
        let original = try finishedBench(workspace)
        var invalid = original
        invalid.exercises[0].sets[0].primary.reps = -8
        let remote = proposal([try ProposedChange(kind: "workout_session", id: original.id.uuidString,
                                                  before: original, after: invalid)])
        try receive(remote, into: workspace)

        #expect(throws: AgentStore.AgentError.self) { try workspace.agent.accept(remote.id) }
        #expect(workspace.training.history.session(original.id) == original)
        #expect(workspace.persistence.sessions[original.id] == original)
        #expect(workspace.agent.proposal(remote.id)?.status == .pending)
    }

    @Test func acceptingTwoNewCustomExercisesKeepsBothInMemory() throws {
        let workspace = try Workspace()
        let first = customExercise("Synthetic first")
        let second = customExercise("Synthetic second")
        let batch = proposal([
            try ProposedChange(kind: "custom_exercise", id: first.id.rawValue, before: Exercise?.none, after: first),
            try ProposedChange(kind: "custom_exercise", id: second.id.rawValue, before: Exercise?.none, after: second),
        ])
        try workspace.agent.file(batch)
        try workspace.agent.accept(batch.id)
        #expect(workspace.training.library.exercise(first.id) == first)
        #expect(workspace.training.library.exercise(second.id) == second)
        let reloaded = try TrainingStore(persistence: workspace.persistence)
        #expect(reloaded.library.exercise(first.id) == first && reloaded.library.exercise(second.id) == second)
    }

    @Test func aSessionMayUseACustomExerciseCreatedInTheSameProposal() throws {
        let workspace = try Workspace()
        let exercise = customExercise("Synthetic floor press")
        let session = Fixture.session([(exercise.id, [Fixture.set(5, 60)])])
        let batch = proposal([
            try ProposedChange(kind: "custom_exercise", id: exercise.id.rawValue, before: Exercise?.none, after: exercise),
            try ProposedChange(kind: "workout_session", id: session.id.uuidString, before: WorkoutSession?.none, after: session),
        ])
        try receive(batch, into: workspace)
        try workspace.agent.accept(batch.id)
        #expect(workspace.training.history.session(session.id) == session)
        #expect(workspace.training.history.statistics(of: exercise.id)?.totalVolume == 300)
    }

    @Test func aSessionUsingAnUnknownExerciseIsRefused() throws {
        let workspace = try Workspace()
        let session = Fixture.session([(ExerciseID("custom-never-created"), [Fixture.set(5, 60)])])
        let batch = proposal([try ProposedChange(kind: "workout_session", id: session.id.uuidString,
                                                 before: WorkoutSession?.none, after: session)])
        try receive(batch, into: workspace)
        #expect(throws: AgentStore.AgentError.self) { try workspace.agent.accept(batch.id) }
        #expect(workspace.training.history.sessions.isEmpty)
    }

    @Test func duplicateAndUnsupportedTargetsAreRefusedWithoutPartialWrites() throws {
        let workspace = try Workspace()
        let original = try finishedBench(workspace)
        var renamed = original
        renamed.name = "Renamed"
        var twice = renamed
        twice.notes = "Twice"
        let duplicate = proposal([
            try ProposedChange(kind: "workout_session", id: original.id.uuidString, before: original, after: renamed),
            try ProposedChange(kind: "workout_session", id: original.id.uuidString, before: original, after: twice),
        ])
        try receive(duplicate, into: workspace)
        #expect(throws: AgentStore.AgentError.self) { try workspace.agent.accept(duplicate.id) }

        let unsupported = proposal([
            try ProposedChange(kind: "workout_session", id: original.id.uuidString, before: original, after: renamed),
            ProposedChange(kind: "audit_event", id: UUID().uuidString, before: nil, after: .object([:])),
        ])
        try receive(unsupported, into: workspace)
        #expect(throws: AgentStore.AgentError.self) { try workspace.agent.accept(unsupported.id) }

        let exercise = customExercise("Synthetic removal")
        try workspace.training.addCustomExercise(exercise)
        let removal = proposal([try ProposedChange(kind: "custom_exercise", id: exercise.id.rawValue,
                                                   before: exercise, after: Exercise?.none)])
        try receive(removal, into: workspace)
        #expect(throws: AgentStore.AgentError.self) { try workspace.agent.accept(removal.id) }

        #expect(workspace.training.history.session(original.id) == original)
        #expect(workspace.training.library.exercise(exercise.id) == exercise)
    }

    @Test func undoOfANewCustomExerciseIsRefusedBecauseExercisesAreNeverRemoved() throws {
        let workspace = try Workspace()
        let exercise = customExercise("Synthetic kept")
        let created = proposal([try ProposedChange(kind: "custom_exercise", id: exercise.id.rawValue,
                                                   before: Exercise?.none, after: exercise)])
        try workspace.agent.file(created)
        try workspace.agent.accept(created.id)
        #expect(throws: AgentStore.AgentError.self) { try workspace.agent.undo(created.id) }
        #expect(workspace.agent.proposal(created.id)?.status == .accepted)
        #expect(workspace.training.library.exercise(exercise.id) == exercise)
    }
}
