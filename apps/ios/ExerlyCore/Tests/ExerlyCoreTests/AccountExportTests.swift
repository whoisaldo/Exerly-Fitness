import Foundation
import Testing
@testable import ExerlyCore

@MainActor
@Suite struct AccountExportTests {
    func row(_ kind: String, _ id: String, _ payload: Data?, revision: Int) throws -> [String: Any] {
        ["id": UUID().uuidString, "kind": kind, "document_id": id, "revision": revision,
         "payload": try payload.map { try JSONSerialization.jsonObject(with: $0) } ?? NSNull(),
         "deleted_at": NSNull(), "account_id": "a"]
    }

    func documents(_ data: Data) throws -> [String: [String: Any]] {
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let rows = try #require(json["documents"] as? [[String: Any]])
        return Dictionary(uniqueKeysWithValues: rows.map { ("\($0["kind"]!)/\($0["document_id"]!)", $0) })
    }

    @Test func unsyncedWorkIsMergedIntoTheServerExport() throws {
        let persistence = InMemoryTrainingPersistence()
        let synced = Fixture.session(days: 0, [("deadlift", [Fixture.set(3, 150)])])
        var edited = Fixture.session(days: 1, [("back-squat", [Fixture.set(5, 120)])])
        let deleted = Fixture.session(days: 2, [("barbell-bench-press", [Fixture.set(5, 100)])])
        let offline = Fixture.session(days: 3, [("deadlift", [Fixture.set(5, 140)])])
        for session in [synced, edited, deleted, offline] { try persistence.save(session) }
        for session in [synced, edited, deleted] {
            try persistence.saveSyncBase(SyncBase(kind: "workout_session", id: session.id.uuidString, revision: 1,
                                                  payload: try ExerlyJSON.canonical(session)))
        }
        let store = try TrainingStore(persistence: persistence)
        let editedBefore = try ExerlyJSON.canonical(edited)
        edited.notes = "Fixed on the plane"
        try store.saveSession(edited)
        try store.deleteSession(deleted.id)
        let elsewhere = UUID().uuidString

        let server = try JSONSerialization.data(withJSONObject: [
            "version": 3, "account": ["email": "person@exerly.test"],
            "documents": [
                try row("workout_session", synced.id.uuidString, ExerlyJSON.canonical(synced), revision: 1),
                try row("workout_session", edited.id.uuidString, editedBefore, revision: 1),
                try row("workout_session", deleted.id.uuidString, ExerlyJSON.canonical(deleted), revision: 1),
                try row("workout_session", elsewhere, Data(#"{"id":"x"}"#.utf8), revision: 4),
            ],
        ])
        let merged = try documents(AccountExport.merging(server: server, hosts: [store], state: persistence))

        let syncedRow = try #require(merged["workout_session/\(synced.id.uuidString)"])
        #expect(syncedRow["pending_sync"] == nil && syncedRow["account_id"] as? String == "a")
        let editedRow = try #require(merged["workout_session/\(edited.id.uuidString)"])
        #expect(editedRow["pending_sync"] as? Bool == true)
        #expect((editedRow["payload"] as? [String: Any])?["notes"] as? String == "Fixed on the plane")
        #expect(merged["workout_session/\(offline.id.uuidString)"]?["pending_sync"] as? Bool == true)
        #expect(merged["workout_session/\(deleted.id.uuidString)"] == nil)
        #expect(merged["workout_session/\(elsewhere)"]?["revision"] as? Int == 4, "Server-only documents stay")
    }

    @Test func offlineTheExportHoldsThisDevicesDocumentsAndSaysSo() throws {
        let persistence = InMemoryTrainingPersistence()
        let session = Fixture.session([("deadlift", [Fixture.set(3, 150)])])
        try persistence.save(session)
        let store = try TrainingStore(persistence: persistence)
        let data = try AccountExport.merging(server: nil, hosts: [store], state: persistence, now: Fixture.instant())
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["source"] as? String == "device")
        #expect((json["note"] as? String)?.contains("offline") == true)
        #expect(json["exported_at"] as? String == "2026-10-05T18:00:00.000Z")
        #expect(try documents(data)["workout_session/\(session.id.uuidString)"]?["pending_sync"] as? Bool == true)
    }
}
