import Foundation

/// Load times reps, in kilogram-reps, split the way MacroFactor charts it.
public struct Tonnage: Sendable, Codable, Hashable {
    /// From external or added load.
    public var resistance: Double
    /// From the share of bodyweight that bodyweight exercises move.
    public var bodyweight: Double
    /// False when a bodyweight exercise was logged without a known bodyweight,
    /// so its bodyweight share is missing from the total.
    public var isComplete: Bool

    public init(resistance: Double = 0, bodyweight: Double = 0, isComplete: Bool = true) {
        self.resistance = resistance
        self.bodyweight = bodyweight
        self.isComplete = isComplete
    }

    public static let zero = Tonnage()
    public var total: Double { resistance + bodyweight }

    public static func + (lhs: Tonnage, rhs: Tonnage) -> Tonnage {
        Tonnage(resistance: lhs.resistance + rhs.resistance, bodyweight: lhs.bodyweight + rhs.bodyweight,
                isComplete: lhs.isComplete && rhs.isComplete)
    }

    public static func += (lhs: inout Tonnage, rhs: Tonnage) { lhs = lhs + rhs }

    /// Totals for display in kilogram-reps or pound-reps.
    public func total(in unit: MassUnit) -> Double { total / unit.kilogramsPerUnit }
    public func resistance(in unit: MassUnit) -> Double { resistance / unit.kilogramsPerUnit }
    public func bodyweight(in unit: MassUnit) -> Double { bodyweight / unit.kilogramsPerUnit }

    public func scaled(by factor: Double) -> Tonnage {
        Tonnage(resistance: resistance * factor, bodyweight: bodyweight * factor, isComplete: isComplete)
    }
}

public struct MuscleVolume: Sendable, Codable, Hashable {
    /// Fractional hard sets: a target set counts 1, a synergist set 0.5.
    public var sets: Double
    public var tonnage: Tonnage

    public init(sets: Double = 0, tonnage: Tonnage = .zero) {
        self.sets = sets
        self.tonnage = tonnage
    }
}

public enum Volume {
    /// Kilograms moved per rep, or nil when unknown or not a load metric.
    public static func effectiveLoad(_ effort: Effort, exercise: Exercise, bodyweight: Mass?) -> Double? {
        let parts = loadParts(effort, exercise: exercise, bodyweight: bodyweight)
        guard let resistance = parts.resistance, let body = parts.bodyweight else { return nil }
        return resistance + body
    }

    /// Resistance and bodyweight components in kilograms. A nil component is unknown.
    static func loadParts(_ effort: Effort, exercise: Exercise, bodyweight: Mass?) -> (resistance: Double?, bodyweight: Double?) {
        let added = effort.load?.kilograms
        let body = bodyweight.map { $0.kilograms * exercise.bodyweightShare }
        switch exercise.metric {
        case .weightReps, .weightDuration, .weightDistance:
            return (added, 0)
        case .bodyweightReps:
            return (added ?? 0, exercise.bodyweightShare == 0 ? 0 : body)
        case .assistedReps:
            return (0, body.map { max(0, $0 - (added ?? 0)) })
        case .duration, .distanceDuration:
            return (nil, nil)
        }
    }

    /// Tonnage of a set, counting every effort. Only rep-based metrics have tonnage.
    public static func tonnage(_ set: PerformedSet, exercise: Exercise, bodyweight: Mass?) -> Tonnage {
        guard exercise.metric.tracksReps else { return .zero }
        var result = Tonnage.zero
        for effort in set.efforts {
            let reps = Double(effort.reps ?? 0)
            guard reps > 0 else { continue }
            let parts = loadParts(effort, exercise: exercise, bodyweight: bodyweight)
            result.resistance += (parts.resistance ?? 0) * reps
            if let body = parts.bodyweight {
                result.bodyweight += body * reps
            } else {
                result.isComplete = false
            }
        }
        return result
    }

    /// How much one set counts toward set totals: 0 for warm-ups, incomplete
    /// sets and cardio, 0.5 for one side of a unilateral exercise, otherwise 1.
    public static func setCredit(_ set: PerformedSet, exercise: Exercise) -> Double {
        guard set.counts, exercise.category == .strength else { return 0 }
        return exercise.laterality == .unilateral && set.side != nil ? 0.5 : 1
    }

    public static func byMuscle(_ sessions: [WorkoutSession], library: ExerciseLibrary) -> [Muscle: MuscleVolume] {
        var result: [Muscle: MuscleVolume] = [:]
        for session in sessions {
            accumulate(session, library: library, into: &result)
        }
        return result
    }

    /// Volume per muscle, keyed by the local date each week starts on.
    public static func weeklyByMuscle(
        _ sessions: [WorkoutSession], library: ExerciseLibrary, firstWeekday: Weekday
    ) -> [LocalDate: [Muscle: MuscleVolume]] {
        var weeks: [LocalDate: [Muscle: MuscleVolume]] = [:]
        for session in sessions {
            let week = session.localDate.startOfWeek(firstWeekday: firstWeekday)
            accumulate(session, library: library, into: &weeks[week, default: [:]])
        }
        return weeks
    }

    private static func accumulate(_ session: WorkoutSession, library: ExerciseLibrary, into result: inout [Muscle: MuscleVolume]) {
        for performed in session.exercises {
            guard let exercise = library.exercise(performed.exerciseID) else { continue }
            for set in performed.sets {
                let credit = setCredit(set, exercise: exercise)
                guard credit > 0 else { continue }
                let tonnage = tonnage(set, exercise: exercise, bodyweight: session.bodyweight)
                for (muscle, share) in exercise.muscles {
                    var volume = result[muscle, default: MuscleVolume()]
                    volume.sets += credit * share
                    volume.tonnage += tonnage.scaled(by: share)
                    result[muscle] = volume
                }
            }
        }
    }
}

/// Totals for one session, so screens never add sets up themselves.
public struct WorkoutSummary: Sendable, Hashable {
    public var exerciseCount: Int
    public var totalSets: Int
    public var completedSets: Int
    /// Completed sets that aren't warm-ups.
    public var workingSets: Int
    /// Seconds from the start to the end, or to `now` while in progress.
    public var duration: Double
    public var tonnage: Tonnage
    public var muscles: [Muscle: MuscleVolume]

    public init(session: WorkoutSession, library: ExerciseLibrary, at now: Date) {
        let sets = session.exercises.flatMap(\.sets)
        exerciseCount = session.exercises.count
        totalSets = sets.count
        completedSets = sets.filter(\.isCompleted).count
        workingSets = sets.filter(\.counts).count
        duration = max(0, (session.endedAt ?? now).timeIntervalSince(session.startedAt))
        var tonnage = Tonnage.zero
        for performed in session.exercises {
            guard let exercise = library.exercise(performed.exerciseID) else { continue }
            for set in performed.sets where set.counts {
                tonnage += Volume.tonnage(set, exercise: exercise, bodyweight: session.bodyweight)
            }
        }
        self.tonnage = tonnage
        muscles = Volume.byMuscle([session], library: library)
    }
}
