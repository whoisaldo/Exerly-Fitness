import Foundation

/// A completed, non-warm-up set with the context needed to analyse it.
public struct SetRecord: Sendable, Hashable {
    public var sessionID: UUID
    public var performedID: UUID
    public var date: LocalDate
    public var sessionStart: Date
    public var set: PerformedSet
    public var bodyweight: Mass?
}

/// Every metric in MacroFactor's exercise export. Loads are in kilograms;
/// volume is in kilogram-reps; duration in seconds; distance in metres.
public struct ExerciseStatistics: Sendable, Hashable {
    public var estimatedOneRepMax: Mass?
    public var estimatedThreeRepMax: Mass?
    public var estimatedTenRepMax: Mass?
    public var totalVolume: Double = 0
    /// False when a bodyweight exercise was logged without a known bodyweight,
    /// so the volume figures leave that bodyweight out.
    public var isVolumeComplete = true
    public var bestSetVolume: Double = 0
    public var heaviestLoad: Mass?
    public var totalReps = 0
    public var bestSetReps = 0
    public var totalDuration: Double = 0
    public var bestSetDuration: Double = 0
    public var totalDistance: Double = 0
    public var bestSetDistance: Double = 0
    public var totalSets = 0

    public init(exercise: Exercise, sets: [SetRecord]) {
        var bestE1RM: Double?
        var heaviest: Double?
        for record in sets {
            let set = record.set
            totalSets += 1
            totalReps += set.totalReps
            bestSetReps = max(bestSetReps, set.totalReps)
            totalDuration += set.totalDuration
            bestSetDuration = max(bestSetDuration, set.totalDuration)
            totalDistance += set.totalDistance
            bestSetDistance = max(bestSetDistance, set.totalDistance)
            let tonnage = Volume.tonnage(set, exercise: exercise, bodyweight: record.bodyweight)
            let volume = tonnage.total
            isVolumeComplete = isVolumeComplete && tonnage.isComplete
            totalVolume += volume
            bestSetVolume = max(bestSetVolume, volume)
            if let load = Volume.effectiveLoad(set.primary, exercise: exercise, bodyweight: record.bodyweight),
               exercise.metric.tracksLoad {
                heaviest = max(heaviest ?? load, load)
            }
            if let e1rm = Self.oneRepMax(set, exercise: exercise, bodyweight: record.bodyweight) {
                bestE1RM = max(bestE1RM ?? e1rm, e1rm)
            }
        }
        heaviestLoad = heaviest.map(Mass.kg)
        if let bestE1RM {
            estimatedOneRepMax = .kg(bestE1RM)
            estimatedThreeRepMax = .kg(OneRepMax.load(forReps: 3, oneRepMax: bestE1RM))
            estimatedTenRepMax = .kg(OneRepMax.load(forReps: 10, oneRepMax: bestE1RM))
        }
    }

    /// e1RM in kilograms from a set's primary effort.
    static func oneRepMax(_ set: PerformedSet, exercise: Exercise, bodyweight: Mass?) -> Double? {
        guard exercise.metric.tracksReps, let reps = set.primary.reps,
              let load = Volume.effectiveLoad(set.primary, exercise: exercise, bodyweight: bodyweight)
        else { return nil }
        return OneRepMax.estimate(load: load, reps: reps, rir: set.effectiveRIR)
    }
}

public struct PersonalRecord: Sendable, Hashable {
    public enum Kind: String, Sendable, Codable, Hashable, CaseIterable {
        /// Value in kilograms.
        case oneRepMax, heaviestLoad
        /// Value in kilogram-reps.
        case setVolume
        /// Reps at `load` or heavier; value in reps.
        case repsAtLoad
        /// Value in seconds.
        case duration
        /// Value in metres.
        case distance
    }

    public var kind: Kind
    public var exerciseID: ExerciseID
    public var sessionID: UUID
    public var setID: UUID
    public var value: Double
    public var previous: Double
    /// The load for a reps-at-load record, in kilograms.
    public var load: Mass?

    /// The one record per exercise worth announcing after a workout: a
    /// heavier weight first, then a higher estimated 1RM, then more reps at a
    /// weight, then the rest. Exercises keep the order the records came in.
    public static func headlines(_ records: [PersonalRecord]) -> [PersonalRecord] {
        let rank: [Kind: Int] = [.heaviestLoad: 0, .oneRepMax: 1, .repsAtLoad: 2, .setVolume: 3, .duration: 4, .distance: 5]
        var best: [ExerciseID: PersonalRecord] = [:]
        var order: [ExerciseID] = []
        for record in records {
            guard let current = best[record.exerciseID] else {
                best[record.exerciseID] = record
                order.append(record.exerciseID)
                continue
            }
            if rank[record.kind, default: .max] < rank[current.kind, default: .max] { best[record.exerciseID] = record }
        }
        return order.compactMap { best[$0] }
    }
}

/// The analysable view of every session. Build a new one after a change; it
/// indexes sets by exercise once.
public struct TrainingHistory: Sendable {
    public let library: ExerciseLibrary
    /// Sorted by start time, earliest first.
    public let sessions: [WorkoutSession]
    private let setsByExercise: [ExerciseID: [SetRecord]]

    public init(sessions: [WorkoutSession], library: ExerciseLibrary) {
        self.library = library
        self.sessions = sessions.sorted { ($0.startedAt, $0.id.uuidString) < ($1.startedAt, $1.id.uuidString) }
        var index: [ExerciseID: [SetRecord]] = [:]
        for session in self.sessions {
            let date = session.localDate
            for performed in session.exercises {
                for set in performed.sets where set.counts {
                    index[performed.exerciseID, default: []].append(SetRecord(
                        sessionID: session.id, performedID: performed.id, date: date,
                        sessionStart: session.startedAt, set: set, bodyweight: session.bodyweight
                    ))
                }
            }
        }
        setsByExercise = index
    }

    public func session(_ id: UUID) -> WorkoutSession? {
        sessions.first { $0.id == id }
    }

    /// The most recent performance of an exercise in a session that started
    /// before `date`, skipping `excluding`.
    public func lastPerformance(of exerciseID: ExerciseID, before date: Date? = nil, excluding sessionID: UUID? = nil) -> PerformedExercise? {
        for session in sessions.reversed() {
            if let date, session.startedAt >= date { continue }
            if session.id == sessionID { continue }
            if let performed = session.exercises.last(where: { $0.exerciseID == exerciseID && $0.sets.contains(where: \.isCompleted) }) {
                return performed
            }
        }
        return nil
    }

    /// Completed working sets of an exercise, oldest first, within an optional
    /// inclusive range of local dates.
    public func sets(of exerciseID: ExerciseID, from start: LocalDate? = nil, through end: LocalDate? = nil) -> [SetRecord] {
        let all = setsByExercise[exerciseID] ?? []
        guard start != nil || end != nil else { return all }
        return all.filter { record in
            (start.map { record.date >= $0 } ?? true) && (end.map { record.date <= $0 } ?? true)
        }
    }

    public func statistics(of exerciseID: ExerciseID, from start: LocalDate? = nil, through end: LocalDate? = nil) -> ExerciseStatistics? {
        guard let exercise = library.exercise(exerciseID) else { return nil }
        let sets = sets(of: exerciseID, from: start, through: end)
        return sets.isEmpty ? nil : ExerciseStatistics(exercise: exercise, sets: sets)
    }

    /// The best e1RM of each session that has one, oldest first.
    public func oneRepMaxTrend(of exerciseID: ExerciseID) -> [(date: LocalDate, sessionID: UUID, oneRepMax: Mass)] {
        guard let exercise = library.exercise(exerciseID) else { return [] }
        var trend: [(date: LocalDate, sessionID: UUID, oneRepMax: Mass)] = []
        for record in sets(of: exerciseID) {
            guard let e1rm = ExerciseStatistics.oneRepMax(record.set, exercise: exercise, bodyweight: record.bodyweight) else { continue }
            if trend.last?.sessionID == record.sessionID {
                trend[trend.count - 1].oneRepMax = .kg(max(trend[trend.count - 1].oneRepMax.kilograms, e1rm))
            } else {
                trend.append((record.date, record.sessionID, .kg(e1rm)))
            }
        }
        return trend
    }

    /// Records set in `session`, compared with every session that started
    /// earlier. An exercise's first session sets none. Each kind is reported
    /// once per exercise, for its best set; reps-at-load once per set.
    public func records(in session: WorkoutSession) -> [PersonalRecord] {
        var records: [PersonalRecord] = []
        var seen = Set<ExerciseID>()
        for performed in session.exercises where seen.insert(performed.exerciseID).inserted {
            guard let exercise = library.exercise(performed.exerciseID) else { continue }
            let earlier = sets(of: exercise.id).filter { $0.sessionStart < session.startedAt && $0.sessionID != session.id }
            guard !earlier.isEmpty else { continue }
            let current = session.exercises
                .filter { $0.exerciseID == exercise.id }
                .flatMap(\.sets)
                .filter(\.counts)
            let bw = session.bodyweight

            let measures: [(PersonalRecord.Kind, (PerformedSet, Mass?) -> Double?)] = [
                (.oneRepMax, { ExerciseStatistics.oneRepMax($0, exercise: exercise, bodyweight: $1) }),
                (.heaviestLoad, { set, body in
                    exercise.metric.tracksLoad ? Volume.effectiveLoad(set.primary, exercise: exercise, bodyweight: body) : nil
                }),
                (.setVolume, { set, body in
                    let tonnage = Volume.tonnage(set, exercise: exercise, bodyweight: body)
                    return exercise.metric.tracksReps && tonnage.isComplete && tonnage.total > 0 ? tonnage.total : nil
                }),
                (.duration, { set, _ in exercise.metric.tracksDuration && set.totalDuration > 0 ? set.totalDuration : nil }),
                (.distance, { set, _ in exercise.metric.tracksDistance && set.totalDistance > 0 ? set.totalDistance : nil }),
            ]
            for (kind, measure) in measures {
                let previous = earlier.compactMap { measure($0.set, $0.bodyweight) }.max()
                let candidates = current.compactMap { set in measure(set, bw).map { (set, $0) } }
                guard let previous, let top = candidates.max(by: { $0.1 < $1.1 }), top.1 > previous + 1e-9 else { continue }
                records.append(PersonalRecord(kind: kind, exerciseID: exercise.id, sessionID: session.id,
                                              setID: top.0.id, value: top.1, previous: previous))
            }

            guard exercise.metric.tracksReps else { continue }
            var repRecords: [PersonalRecord] = []
            for set in current {
                guard let reps = set.primary.reps,
                      let load = Volume.effectiveLoad(set.primary, exercise: exercise, bodyweight: bw), load > 0
                else { continue }
                let previous = earlier.compactMap { record -> Int? in
                    guard let earlierLoad = Volume.effectiveLoad(record.set.primary, exercise: exercise, bodyweight: record.bodyweight),
                          earlierLoad >= load - 1e-9
                    else { return nil }
                    return record.set.primary.reps
                }.max()
                // One record per load: the set with the most reps.
                if let previous, reps > previous,
                   !repRecords.contains(where: { $0.load == .kg(load) && $0.value >= Double(reps) }) {
                    repRecords.removeAll { $0.load == .kg(load) }
                    repRecords.append(PersonalRecord(kind: .repsAtLoad, exerciseID: exercise.id, sessionID: session.id,
                                                     setID: set.id, value: Double(reps), previous: Double(previous), load: .kg(load)))
                }
            }
            records += repRecords
        }
        return records
    }

    /// Volume per muscle for each week, keyed by the week's first local date.
    public func weeklyMuscleVolume(firstWeekday: Weekday) -> [LocalDate: [Muscle: MuscleVolume]] {
        Volume.weeklyByMuscle(sessions, library: library, firstWeekday: firstWeekday)
    }

    /// Volume per muscle for sessions whose local date is in the inclusive range.
    public func muscleVolume(from start: LocalDate, through end: LocalDate) -> [Muscle: MuscleVolume] {
        Volume.byMuscle(sessions.filter { (start...end).contains($0.localDate) }, library: library)
    }
}
