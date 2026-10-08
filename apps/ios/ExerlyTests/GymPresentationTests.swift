import ExerlyCore
import XCTest
@testable import Exerly

@MainActor
final class GymPresentationTests: XCTestCase {
    func testWorkoutPreviewUsesTheActiveInventoryAndArchiveRestoresStandardIncrements() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = try TrainingWorkspace(accountID: UUID().uuidString, root: root)
        let sessions = [7, 8].enumerated().map { index, reps in
            let time = Date(timeIntervalSince1970: 1_791_223_200 + Double(index * 3 * 86_400))
            return WorkoutSession(name: "Synthetic press", startedAt: time, endedAt: time.addingTimeInterval(300),
                exercises: [PerformedExercise(exerciseID: "dumbbell-bench-press", sets: [
                    PerformedSet(efforts: [Effort(reps: reps, load: .kg(32.5))], rir: 2, completedAt: time)
                ])])
        }
        _ = try workspace.store.importSessions(sessions)
        let program = Program(name: "Press plan", days: [ProgramDay(name: "Press", slots: [
            ProgramSlot(exerciseID: "dumbbell-bench-press", target: SlotTarget(sets: 3, minReps: 6, maxReps: 8, rir: 2))
        ])], cycles: 2)
        try workspace.programs.save(program)
        try workspace.programs.activate(program.id)
        XCTAssertEqual(workspace.nextWorkout(bodyweight: nil)?.exercises.first?.recommendation.sets.first?.effort.load, .kg(32))
        let gym = GymProfile(name: "Real rack", equipment: [.dumbbell, .flatBench], loads: [.dumbbell: [.kg(30), .kg(32.5), .kg(35)]])
        try workspace.gyms.save(gym)
        try workspace.gyms.activate(gym.id)
        XCTAssertEqual(workspace.nextWorkout(bodyweight: nil)?.exercises.first?.recommendation.sets.first?.effort.load, .kg(32.5))
        try workspace.gyms.archive(gym.id)
        XCTAssertEqual(workspace.nextWorkout(bodyweight: nil)?.exercises.first?.recommendation.sets.first?.effort.load, .kg(32))
        XCTAssertNil(workspace.store.activeSession)
        await workspace.close()
    }

    func testNewGymsUseChosenUnitsAndSaveOfflineWithoutSwitchingTheCurrentGym() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let account = UUID().uuidString
        let workspace = try TrainingWorkspace(accountID: account, root: root)
        let original = GymProfile(name: "Current gym", bars: [.lb(45)])
        try workspace.gyms.save(original)
        try workspace.gyms.activate(original.id)
        let model = GymEditorModel(store: workspace.gyms, unit: .pounds)
        XCTAssertEqual(model.draft.bars, [.lb(45)])
        XCTAssertTrue(model.draft.plates.isEmpty)
        XCTAssertEqual(GymEditorModel(store: workspace.gyms, unit: .kilograms).draft.bars, [.kg(20)])
        model.draft.name = "Home"
        model.draft.equipment = [.bodyweight, .dumbbell]
        XCTAssertTrue(model.addWeight("22.5", unit: .pounds, to: .loads(.dumbbell)))
        XCTAssertTrue(model.addWeight("12", unit: .kilograms, to: .loads(.dumbbell)))
        XCTAssertTrue(model.save())
        XCTAssertEqual(workspace.gyms.active?.id, original.id)
        let saved = model.draft
        await workspace.close()
        let reopened = try TrainingWorkspace(accountID: account, root: root)
        XCTAssertEqual(reopened.gyms.gym(saved.id)?.loads[.dumbbell], [.lb(22.5), .kg(12)])
        let edit = GymEditorModel(store: reopened.gyms, unit: .kilograms, gym: saved)
        edit.draft.name = "Home weights"
        XCTAssertTrue(edit.save())
        XCTAssertEqual(reopened.gyms.gym(saved.id)?.bars, [.lb(45)])
        XCTAssertEqual(reopened.gyms.gym(saved.id)?.loads, saved.loads)
        await reopened.close()
    }

    func testInvalidAndDuplicateWeightsNeverReplaceTheInventory() throws {
        let store = try GymStore(persistence: InMemoryTrainingPersistence())
        let model = GymEditorModel(store: store, unit: .pounds)
        for text in ["", "-2", "NaN", "1x", "0", "100000"] {
            XCTAssertFalse(model.addWeight(text, unit: .pounds, to: .loads(.dumbbell)))
        }
        XCTAssertTrue(model.draft.loads.isEmpty)
        XCTAssertTrue(model.addWeight("2.5", unit: .pounds, to: .plates, pairs: 2))
        XCTAssertFalse(model.addWeight("2.5", unit: .pounds, to: .plates, pairs: 1))
        XCTAssertEqual(model.draft.plates, [PlateStock(.lb(2.5), pairs: 2)])
        XCTAssertFalse(model.save())
        XCTAssertTrue(store.gyms.isEmpty)
    }

    func testSyncChangeAndAccountChangeCannotBeOverwrittenByAnOldEditor() throws {
        let store = try GymStore(persistence: InMemoryTrainingPersistence())
        let gym = GymProfile(name: "Home", loads: [.dumbbell: [.lb(20)]])
        try store.save(gym)
        let edit = GymEditorModel(store: store, unit: .pounds, gym: gym)
        edit.draft.name = "My edit"
        var updated = gym
        updated.loads[.dumbbell] = [.lb(25)]
        try store.save(updated)
        XCTAssertFalse(edit.save())
        XCTAssertEqual(store.gym(gym.id), updated)
        XCTAssertEqual(edit.draft.name, "My edit")
        let signedOut = GymEditorModel(store: store, unit: .pounds, ownerIsActive: { false })
        signedOut.draft.name = "Other account"
        XCTAssertFalse(signedOut.save())
        XCTAssertEqual(store.gyms.count, 1)
    }
}
