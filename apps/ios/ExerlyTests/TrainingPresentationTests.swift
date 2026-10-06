import XCTest
import ExerlyCore
@testable import Exerly

@MainActor
final class TrainingPresentationTests: XCTestCase {
    func testAccountsCannotSeeEachOthersUnfinishedWorkAndRelaunchRestoresIt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let alice = try TrainingWorkspace(accountID: "alice", root: root)
        let session = try alice.store.startSession(name: "Upper", bodyweight: .kg(70))
        let exercise = try alice.store.addExercise("barbell-bench-press")
        var set = try XCTUnwrap(alice.store.activeSession?.exercises.first?.sets.first)
        set.primary = Effort(reps: 6, load: .kg(40))
        try alice.store.updateSet(set, in: exercise)
        try alice.store.completeSet(set.id)

        let bob = try TrainingWorkspace(accountID: "bob", root: root)
        XCTAssertNil(bob.store.activeSession)
        XCTAssertTrue(bob.store.history.sessions.isEmpty)
        let restored = try TrainingWorkspace(accountID: "alice", root: root)
        XCTAssertEqual(restored.store.activeSession?.id, session.id)
        XCTAssertEqual(restored.store.activeSession?.set(set.id)?.set.primary.load, .kg(40))
        XCTAssertTrue(try XCTUnwrap(restored.store.activeSession?.set(set.id)?.set.isCompleted))
        XCTAssertEqual(restored.store.restTimer?.endsAt, alice.store.restTimer?.endsAt)
        XCTAssertNotNil(restored.store.restTimer)
        try restored.store.skipRest()
        let skipped = try TrainingWorkspace(accountID: "alice", root: root)
        XCTAssertNil(skipped.store.restTimer)
        XCTAssertTrue(restored.url.path.hasPrefix(root.path + "/"))
        XCTAssertNotEqual(restored.url, bob.url)
    }

    func testMissingAccountAndUnreadableStorageDoNotCreateTemporaryWorkspaces() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try TrainingWorkspace(accountID: "", root: root))
        XCTAssertThrowsError(try TrainingWorkspace(accountID: "alice/../shared", root: root))
        try Data("not a directory".utf8).write(to: root)
        XCTAssertThrowsError(try TrainingWorkspace(accountID: "alice", root: root))
    }

    func testNormalWorkspaceUsesTheCoreAccountLifecyclePath() throws {
        let accountID = UUID().uuidString
        let expected = try SQLiteTrainingPersistence.defaultURL(accountID: accountID)
        defer { try? FileManager.default.removeItem(at: expected.deletingLastPathComponent()) }
        let workspace = try TrainingWorkspace(accountID: accountID)
        XCTAssertEqual(workspace.url, expected)
    }

    func testNumericInputHonorsDecimalSeparatorAndRejectsPartialOrNonFiniteValues() {
        let french = Locale(identifier: "fr_FR")
        let english = Locale(identifier: "en_US")
        XCTAssertEqual(TrainingInput.number("42,5", locale: french), 42.5)
        XCTAssertEqual(TrainingInput.number(" 42.5 ", locale: english), 42.5)
        for invalid in ["42kg", "NaN", "inf", "1e309", "-1", "1.2.3", ""] {
            XCTAssertNil(TrainingInput.number(invalid, locale: english), invalid)
        }
        XCTAssertNil(TrainingInput.number("42,5", locale: english))
        XCTAssertEqual(TrainingInput.reps("12"), 12)
        XCTAssertNil(TrainingInput.reps("12.5"))
        XCTAssertNil(TrainingInput.reps("-3"))
    }

    func testSetDescriptionKeepsEnteredUnitAndEveryContinuation() {
        let set = PerformedSet(kind: .drop, efforts: [
            Effort(reps: 8, load: .lb(45)), Effort(reps: 5, load: .lb(25))
        ], rir: 1)
        let text = TrainingFormat.set(set, unit: .pounds)
        XCTAssertTrue(text.contains("45 lb"), text)
        XCTAssertTrue(text.contains("25 lb"), text)
        XCTAssertTrue(text.contains("8 reps"), text)
        XCTAssertTrue(text.contains("5 reps"), text)
    }

    func testEditingRepsInDifferentUnitsDoesNotRoundOrConvertTheSavedLoad() throws {
        let original = Effort(reps: 8, load: .kg(100.123456789))
        var draft = EffortFields(original, unit: .pounds)
        draft.reps = "9"
        let result = try draft.value(for: .weightReps, unit: .pounds)
        XCTAssertEqual(result.load, original.load)
        XCTAssertEqual(result.load?.unit, .kilograms)
        XCTAssertEqual(result.reps, 9)
        draft.load = "225.5"
        XCTAssertEqual(try draft.value(for: .weightReps, unit: .pounds).load, .lb(225.5))
    }

    func testEditingDistanceKeepsTheExactDurationAndRejectsMalformedInput() throws {
        let original = Effort(duration: 61.123456789, distance: 400)
        var draft = EffortFields(original, unit: .kilograms)
        draft.distance = "450"
        XCTAssertEqual(try draft.value(for: .distanceDuration, unit: .kilograms).duration, original.duration)
        draft.duration = "61seconds"
        XCTAssertThrowsError(try draft.value(for: .distanceDuration, unit: .kilograms))
    }
}
