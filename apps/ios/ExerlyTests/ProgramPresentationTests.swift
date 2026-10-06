import ExerlyCore
import XCTest
@testable import Exerly

@MainActor
final class ProgramPresentationTests: XCTestCase {
    func testAccountExportIncludesProgramsSavedOnThisDevice() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let account = UUID().uuidString
        let first = try TrainingWorkspace(accountID: account, root: root)
        let source = try SQLiteTrainingPersistence(url: first.url)
        let programs = try ProgramStore(persistence: source, training: first.store)
        let program = sampleProgram()
        try programs.save(program)
        source.close()
        await first.close()
        let reopened = try TrainingWorkspace(accountID: account, root: root)
        let exported = try XCTUnwrap(JSONSerialization.jsonObject(with: reopened.export(server: nil)) as? [String: Any])
        let documents = try XCTUnwrap(exported["documents"] as? [[String: Any]])
        let row = try XCTUnwrap(documents.first { $0["kind"] as? String == "program" })
        XCTAssertEqual(row["document_id"] as? String, program.id.uuidString)
        XCTAssertEqual(row["pending_sync"] as? Bool, true)
        XCTAssertEqual((row["payload"] as? [String: Any])?["name"] as? String, "Synthetic strength")
        await reopened.close()
    }

    func testProgramCreationProposalIsSupportedAndCanBeAcceptedAndUndone() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = try TrainingWorkspace(accountID: UUID().uuidString, root: root)
        let program = sampleProgram()
        let proposal = try Proposal(author: AgentIdentity(kind: .mcp, name: "Synthetic program coach"),
            title: "Review a training program", summary: "An editable training plan.",
            changes: [ProposedChange(kind: "program", id: program.id.uuidString, before: Optional<Program>.none, after: program)],
            evidence: [], confidence: .low, falsifier: "The program does not fit your preferences.")
        XCTAssertTrue(workspace.supportsChanges(in: proposal))
        try workspace.agent.file(proposal)
        try workspace.agent.accept(proposal.id)
        XCTAssertEqual(workspace.agent.proposal(proposal.id)?.status, .accepted)
        try workspace.agent.undo(proposal.id)
        XCTAssertEqual(workspace.agent.proposal(proposal.id)?.status, .undone)
        await workspace.close()
    }

    func testInvalidProgramKeepsTheDraftAndDoesNotWritePartialData() throws {
        let persistence = InMemoryTrainingPersistence()
        let training = try TrainingStore(persistence: persistence)
        let programs = try ProgramStore(persistence: persistence, training: training)
        let draft = TrainingProgramDraft(store: programs)
        draft.program.name = "Keep this draft"
        draft.cycles = "2"
        XCTAssertFalse(draft.save())
        XCTAssertEqual(draft.program.name, "Keep this draft")
        XCTAssertTrue(draft.errors.contains { $0.contains("training day") })
        XCTAssertTrue(programs.programs.isEmpty)
        draft.program.days = sampleProgram().days
        XCTAssertTrue(draft.save())
        XCTAssertFalse(draft.hasChanges)
        XCTAssertEqual(programs.programs.first?.cycles, 2)
        XCTAssertEqual(programs.programs.first?.name, "Keep this draft")
    }

    func testDraftRefusesToOverwriteAProgramChangedWhileEditing() throws {
        let persistence = InMemoryTrainingPersistence()
        let training = try TrainingStore(persistence: persistence)
        let programs = try ProgramStore(persistence: persistence, training: training)
        let original = sampleProgram()
        try programs.save(original)
        let draft = TrainingProgramDraft(store: programs, editing: original)
        draft.program.name = "Unsaved phone name"
        var newer = original
        newer.name = "Updated from another device"
        try programs.save(newer)
        XCTAssertFalse(draft.save())
        XCTAssertTrue(draft.errors.contains { $0.contains("changed while") })
        XCTAssertEqual(draft.program.name, "Unsaved phone name")
        XCTAssertEqual(programs.program(original.id), newer)
    }

    func testTargetEditingKeepsExactUnchangedNumbersAndRejectsMalformedInput() throws {
        let original = SlotTarget(sets: 3, minReps: 6, maxReps: 10, rir: 1.23456789, rest: 91.123456789)
        var fields = ProgramTargetFields(original)
        fields.sets = "4"
        let updated = try fields.value()
        XCTAssertEqual(updated.rir, original.rir)
        XCTAssertEqual(updated.rest, original.rest)
        XCTAssertEqual(updated.sets, 4)
        fields.rir = "2,5"
        XCTAssertEqual(try fields.value(locale: Locale(identifier: "fr_FR")).rir, 2.5)
        fields.rest = "91seconds"
        XCTAssertThrowsError(try fields.value(locale: Locale(identifier: "fr_FR")))
    }

    func testPlannedWorkoutAdvancesOnlyWhenFinishedAndSurvivesAccountReopen() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let account = UUID().uuidString
        let workspace = try TrainingWorkspace(accountID: account, root: root)
        let program = sampleProgram()
        try workspace.programs.save(program)
        try workspace.programs.activate(program.id)
        let plan = try XCTUnwrap(workspace.programs.nextWorkout(bodyweight: nil))
        XCTAssertEqual(plan.program?.dayID, program.days[0].id)
        let started = try workspace.store.startSession(from: plan, bodyweight: nil)
        XCTAssertFalse(started.exercises.flatMap(\.sets).contains(where: \.isCompleted))
        var set = try XCTUnwrap(started.exercises.first?.sets.first)
        set.primary = Effort(reps: 6, load: .kg(100))
        try workspace.store.updateSet(set, in: started.exercises[0].id)
        try workspace.store.completeSet(set.id)
        XCTAssertEqual(workspace.programs.nextWorkout(bodyweight: nil)?.program, plan.program)
        try workspace.store.finishSession()
        XCTAssertEqual(workspace.programs.nextWorkout(bodyweight: nil)?.program?.dayID, program.days[2].id)
        await workspace.close()
        XCTAssertThrowsError(try workspace.programs.save(program))
        let restored = try TrainingWorkspace(accountID: account, root: root)
        XCTAssertEqual(restored.programs.active?.id, program.id)
        XCTAssertEqual(restored.programs.nextWorkout(bodyweight: nil)?.program?.dayID, program.days[2].id)
        let other = try TrainingWorkspace(accountID: UUID().uuidString, root: root)
        XCTAssertTrue(other.programs.programs.isEmpty)
        await restored.close()
        await other.close()
    }

    private func sampleProgram() -> Program {
        Program(name: "Synthetic strength", days: [
            ProgramDay(name: "Pull", slots: [ProgramSlot(exerciseID: "deadlift", target: SlotTarget(sets: 3, minReps: 5, maxReps: 8, rir: 2))]),
            ProgramDay(name: "Rest"),
            ProgramDay(name: "Push", slots: [ProgramSlot(exerciseID: "barbell-bench-press", target: SlotTarget(sets: 3, minReps: 6, maxReps: 10, rir: 2))])
        ], cycles: 2, deload: .last)
    }
}
