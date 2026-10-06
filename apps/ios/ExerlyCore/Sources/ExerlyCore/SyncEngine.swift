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

    @ObservationIgnored private let hosts: [DocumentHost]
    @ObservationIgnored private let stateStore: SyncStateStore
    @ObservationIgnored private let api: DocumentAPI
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var running: Task<Void, Error>?
    @ObservationIgnored private var bases: [String: SyncBase] = [:]

    private static let maxAttempts = 4

    /// `hosts` are synced in order, kind by kind, so a host's earlier kinds
    /// (custom exercises) arrive before the ones that use them (sessions).
    public init(hosts: [DocumentHost], state: SyncStateStore, api: DocumentAPI, now: @escaping () -> Date = Date.init) {
        self.hosts = hosts
        stateStore = state
        self.api = api
        self.now = now
    }

    public convenience init(store: TrainingStore, state: SyncStateStore, api: DocumentAPI, now: @escaping () -> Date = Date.init) {
        self.init(hosts: [store], state: state, api: api, now: now)
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

    private var kindOrder: [String] { hosts.flatMap(\.documentKinds) }

    private func host(for kind: String) -> DocumentHost? {
        hosts.first { $0.documentKinds.contains(kind) }
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
            for kind in kindOrder {
                for change in page.changes where change.kind == kind { try receive(change) }
            }
            cursor = page.cursor
            try stateStore.saveSyncCursor(cursor)
            if !page.hasMore { return }
        }
    }

    /// Applies a remote version, merging with unpushed local changes.
    private func receive(_ change: RemoteDocument) throws {
        guard let host = host(for: change.kind) else { return }
        let key = Self.key(change.kind, change.id)
        let base = bases[key]
        if let base, change.revision <= base.revision { return }
        let remote = try change.payload.map { try host.canonicalize(kind: change.kind, payload: $0) }
        let local = try host.payload(kind: change.kind, id: change.id)
        let clean = base.map { local == $0.payload } ?? (local == nil)
        var write: Data??
        if clean {
            write = .some(remote)
        } else if let remote, let local {
            write = .some(try host.merge(kind: change.kind, base: base?.payload, local: local, remote: remote))
        } else if let remote {
            // Deleted here, changed there: the change wins.
            write = .some(remote)
        }
        // Changed here, deleted there: local stays and is pushed back.
        let newBase = SyncBase(kind: change.kind, id: change.id, revision: change.revision, payload: remote)
        var publish: () -> Void = {}
        try stateStore.performAtomically {
            if let write { publish = try host.prepareWrite(kind: change.kind, id: change.id, payload: write) }
            try stateStore.saveSyncBase(newBase)
        }
        publish()
        bases[key] = newBase
    }

    // MARK: Push

    /// Pushes every document that differs from its base. Returns whether anything was written.
    private func push() async throws -> Bool {
        let order = kindOrder
        var documents = Set<SyncBase>()
        for base in bases.values where base.payload != nil { documents.insert(SyncBase(kind: base.kind, id: base.id, revision: 0)) }
        for host in hosts {
            for kind in host.documentKinds {
                for id in host.documentIDs(kind: kind) { documents.insert(SyncBase(kind: kind, id: id, revision: 0)) }
            }
        }
        let ordered = documents.sorted {
            (order.firstIndex(of: $0.kind) ?? .max, $0.id) < (order.firstIndex(of: $1.kind) ?? .max, $1.id)
        }
        var wrote = false
        for document in ordered where host(for: document.kind) != nil {
            if try await pushDocument(document.kind, document.id) { wrote = true }
        }
        return wrote
    }

    private func pushDocument(_ kind: String, _ id: String) async throws -> Bool {
        for _ in 0..<Self.maxAttempts {
            guard let host = host(for: kind) else { return false }
            let current = try host.payload(kind: kind, id: id)
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

    // MARK: Bases

    private static func key(_ kind: String, _ id: String) -> String { "\(kind)/\(id)" }

    private func saveBase(_ base: SyncBase) throws {
        try stateStore.saveSyncBase(base)
        bases[Self.key(base.kind, base.id)] = base
    }
}
