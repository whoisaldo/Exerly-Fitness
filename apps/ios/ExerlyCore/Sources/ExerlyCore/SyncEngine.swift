import CryptoKit
import Foundation
import Observation

/// The document endpoints the sync engine needs. `ExerlyAPI` provides them.
public protocol DocumentAPI: Sendable {
    func putDocument(kind: String, id: String, payload: Data, baseRevision: Int, idempotencyKey: String) async throws -> DocumentWriteResult
    func deleteDocument(kind: String, id: String, baseRevision: Int, idempotencyKey: String) async throws -> DocumentWriteResult
    func changes(after cursor: Int, limit: Int) async throws -> ChangePage
}

extension ExerlyAPI: DocumentAPI {}

/// Keeps a TrainingStore and the server in step. See
/// docs/design/003-document-sync.md.
///
/// A document needs pushing when its canonical JSON differs from the base:
/// the last version the server acknowledged. Because that is derived rather
/// than flagged, a crash between saving and syncing can't lose a change.
/// Conflicts merge three ways and are pushed again.
@MainActor
@Observable
public final class SyncEngine {
    public enum State: Equatable, Sendable {
        case idle
        case syncing
        /// The last attempt couldn't reach the server. Local data is intact.
        case offline
        case failed(String)
    }

    public private(set) var state: State = .idle
    public private(set) var lastSyncedAt: Date?

    @ObservationIgnored private let store: TrainingStore
    @ObservationIgnored private let stateStore: SyncStateStore
    @ObservationIgnored private let api: DocumentAPI
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var running: Task<Void, Error>?
    @ObservationIgnored private var bases: [String: SyncBase] = [:]

    private static let sessionKind = "workout_session"
    private static let exerciseKind = "custom_exercise"
    private static let maxAttempts = 4

    public init(store: TrainingStore, state: SyncStateStore, api: DocumentAPI, now: @escaping () -> Date = Date.init) {
        self.store = store
        stateStore = state
        self.api = api
        self.now = now
    }

    /// Pulls, pushes, then pulls again. Overlapping calls share one run.
    public func sync() async throws {
        if let running { return try await running.value }
        let task = Task { try await self.run() }
        running = task
        defer { running = nil }
        do {
            try await task.value
            state = .idle
            lastSyncedAt = now()
        } catch {
            switch error {
            case APIError.sessionExpired, APIError.notSignedIn: state = .failed("Sign in again to sync.")
            case APIError.server(_, let message): state = .failed(message)
            case APIError.invalidResponse: state = .failed("The server sent an unexpected response.")
            default: state = .offline
            }
            throw error
        }
    }

    private func run() async throws {
        state = .syncing
        bases = Dictionary(try stateStore.syncBases().map { (Self.key($0.kind, $0.id), $0) }, uniquingKeysWith: { a, _ in a })
        try await pull()
        if try await push() { try await pull() }
    }

    // MARK: Pull

    private func pull() async throws {
        var cursor = try stateStore.syncCursor()
        while true {
            let page = try await api.changes(after: cursor, limit: 500)
            // Exercises first, so sessions that use them can be read.
            for change in page.changes where change.kind == Self.exerciseKind { try receive(change) }
            for change in page.changes where change.kind != Self.exerciseKind { try receive(change) }
            cursor = page.cursor
            try stateStore.saveSyncCursor(cursor)
            if !page.hasMore { return }
        }
    }

    /// Applies a remote version, merging with unpushed local changes.
    private func receive(_ change: RemoteDocument) throws {
        guard change.kind == Self.sessionKind || change.kind == Self.exerciseKind else { return }
        let key = Self.key(change.kind, change.id)
        let base = bases[key]
        if let base, change.revision <= base.revision { return }
        let remote = try change.payload.map { try canonicalize(change.kind, $0) }
        let local = try localData(change.kind, change.id)
        let clean = base.map { local == $0.payload } ?? (local == nil)
        if clean {
            try write(change.kind, change.id, remote)
        } else if let remote, let local {
            try write(change.kind, change.id, try merge(change.kind, base: base?.payload, local: local, remote: remote))
        } else if let remote {
            // Deleted here, changed there: the change wins.
            try write(change.kind, change.id, remote)
        }
        // Changed here, deleted there: local stays and is pushed back.
        try saveBase(SyncBase(kind: change.kind, id: change.id, revision: change.revision, payload: remote))
    }

    // MARK: Push

    /// Pushes every document that differs from its base. Returns whether anything was written.
    private func push() async throws -> Bool {
        var keys = Set(bases.values.filter { $0.payload != nil }.map { Self.key($0.kind, $0.id) })
        var kinds: [String: (String, String)] = [:]
        for base in bases.values { kinds[Self.key(base.kind, base.id)] = (base.kind, base.id) }
        for document in store.syncDocuments() {
            let key = Self.key(document.kind, document.id)
            keys.insert(key)
            kinds[key] = (document.kind, document.id)
        }
        // Exercises first, so the server never holds a session whose exercise it hasn't seen.
        let ordered = keys.sorted { (kinds[$0]!.0 == Self.exerciseKind ? 0 : 1, $0) < (kinds[$1]!.0 == Self.exerciseKind ? 0 : 1, $1) }
        var wrote = false
        for key in ordered {
            let (kind, id) = kinds[key]!
            if try await pushDocument(kind, id) { wrote = true }
        }
        return wrote
    }

    private func pushDocument(_ kind: String, _ id: String) async throws -> Bool {
        for _ in 0..<Self.maxAttempts {
            let current = try localData(kind, id)
            var base = bases[Self.key(kind, id)] ?? SyncBase(kind: kind, id: id, revision: 0)
            if current == base.payload || (current == nil && base.revision == 0) { return false }
            // One key per content and base revision: a lost response is
            // retried with the same key, a merged version gets a new one.
            let hash = SHA256.hash(data: current ?? Data()).map { String(format: "%02x", $0) }.joined() + "@\(base.revision)"
            if base.pushHash != hash || base.pushKey == nil {
                base.pushKey = UUID().uuidString
                base.pushHash = hash
                try saveBase(base)
            }
            let result: DocumentWriteResult
            do {
                if let current {
                    result = try await api.putDocument(kind: kind, id: id, payload: current, baseRevision: base.revision,
                                                       idempotencyKey: base.pushKey!)
                } else {
                    result = try await api.deleteDocument(kind: kind, id: id, baseRevision: base.revision,
                                                          idempotencyKey: base.pushKey!)
                }
            } catch APIError.server(status: 404, _) where current == nil {
                try stateStore.removeSyncBase(kind: kind, id: id)
                bases[Self.key(kind, id)] = nil
                return false
            }
            switch result {
            case .applied(let revision):
                try saveBase(SyncBase(kind: kind, id: id, revision: revision, payload: current))
                return true
            case .conflict(let remote?):
                try receive(remote)
            case .conflict(nil):
                // The server has no such document: start again from nothing.
                try saveBase(SyncBase(kind: kind, id: id, revision: 0))
            }
        }
        throw APIError.server(status: 409, message: "\(kind) \(id) kept changing during sync. Try again.")
    }

    // MARK: Documents

    private static func key(_ kind: String, _ id: String) -> String { "\(kind)/\(id)" }

    private func saveBase(_ base: SyncBase) throws {
        try stateStore.saveSyncBase(base)
        bases[Self.key(base.kind, base.id)] = base
    }

    private func localData(_ kind: String, _ id: String) throws -> Data? {
        switch kind {
        case Self.sessionKind:
            return try UUID(uuidString: id).flatMap(store.session(withID:)).map(ExerlyJSON.canonical)
        default:
            let exercise = store.library.exercise(ExerciseID(id))
            return try exercise.flatMap { $0.id.isCustom ? $0 : nil }.map(ExerlyJSON.canonical)
        }
    }

    private func canonicalize(_ kind: String, _ payload: Data) throws -> Data {
        switch kind {
        case Self.sessionKind: return try ExerlyJSON.canonical(ExerlyJSON.decoder.decode(WorkoutSession.self, from: payload))
        default: return try ExerlyJSON.canonical(ExerlyJSON.decoder.decode(Exercise.self, from: payload))
        }
    }

    private func merge(_ kind: String, base: Data?, local: Data, remote: Data) throws -> Data {
        let decoder = ExerlyJSON.decoder
        switch kind {
        case Self.sessionKind:
            return try ExerlyJSON.canonical(Merge.session(
                base: try base.map { try decoder.decode(WorkoutSession.self, from: $0) },
                local: try decoder.decode(WorkoutSession.self, from: local),
                remote: try decoder.decode(WorkoutSession.self, from: remote)
            ))
        default:
            return try ExerlyJSON.canonical(Merge.exerciseDefinition(
                base: try base.map { try decoder.decode(Exercise.self, from: $0) },
                local: try decoder.decode(Exercise.self, from: local),
                remote: try decoder.decode(Exercise.self, from: remote)
            ))
        }
    }

    private func write(_ kind: String, _ id: String, _ data: Data?) throws {
        switch kind {
        case Self.sessionKind:
            guard let uuid = UUID(uuidString: id) else { return }
            if let data {
                try store.applyRemote(ExerlyJSON.decoder.decode(WorkoutSession.self, from: data))
            } else if store.session(withID: uuid) != nil {
                try store.removeRemoteSession(uuid)
            }
        default:
            // Custom exercises are never removed locally; sessions may still use them.
            if let data { try store.applyRemote(ExerlyJSON.decoder.decode(Exercise.self, from: data)) }
        }
    }
}
