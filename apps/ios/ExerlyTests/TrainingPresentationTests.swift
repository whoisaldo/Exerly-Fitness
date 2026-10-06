import XCTest
import ExerlyCore
@testable import Exerly

@MainActor
final class TrainingPresentationTests: XCTestCase {
    func testAccountsCannotSeeEachOthersUnfinishedWorkAndRelaunchRestoresIt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let alice = try TrainingWorkspace(accountID: "alice/../shared", root: root)
        let session = try alice.store.startSession(name: "Upper", bodyweight: .kg(70))
        let exercise = try alice.store.addExercise("barbell-bench-press")
        var set = try XCTUnwrap(alice.store.activeSession?.exercises.first?.sets.first)
        set.primary = Effort(reps: 6, load: .kg(40))
        try alice.store.updateSet(set, in: exercise)
        try alice.store.completeSet(set.id)

        let bob = try TrainingWorkspace(accountID: "bob", root: root)
        XCTAssertNil(bob.store.activeSession)
        XCTAssertTrue(bob.store.history.sessions.isEmpty)
        let restored = try TrainingWorkspace(accountID: "alice/../shared", root: root)
        XCTAssertEqual(restored.store.activeSession?.id, session.id)
        XCTAssertEqual(restored.store.activeSession?.set(set.id)?.set.primary.load, .kg(40))
        XCTAssertTrue(try XCTUnwrap(restored.store.activeSession?.set(set.id)?.set.isCompleted))
        XCTAssertEqual(restored.store.restTimer?.endsAt, alice.store.restTimer?.endsAt)
        XCTAssertNotNil(restored.store.restTimer)
        try restored.store.skipRest()
        let skipped = try TrainingWorkspace(accountID: "alice/../shared", root: root)
        XCTAssertNil(skipped.store.restTimer)
        XCTAssertTrue(restored.url.path.hasPrefix(root.path + "/"))
        XCTAssertFalse(restored.url.path.contains("alice"))
        XCTAssertNotEqual(restored.url, bob.url)
    }

    func testMissingAccountAndUnreadableStorageDoNotCreateTemporaryWorkspaces() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try TrainingWorkspace(accountID: "", root: root))
        try Data("not a directory".utf8).write(to: root)
        XCTAssertThrowsError(try TrainingWorkspace(accountID: "alice", root: root))
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
}
