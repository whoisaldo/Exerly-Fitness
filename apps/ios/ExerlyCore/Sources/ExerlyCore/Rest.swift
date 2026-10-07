import Foundation

/// Default rest between sets, in seconds. Longer rest for compound lifts
/// follows Schoenfeld et al. (2016) and Singer et al. (2024).
public struct RestPolicy: Sendable, Codable, Hashable {
    public var compoundUpper: Double = 150
    /// Also used for full-body lifts.
    public var compoundLower: Double = 180
    /// Isolation and core exercises.
    public var isolation: Double = 90
    public var warmUp: Double = 60
    /// After the first side of a unilateral pair.
    public var betweenSides: Double = 15
    /// After an exercise's last set, before the next exercise.
    public var betweenExercises: Double = 120

    public init() {}

    /// Rest for a set of this exercise, before any session context.
    public func rest(for exercise: Exercise, kind: SetKind, override: Double?) -> Double {
        if kind == .warmUp { return warmUp }
        if let override { return override }
        if exercise.category == .cardio { return 0 }
        switch (exercise.mechanics, exercise.region) {
        case (.compound, .upper): return compoundUpper
        case (.compound, .lower), (.compound, .fullBody): return compoundLower
        default: return isolation
        }
    }

    /// Rest after completing `setID`, given what comes next:
    /// - the other side of a unilateral pair: `betweenSides`;
    /// - the next member of a superset round: none;
    /// - a new superset round: the rest for the exercise that starts it;
    /// - a different exercise: `betweenExercises`;
    /// - otherwise the rest for this exercise and set.
    public func rest(after setID: UUID, in session: WorkoutSession, library: ExerciseLibrary) -> Double {
        guard let (performedID, set) = session.set(setID),
              let performed = session.exercises.first(where: { $0.id == performedID }),
              let exercise = library.exercise(performed.exerciseID)
        else { return 0 }
        let own = rest(for: exercise, kind: set.kind, override: performed.restOverride)
        guard let next = session.nextSet(after: setID),
              let nextPerformed = session.exercises.first(where: { $0.id == next.performedID }),
              let nextSet = session.set(next.setID)?.set
        else { return own }

        if next.performedID == performedID {
            if let side = set.side, nextSet.side == side.other, performed.sets.first?.side == side {
                return betweenSides
            }
            return own
        }
        if let group = performed.supersetID, nextPerformed.supersetID == group {
            let order = session.exercises.map(\.id)
            if order.firstIndex(of: next.performedID)! > order.firstIndex(of: performedID)! { return 0 }
            guard let nextExercise = library.exercise(nextPerformed.exerciseID) else { return own }
            return rest(for: nextExercise, kind: nextSet.kind, override: nextPerformed.restOverride)
        }
        return betweenExercises
    }
}

/// A countdown that survives backgrounding: time left comes from a clock.
public struct RestTimer: Sendable, Codable, Hashable {
    public var startedAt: Date
    /// Seconds.
    public var duration: Double

    public init(startedAt: Date, duration: Double) {
        self.startedAt = startedAt
        self.duration = max(0, duration)
    }

    public var endsAt: Date { startedAt.addingTimeInterval(duration) }
    public func remaining(at now: Date) -> Double { max(0, endsAt.timeIntervalSince(now)) }
    public func isFinished(at now: Date) -> Bool { now >= endsAt }
    public mutating func extend(by seconds: Double) { duration = max(0, duration + seconds) }
}
