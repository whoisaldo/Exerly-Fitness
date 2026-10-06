import Foundation
import Observation

/// The training state screens bind to: the exercise library, finished
/// history, the session in progress and its rest timer. Every change is
/// validated by ExerlyCore and written to persistence before returning.
@MainActor
@Observable
public final class TrainingStore {
    public enum StoreError: Error, Equatable {
        case noActiveSession
        case sessionInProgress
        case sessionNotFound(UUID)
        case invalidCustomExercise([String])
        case edit(WorkoutSession.EditError)
    }

    public struct SessionSummary: Sendable {
        public var session: WorkoutSession
        public var records: [PersonalRecord]
    }

    public private(set) var library: ExerciseLibrary
    /// Finished sessions.
    public private(set) var history: TrainingHistory
    public private(set) var activeSession: WorkoutSession?
    public private(set) var restTimer: RestTimer?
    public var restPolicy: RestPolicy

    @ObservationIgnored private let persistence: TrainingPersistence
    @ObservationIgnored private let now: () -> Date

    public init(
        persistence: TrainingPersistence, library: ExerciseLibrary = .bundled,
        restPolicy: RestPolicy = RestPolicy(), now: @escaping () -> Date = Date.init
    ) throws {
        self.persistence = persistence
        self.now = now
        self.restPolicy = restPolicy
        var library = library
        for exercise in try persistence.loadCustomExercises() where library.exercise(exercise.id) == nil {
            library = try library.adding(exercise)
        }
        self.library = library
        let sessions = try persistence.loadSessions()
        history = TrainingHistory(sessions: sessions.filter(\.isFinished), library: library)
        activeSession = sessions.filter { !$0.isFinished }.max { $0.startedAt < $1.startedAt }
    }

    // MARK: The session in progress

    @discardableResult
    public func startSession(name: String, bodyweight: Mass?, timeZone: TimeZone = .current) throws -> WorkoutSession {
        guard activeSession == nil else { throw StoreError.sessionInProgress }
        let session = WorkoutSession(name: name, startedAt: now(), timeZone: timeZone, bodyweight: bodyweight)
        try persistence.save(session)
        activeSession = session
        return session
    }

    /// Adds an exercise prefilled from its last performance.
    @discardableResult
    public func addExercise(_ exerciseID: ExerciseID, at index: Int? = nil) throws -> UUID {
        let previous = history.lastPerformance(of: exerciseID)
        return try edit { try $0.addExercise(exerciseID, at: index, previous: previous, library: library) }
    }

    @discardableResult
    public func addSet(to performedID: UUID, kind: SetKind? = nil) throws -> UUID {
        try edit { try $0.addSet(to: performedID, kind: kind) }
    }

    public func updateSet(_ set: PerformedSet, in performedID: UUID, propagate: Bool = false) throws {
        try edit { try $0.updateSet(set, in: performedID, propagate: propagate) }
    }

    /// Completes a set and starts the rest timer the policy picks.
    public func completeSet(_ setID: UUID) throws {
        let date = now()
        try edit { try $0.completeSet(setID, at: date, library: library) }
        if let session = activeSession {
            restTimer = RestTimer(startedAt: date, duration: restPolicy.rest(after: setID, in: session, library: library))
        }
    }

    public func reopenSet(_ setID: UUID) throws { try edit { try $0.reopenSet(setID) } }
    public func removeSet(_ setID: UUID) throws { try edit { try $0.removeSet(setID) } }
    public func removeExercise(_ performedID: UUID) throws { try edit { try $0.removeExercise(performedID) } }
    public func moveExercise(_ performedID: UUID, to index: Int) throws { try edit { try $0.moveExercise(performedID, to: index) } }

    @discardableResult
    public func makeSuperset(_ performedIDs: [UUID]) throws -> UUID {
        try edit { try $0.makeSuperset(performedIDs) }
    }

    public func removeFromSuperset(_ performedID: UUID) throws { try edit { try $0.removeFromSuperset(performedID) } }

    /// Changes the session's name, notes, bodyweight or exercise notes.
    public func updateActiveSession(_ change: (inout WorkoutSession) -> Void) throws {
        try edit { change(&$0) }
    }

    /// Sets from the last performance of this exercise, to show beside the
    /// current ones.
    public func previousSets(for performedID: UUID) -> [PerformedSet] {
        guard let performed = activeSession?.exercises.first(where: { $0.id == performedID }) else { return [] }
        return history.lastPerformance(of: performed.exerciseID)?.sets ?? []
    }

    @discardableResult
    public func finishSession(discardIncompleteSets: Bool = true) throws -> SessionSummary {
        guard var session = activeSession else { throw StoreError.noActiveSession }
        session.finish(at: now(), discardIncompleteSets: discardIncompleteSets)
        try persistence.save(session)
        let records = history.records(in: session)
        history = TrainingHistory(sessions: history.sessions + [session], library: library)
        activeSession = nil
        restTimer = nil
        return SessionSummary(session: session, records: records)
    }

    public func discardSession() throws {
        guard let session = activeSession else { throw StoreError.noActiveSession }
        try persistence.deleteSession(session.id)
        activeSession = nil
        restTimer = nil
    }

    // MARK: Rest

    public func startRest(seconds: Double) { restTimer = RestTimer(startedAt: now(), duration: seconds) }
    public func extendRest(by seconds: Double) { restTimer?.extend(by: seconds) }
    public func skipRest() { restTimer = nil }

    // MARK: History

    /// Replaces a finished session, for corrections after the fact.
    public func saveSession(_ session: WorkoutSession) throws {
        guard session.isFinished, history.session(session.id) != nil else { throw StoreError.sessionNotFound(session.id) }
        try persistence.save(session)
        history = TrainingHistory(sessions: history.sessions.map { $0.id == session.id ? session : $0 }, library: library)
    }

    public func deleteSession(_ id: UUID) throws {
        guard history.session(id) != nil else { throw StoreError.sessionNotFound(id) }
        try persistence.deleteSession(id)
        history = TrainingHistory(sessions: history.sessions.filter { $0.id != id }, library: library)
    }

    // MARK: Library

    public func addCustomExercise(_ exercise: Exercise) throws {
        guard exercise.id.isCustom else { throw StoreError.invalidCustomExercise(["custom IDs start with custom-"]) }
        let updated: ExerciseLibrary
        do {
            updated = try library.adding(exercise)
        } catch let ExerciseLibrary.Error.invalid(_, problems) {
            throw StoreError.invalidCustomExercise(problems)
        } catch {
            throw StoreError.invalidCustomExercise(["\(error)"])
        }
        try persistence.save(exercise)
        library = updated
        history = TrainingHistory(sessions: history.sessions, library: updated)
    }

    // MARK: Private

    private func edit<T>(_ change: (inout WorkoutSession) throws -> T) throws -> T {
        guard var session = activeSession else { throw StoreError.noActiveSession }
        let result: T
        do {
            result = try change(&session)
        } catch let error as WorkoutSession.EditError {
            throw StoreError.edit(error)
        }
        try persistence.save(session)
        activeSession = session
        return result
    }
}
