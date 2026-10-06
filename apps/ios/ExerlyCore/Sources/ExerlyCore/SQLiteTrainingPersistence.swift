import Foundation

/// Training data in a local SQLite database. Each session and custom exercise
/// is one JSON document keyed by its ID, written in one statement, so a crash
/// leaves either the old or the new version. The file uses write-ahead logging
/// with full sync. On iOS it gets the default data-protection class,
/// complete until first user authentication, so it is encrypted at rest and
/// still writable in the background after the first unlock.
@MainActor
public final class SQLiteTrainingPersistence: TrainingPersistence {
    public enum PersistenceError: Error, Equatable {
        /// The file was written by a newer app version. It is never downgraded.
        case newerSchema(found: Int, supported: Int)
    }

    public static let currentSchemaVersion = 1

    /// Rows that could not be decoded, as `table/id`. They stay in the file
    /// untouched so a later version can read them.
    public private(set) var unreadableRows: [String] = []

    private let database: SQLiteDatabase
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        database = try SQLiteDatabase(url: url)
        try database.executeScript("PRAGMA journal_mode = WAL; PRAGMA synchronous = FULL; PRAGMA foreign_keys = ON;")
        try migrate()
    }

    /// `Application Support/Exerly/exerly.sqlite`.
    public static func defaultURL() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Exerly", isDirectory: true)
            .appendingPathComponent("exerly.sqlite")
    }

    func schemaVersion() throws -> Int {
        guard case .integer(let version) = try database.query("PRAGMA user_version").first?.first else { return 0 }
        return Int(version)
    }

    /// Ordered migrations; migration `n` moves the schema from version n to n + 1.
    private static let migrations = [
        """
        CREATE TABLE sessions (
            id TEXT PRIMARY KEY,
            started_at REAL NOT NULL,
            ended_at REAL,
            payload BLOB NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE INDEX sessions_started_at ON sessions (started_at);
        CREATE TABLE custom_exercises (
            id TEXT PRIMARY KEY,
            payload BLOB NOT NULL,
            updated_at REAL NOT NULL
        );
        """,
    ]

    private func migrate() throws {
        let version = try schemaVersion()
        guard version <= Self.currentSchemaVersion else {
            throw PersistenceError.newerSchema(found: version, supported: Self.currentSchemaVersion)
        }
        for step in version..<Self.currentSchemaVersion {
            try database.transaction {
                try database.executeScript(Self.migrations[step])
                try database.executeScript("PRAGMA user_version = \(step + 1)")
            }
        }
    }

    /// Runs several writes as one atomic unit.
    public func inTransaction(_ body: () throws -> Void) throws {
        try database.transaction(body)
    }

    // MARK: TrainingPersistence

    public func loadSessions() throws -> [WorkoutSession] {
        try load(WorkoutSession.self, table: "sessions", order: "started_at")
    }

    public func loadCustomExercises() throws -> [Exercise] {
        try load(Exercise.self, table: "custom_exercises", order: "id")
    }

    public func save(_ session: WorkoutSession) throws {
        try database.execute(
            """
            INSERT INTO sessions (id, started_at, ended_at, payload, updated_at) VALUES (?, ?, ?, ?, ?)
            ON CONFLICT (id) DO UPDATE SET started_at = excluded.started_at, ended_at = excluded.ended_at,
                payload = excluded.payload, updated_at = excluded.updated_at
            """,
            session.id.uuidString, session.startedAt, session.endedAt, try encoder.encode(session), Date()
        )
    }

    public func deleteSession(_ id: UUID) throws {
        try database.execute("DELETE FROM sessions WHERE id = ?", id.uuidString)
    }

    public func save(_ exercise: Exercise) throws {
        try database.execute(
            """
            INSERT INTO custom_exercises (id, payload, updated_at) VALUES (?, ?, ?)
            ON CONFLICT (id) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at
            """,
            exercise.id.rawValue, try encoder.encode(exercise), Date()
        )
    }

    private func load<T: Decodable>(_ type: T.Type, table: String, order: String) throws -> [T] {
        var values: [T] = []
        for row in try database.query("SELECT id, payload FROM \(table) ORDER BY \(order)") {
            guard case .text(let id) = row[0] else { continue }
            if case .blob(let payload) = row[1], let value = try? decoder.decode(T.self, from: payload) {
                values.append(value)
            } else if !unreadableRows.contains("\(table)/\(id)") {
                unreadableRows.append("\(table)/\(id)")
            }
        }
        return values
    }
}
