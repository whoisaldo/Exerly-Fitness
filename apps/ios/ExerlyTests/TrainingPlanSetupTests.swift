import ExerlyCore
import XCTest
@testable import Exerly

@MainActor
final class TrainingPlanSetupTests: XCTestCase {
    func testSavedPreferencesSeedRealEquipmentWithoutInventingSupportOrClampingDays() {
        var answers = TrainingPlanAnswers()
        let snapshot = PreferencesSnapshot(schemaVersion: 1, accountID: "a", revision: 2, values: [
            "experienceLevel": .string("intermediate"), "workoutDaysPerWeek": .number(4),
            "equipmentAccess": .string("home"), "equipment": .array([.string("dumbbells"), .string("bench"), .string("barbell")])],
            user: UserDTO(id: "a", email: "synthetic@exerly.test"))
        answers.apply(snapshot)
        XCTAssertEqual(answers.days, 4)
        XCTAssertEqual(answers.experience, .intermediate)
        XCTAssertEqual(answers.equipment, [.bodyweight, .dumbbell, .flatBench, .barbell])
        XCTAssertFalse(answers.gym(unit: .pounds, active: nil).equipment.contains(.rack))
        XCTAssertEqual(answers.gym(unit: .pounds, active: nil).bars, [.lb(45)])
        XCTAssertEqual(answers.gym(unit: .kilograms, active: nil).bars, [.kg(20)])
        for days in [0, 1, 7] {
            var unsupported = snapshot
            unsupported.values["workoutDaysPerWeek"] = .number(Double(days))
            answers.apply(unsupported)
            XCTAssertNil(answers.days)
            XCTAssertEqual(answers.savedDaysOutsideBuilder, days)
            XCTAssertFalse(answers.request.problems.isEmpty)
        }
    }

    func testPreviewSavesNothingAndAcceptanceUsesExactlyTheReviewedProgramOnce() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let account = UUID().uuidString
        let workspace = try TrainingWorkspace(accountID: account, root: root)
        let existing = Program(name: "Existing plan", days: [ProgramDay(name: "Pull", slots: [
            ProgramSlot(exerciseID: "deadlift", target: SlotTarget(sets: 2, minReps: 5, maxReps: 8, rir: 2))
        ])], cycles: 2)
        try workspace.programs.save(existing)
        try workspace.programs.activate(existing.id)
        let active = workspace.programs.active
        let model = TrainingPlanSetupModel(workspace: workspace, unit: .pounds)
        model.answers.equipment = [.bodyweight, .dumbbell, .flatBench]
        model.answers.minutes = 45
        model.prepare()
        let candidate = try XCTUnwrap(model.candidate)
        XCTAssertEqual(workspace.programs.programs.count, 1)
        XCTAssertTrue(workspace.agent.proposals.isEmpty)
        let gym = model.answers.gym(unit: .pounds, active: nil)
        for slot in candidate.program.trainingDays.flatMap(\.slots) {
            XCTAssertTrue(gym.allows(try XCTUnwrap(workspace.store.library.exercise(slot.exerciseID))))
        }
        model.accept(); model.accept()
        XCTAssertTrue(model.accepted)
        XCTAssertEqual(workspace.programs.program(candidate.program.id), candidate.program)
        XCTAssertEqual(workspace.programs.active, active)
        XCTAssertEqual(workspace.agent.proposals.count, 1)
        await workspace.close()
        let reopened = try TrainingWorkspace(accountID: account, root: root)
        XCTAssertEqual(reopened.programs.program(candidate.program.id), candidate.program)
        try reopened.agent.undo(candidate.proposal.id)
        XCTAssertNil(reopened.programs.program(candidate.program.id))
        XCTAssertEqual(reopened.programs.active, active)
        await reopened.close()
    }

    func testUnavailableStorageKeepsThePreviewAndAccountChangeCannotSave() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = try TrainingWorkspace(accountID: UUID().uuidString, root: root)
        var owned = true
        let model = TrainingPlanSetupModel(workspace: workspace, unit: .pounds, ownerIsActive: { owned })
        model.prepare()
        let id = try XCTUnwrap(model.candidate?.proposal.id)
        owned = false
        model.accept()
        XCTAssertTrue(workspace.agent.proposals.isEmpty)
        owned = true
        await workspace.close()
        model.accept()
        XCTAssertFalse(model.accepted)
        XCTAssertNotNil(model.error)
        XCTAssertEqual(model.candidate?.proposal.id, id)
        XCTAssertTrue(workspace.agent.proposals.isEmpty)
    }

    func testGymProfilesRemainInAccountExportsAndReopenWithExactUSLoads() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let account = UUID().uuidString
        let workspace = try TrainingWorkspace(accountID: account, root: root)
        let gym = GymProfile(name: "Synthetic home", equipment: [.barbell, .rack], bars: [.lb(45)], plates: PlateStock.standardPounds)
        try workspace.gyms.save(gym)
        try workspace.gyms.activate(gym.id)
        let offlineBuilder = TrainingPlanSetupModel(workspace: workspace, unit: .pounds)
        XCTAssertEqual(offlineBuilder.answers.equipment, [.bodyweight, .barbell, .rack],
                       "The local gym must be available before any preferences request")
        XCTAssertEqual(offlineBuilder.answers.gym(unit: .pounds, active: gym).bars, [.lb(45)])
        let defaultsName = "exerly.plan-gym.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        let credentials = MemoryCredentials()
        credentials.saveSession(token: SessionBridgeTests.token(account), refreshToken: "fixture-refresh")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let api = APIClient(baseURL: "https://fixture.exerly.test", session: URLSession(configuration: configuration),
                            keychain: credentials, defaults: defaults)
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
            StubURLProtocol.handler = nil
        }
        let snapshot = PreferencesSnapshot(schemaVersion: 1, accountID: account, revision: 1,
            values: ["experienceLevel": .string("advanced"), "workoutDaysPerWeek": .number(5),
                     "equipmentAccess": .string("full_gym")], user: UserDTO(id: account, email: "synthetic@exerly.test"))
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET", "Reading setup must not resend a profile edit")
            return (200, try JSONEncoder().encode(snapshot))
        }
        await offlineBuilder.loadPreferences(PreferencesStore(accountID: account, api: api, defaults: defaults, ownerIsActive: { true }))
        XCTAssertEqual(offlineBuilder.answers.days, 5)
        XCTAssertEqual(offlineBuilder.answers.experience, .advanced)
        XCTAssertEqual(offlineBuilder.answers.equipment, [.bodyweight, .barbell, .rack],
                       "The local gym supplies equipment while saved setup supplies the training answers")
        let data = try workspace.export(server: nil)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let documents = try XCTUnwrap(json["documents"] as? [[String: Any]])
        XCTAssertEqual(documents.filter { $0["kind"] as? String == "gym_profile" }.count, 1)
        await workspace.close()
        let reopened = try TrainingWorkspace(accountID: account, root: root)
        XCTAssertEqual(reopened.gyms.active?.bars, [.lb(45)])
        XCTAssertEqual(reopened.gyms.active?.plates, PlateStock.standardPounds)
        await reopened.close()
    }
}
