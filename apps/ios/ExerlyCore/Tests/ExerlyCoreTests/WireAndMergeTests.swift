import Foundation
import Testing
@testable import ExerlyCore

@Suite struct WireFormatTests {
    @Test func datesTravelAsMillisecondISOStrings() throws {
        let date = Date(timeIntervalSince1970: 1_791_223_200.123)
        let data = try ExerlyJSON.encoder.encode(["at": date])
        #expect(String(bytes: data, encoding: .utf8) == #"{"at":"2026-10-05T18:00:00.123Z"}"#)
        let decoded = try ExerlyJSON.decoder.decode([String: Date].self, from: data)
        #expect(decoded["at"] == Date.milliseconds(1_791_223_200_123))
    }

    @Test func roundedDatesRoundTripExactly() throws {
        for raw in [0.0, 1_791_223_200.1234567, 1_791_223_200.9995, -12.3456, 2_000_000_000.0009] {
            let rounded = Date(timeIntervalSince1970: raw).roundedToMilliseconds
            let back = try ExerlyJSON.decoder.decode([Date].self, from: ExerlyJSON.encoder.encode([rounded]))
            #expect(back == [rounded], "\(raw)")
            #expect(rounded.roundedToMilliseconds == rounded)
        }
    }

    @Test func acceptsOtherISOFormsAndRejectsGarbage() throws {
        let plain = try ExerlyJSON.decoder.decode([Date].self, from: Data(#"["2026-10-05T18:00:00Z"]"#.utf8))
        #expect(plain == [Date.milliseconds(1_791_223_200_000)])
        let offset = try ExerlyJSON.decoder.decode([Date].self, from: Data(#"["2026-10-05T14:00:00.5-04:00"]"#.utf8))
        #expect(offset == [Date.milliseconds(1_791_223_200_500)])
        #expect(throws: DecodingError.self) {
            try ExerlyJSON.decoder.decode([Date].self, from: Data(#"["yesterday"]"#.utf8))
        }
    }

    @Test func encodingIsCanonical() throws {
        let session = Fixture.session([("barbell-bench-press", [Fixture.set(5, 100)])])
        let a = try ExerlyJSON.canonical(session)
        let b = try ExerlyJSON.canonical(try ExerlyJSON.decoder.decode(WorkoutSession.self, from: a))
        #expect(a == b)
    }

    @Test func appleNonceIsRandomAndHashed() {
        let first = AppleSignInNonce()
        let second = AppleSignInNonce()
        #expect(first.raw != second.raw)
        #expect(first.raw.count >= 32)
        #expect(first.sha256.count == 64)
        #expect(first.sha256 == AppleSignInNonce.sha256Hex(first.raw))
        #expect(AppleSignInNonce.sha256Hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}

@Suite struct MergeTests {
    let library = Fixture.library

    func base() -> WorkoutSession {
        var session = Fixture.session([("back-squat", [Fixture.set(5, 100), Fixture.set(5, 100, done: false)])])
        session.notes = "base"
        return session
    }

    @Test func takesWhicheverSideChangedAField() {
        let base = base()
        var local = base
        local.notes = "local"
        var remote = base
        remote.name = "Remote name"
        let merged = Merge.session(base: base, local: local, remote: remote)
        #expect(merged.notes == "local")
        #expect(merged.name == "Remote name")
    }

    @Test func localWinsWhenBothChangedTheSameField() {
        let base = base()
        var local = base
        local.notes = "local"
        var remote = base
        remote.notes = "remote"
        #expect(Merge.session(base: base, local: local, remote: remote).notes == "local")
    }

    @Test func keepsSetsAndExercisesAddedOnBothSides() throws {
        let base = base()
        var local = base
        try local.addSet(to: local.exercises[0].id)
        let localSet = local.exercises[0].sets.last!.id
        var remote = base
        try remote.addExercise("leg-extension", library: library)
        try remote.addSet(to: remote.exercises[0].id)
        let remoteSet = remote.exercises[0].sets.last!.id

        let merged = Merge.session(base: base, local: local, remote: remote)
        #expect(merged.exercises.map(\.exerciseID) == ["back-squat", "leg-extension"])
        let ids = merged.exercises[0].sets.map(\.id)
        #expect(ids.prefix(2) == base.exercises[0].sets.map(\.id)[...])
        #expect(ids.contains(localSet) && ids.contains(remoteSet))
        #expect(ids.count == 4)
    }

    @Test func mergesEditsToTheSameSetFieldByField() {
        let base = base()
        let setID = base.exercises[0].sets[1].id
        var local = base
        local.exercises[0].sets[1].primary = Effort(reps: 5, load: .kg(105))
        var remote = base
        remote.exercises[0].sets[1].completedAt = Fixture.instant(minutes: 10)
        remote.exercises[0].sets[1].rir = 2
        let merged = Merge.session(base: base, local: local, remote: remote)
        let set = merged.set(setID)!.set
        #expect(set.primary.load == .kg(105))
        #expect(set.completedAt == Fixture.instant(minutes: 10))
        #expect(set.rir == 2)
    }

    @Test func deletionAppliesOnlyWhenTheOtherSideLeftItAlone() throws {
        let base = base()
        let doneSet = base.exercises[0].sets[0].id
        let draftSet = base.exercises[0].sets[1].id

        // Local deletes the draft; remote didn't touch it: gone.
        var local = base
        try local.removeSet(draftSet)
        #expect(Merge.session(base: base, local: local, remote: base).set(draftSet) == nil)

        // Local deletes the exercise; remote logged a set in it: the set survives.
        var deleting = base
        try deleting.removeExercise(base.exercises[0].id)
        var logging = base
        logging.exercises[0].sets[1].primary = Effort(reps: 5, load: .kg(100))
        logging.exercises[0].sets[1].completedAt = Fixture.instant(minutes: 8)
        let merged = Merge.session(base: base, local: deleting, remote: logging)
        #expect(merged.set(draftSet)?.set.isCompleted == true)
        #expect(merged.set(doneSet) != nil)
    }

    @Test func withoutABaseEverythingFromBothSidesIsKept() throws {
        var local = base()
        local.notes = "local"
        var remote = base()
        remote.id = local.id
        remote.notes = "remote"
        let merged = Merge.session(base: nil, local: local, remote: remote)
        #expect(merged.notes == "local")
        #expect(merged.exercises.map(\.id) == local.exercises.map(\.id) + remote.exercises.map(\.id))
    }

    @Test func mergingIsStableWhenNothingChanged() {
        let base = base()
        #expect(Merge.session(base: base, local: base, remote: base) == base)
    }
}
