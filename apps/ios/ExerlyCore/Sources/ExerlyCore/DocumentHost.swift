import Foundation

/// Stores whose entities sync and can be changed by proposals: the training
/// store, the agent store, and later nutrition and programs.
@MainActor
public protocol DocumentHost: AnyObject {
    /// The kinds this host owns, in the order they should sync.
    var documentKinds: [String] { get }
    func documentIDs(kind: String) -> [String]
    /// The current canonical payload, or nil when the document doesn't exist.
    func payload(kind: String, id: String) throws -> Data?
    /// Decodes and re-encodes a payload, throwing when it isn't a valid document of that kind.
    func canonicalize(kind: String, payload: Data) throws -> Data
    /// Stricter than `canonicalize`: what a proposal may write.
    func validate(kind: String, id: String, payload: Data) throws
    func merge(kind: String, base: Data?, local: Data, remote: Data) throws -> Data
    /// Persists a write, nil to delete, and returns the step that publishes it in
    /// memory. Call inside `performAtomically` and publish only after it commits.
    func prepareWrite(kind: String, id: String, payload: Data?) throws -> () -> Void
}

/// Documents with no dedicated table: proposals and audit events.
@MainActor
public protocol DocumentPersistence: AnyObject {
    func loadDocuments(kind: String) throws -> [Data]
    func saveDocument(kind: String, id: String, payload: Data) throws
    func deleteDocument(kind: String, id: String) throws
}

public struct DocumentError: Error, Equatable {
    public let message: String
}

extension TrainingStore: DocumentHost {
    static let sessionKind = "workout_session"
    static let exerciseKind = "custom_exercise"

    public var documentKinds: [String] { [Self.exerciseKind, Self.sessionKind] }

    public func documentIDs(kind: String) -> [String] {
        switch kind {
        case Self.exerciseKind: library.exercises.filter(\.id.isCustom).map(\.id.rawValue)
        case Self.sessionKind: (history.sessions + (activeSession.map { [$0] } ?? [])).map(\.id.uuidString)
        default: []
        }
    }

    public func payload(kind: String, id: String) throws -> Data? {
        switch kind {
        case Self.sessionKind:
            return try UUID(uuidString: id).flatMap(session(withID:)).map(ExerlyJSON.canonical)
        case Self.exerciseKind:
            return try library.exercise(ExerciseID(id)).flatMap { $0.id.isCustom ? $0 : nil }.map(ExerlyJSON.canonical)
        default:
            return nil
        }
    }

    public func canonicalize(kind: String, payload: Data) throws -> Data {
        switch kind {
        case Self.sessionKind: try ExerlyJSON.canonical(ExerlyJSON.decoder.decode(WorkoutSession.self, from: payload))
        case Self.exerciseKind: try ExerlyJSON.canonical(ExerlyJSON.decoder.decode(Exercise.self, from: payload))
        default: throw DocumentError(message: "Unknown kind \(kind)")
        }
    }

    public func validate(kind: String, id: String, payload: Data) throws {
        switch kind {
        case Self.sessionKind:
            let session = try ExerlyJSON.decoder.decode(WorkoutSession.self, from: payload)
            guard session.id.uuidString == id else { throw DocumentError(message: "The session ID doesn't match") }
            try session.validate(library: library)
        case Self.exerciseKind:
            let exercise = try ExerlyJSON.decoder.decode(Exercise.self, from: payload)
            guard exercise.id.rawValue == id, exercise.id.isCustom, exercise.validationErrors.isEmpty else {
                throw DocumentError(message: "Not a valid custom exercise")
            }
        default:
            throw DocumentError(message: "Unknown kind \(kind)")
        }
    }

    public func merge(kind: String, base: Data?, local: Data, remote: Data) throws -> Data {
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

    public func prepareWrite(kind: String, id: String, payload: Data?) throws -> () -> Void {
        switch kind {
        case Self.sessionKind:
            guard let uuid = UUID(uuidString: id) else { throw DocumentError(message: "Invalid session ID") }
            if let payload {
                return try stageSession(ExerlyJSON.decoder.decode(WorkoutSession.self, from: payload))
            }
            return try stageSessionRemoval(uuid)
        case Self.exerciseKind:
            // Custom exercises are never removed; sessions may still use them.
            guard let payload else { return {} }
            return try stageExercise(ExerlyJSON.decoder.decode(Exercise.self, from: payload))
        default:
            throw DocumentError(message: "Unknown kind \(kind)")
        }
    }
}
