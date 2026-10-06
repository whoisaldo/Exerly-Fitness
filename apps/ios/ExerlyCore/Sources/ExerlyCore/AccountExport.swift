import Foundation

/// The full export, including what this device hasn't synced yet. The
/// server's export (`AccountAPI.exportAccount()`) holds what reached the
/// server; this overlays the device's newer documents, so a workout logged
/// offline is never left out.
@MainActor
public enum AccountExport {
    /// The server export with this device's unsynced documents merged into its
    /// `documents` rows. Each added or replaced row carries `"pending_sync": true`;
    /// a document deleted on this device but not yet on the server is left out.
    /// With no server export (offline), the result holds this device's documents
    /// only, and says so in `note`.
    public static func merging(server: Data?, hosts: [DocumentHost], state: SyncStateStore,
                               now: Date = Date()) throws -> Data {
        var export: [String: Any]
        if let server {
            guard let parsed = try JSONSerialization.jsonObject(with: server) as? [String: Any] else {
                throw DocumentError(message: "The server export isn't a JSON object")
            }
            export = parsed
        } else {
            export = [
                "exported_at": ISOMilliseconds.format(now.millisecondsSince1970),
                "version": 3,
                "source": "device",
                "note": "Exported on this device while offline: training, proposals and the audit log only. "
                    + "Account details and data kept only on the server are not included.",
            ]
        }
        let bases = Dictionary(try state.syncBases().map { ("\($0.kind)/\($0.id)", $0) }, uniquingKeysWith: { a, _ in a })
        var rows = (export["documents"] as? [[String: Any]]) ?? []
        func index(_ kind: String, _ id: String) -> Int? {
            rows.firstIndex { $0["kind"] as? String == kind && $0["document_id"] as? String == id }
        }
        var seen = Set<String>()
        for host in hosts {
            for kind in host.documentKinds {
                for id in host.documentIDs(kind: kind) {
                    seen.insert("\(kind)/\(id)")
                    guard let local = try host.payload(kind: kind, id: id) else { continue }
                    let base = bases["\(kind)/\(id)"]
                    let synced = base?.payload == local
                    if synced && server != nil { continue }
                    var row: [String: Any] = [
                        "kind": kind, "document_id": id, "revision": base?.revision ?? 0,
                        "payload": try JSONSerialization.jsonObject(with: local), "deleted_at": NSNull(),
                    ]
                    if !synced { row["pending_sync"] = true }
                    if let existing = index(kind, id) {
                        rows[existing] = rows[existing].merging(row) { _, new in new }
                    } else {
                        rows.append(row)
                    }
                }
            }
        }
        // Deleted here, not yet on the server: the person no longer has it.
        rows.removeAll { row in
            guard let kind = row["kind"] as? String, let id = row["document_id"] as? String,
                  hosts.contains(where: { $0.documentKinds.contains(kind) }), !seen.contains("\(kind)/\(id)")
            else { return false }
            return bases["\(kind)/\(id)"]?.payload != nil
        }
        export["documents"] = rows
        return try JSONSerialization.data(withJSONObject: export, options: [.sortedKeys, .withoutEscapingSlashes])
    }
}
