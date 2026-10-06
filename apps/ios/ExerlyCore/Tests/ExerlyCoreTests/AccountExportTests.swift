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

    @Test func entriesTheLegacyAppHasNotSyncedAreMergedIn() throws {
        let edited = UUID().uuidString.lowercased()
        let deleted = UUID().uuidString.lowercased()
        let created = UUID().uuidString.lowercased()
        func json(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object) }
        let server = try json([
            "version": 3, "documents": [],
            "food": [
                ["id": "s1", "client_id": edited, "food_name": "Oats", "calories": 300, "account_id": "a"],
                ["id": "s2", "client_id": deleted, "food_name": "Toast", "calories": 200, "account_id": "a"],
                ["id": "s3", "client_id": UUID().uuidString.lowercased(), "food_name": "Rice", "calories": 400, "account_id": "a"],
            ],
            "water": [["id": "s4", "entry_date": "2026-10-05", "ml": 500, "account_id": "a"]],
        ])
        let pending = [
            AccountExport.PendingRow(table: "food", clientID: edited, serverID: "s1",
                                     row: try json(["id": "s1", "client_id": edited, "food_name": "Oats", "calories": 350])),
            AccountExport.PendingRow(table: "food", clientID: deleted, serverID: "s2", row: nil),
            AccountExport.PendingRow(table: "food", clientID: created, serverID: nil,
                                     row: try json(["id": created, "client_id": created, "food_name": "Eggs", "calories": 150])),
            AccountExport.PendingRow(table: "water", clientID: "2026-10-05", serverID: nil,
                                     row: try json(["entry_date": "2026-10-05", "ml": 750])),
        ]
        let merged = try AccountExport.merging(server: server, hosts: [], state: InMemoryTrainingPersistence(), pending: pending)
        let export = try #require(try JSONSerialization.jsonObject(with: merged) as? [String: Any])
        let food = try #require(export["food"] as? [[String: Any]])
        #expect(food.map { $0["food_name"] as? String }.sorted { ($0 ?? "") < ($1 ?? "") } == ["Eggs", "Oats", "Rice"])
        let oats = try #require(food.first { $0["food_name"] as? String == "Oats" })
        #expect(oats["calories"] as? Int == 350 && oats["pending_sync"] as? Bool == true)
        #expect(oats["account_id"] as? String == "a", "Server-only columns are kept")
        #expect(food.first { $0["food_name"] as? String == "Rice" }?["pending_sync"] == nil)
        let water = try #require(export["water"] as? [[String: Any]])
        #expect(water.count == 1 && water[0]["ml"] as? Int == 750 && water[0]["pending_sync"] as? Bool == true)

        // Offline, the queued entries are all there is, and the note says so.
        let offline = try #require(try JSONSerialization.jsonObject(
            with: AccountExport.merging(server: nil, hosts: [], state: InMemoryTrainingPersistence(), pending: pending)) as? [String: Any])
        #expect((offline["food"] as? [[String: Any]])?.count == 2)
        #expect((offline["note"] as? String)?.contains("entries waiting to sync") == true)
    }
}
