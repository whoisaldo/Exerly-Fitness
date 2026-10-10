import ExerlyCore
import Foundation

/// The Live Activity's view of the workout in progress: its title, sets done,
/// rest while it runs, and the next set with its values in the person's unit.
struct WorkoutActivityContent: Equatable, Sendable {
    var workoutID: UUID
    var state: WorkoutActivityAttributes.ContentState

    @MainActor
    init?(store: TrainingStore, unit: MassUnit, now: Date = .now) {
        guard let session = store.activeSession else { return nil }
        self.init(session: session, rest: store.restTimer, library: store.library, unit: unit, now: now)
    }

    init(session: WorkoutSession, rest: RestTimer?, library: ExerlyCore.ExerciseLibrary, unit: MassUnit, now: Date) {
        let title = TrainingFormat.title(of: session)
        let sets = session.exercises.flatMap(\.sets)
        workoutID = session.id
        state = .init(title: title.name, program: title.program, startedAt: session.startedAt,
                      completedSets: sets.filter(\.isCompleted).count, totalSets: sets.count,
                      rest: rest.flatMap { $0.isFinished(at: now) ? nil : .init(startedAt: $0.startedAt, endsAt: $0.endsAt) },
                      next: Self.next(in: session, library: library, unit: unit))
    }

    private static func next(in session: WorkoutSession, library: ExerlyCore.ExerciseLibrary, unit: MassUnit) -> WorkoutActivityAttributes.NextSet? {
        guard let position = session.nextSet(after: nil),
              let performed = session.exercises.first(where: { $0.id == position.performedID }),
              let index = performed.sets.firstIndex(where: { $0.id == position.setID }),
              let exercise = library.exercise(performed.exerciseID)
        else { return nil }
        let set = performed.sets[index]
        let values = Self.values(set, metric: exercise.metric, unit: unit)
        return .init(setID: set.id, exercise: exercise.name, number: index + 1, values: values.text,
                     spokenValues: values.spoken, isLoggable: set.isLoggable(for: exercise))
    }

    /// A set's values with their unit, as written and as spoken:
    /// ("160 lb × 7", "160 pounds, 7 reps"), ("BW × 9", "bodyweight, 9 reps").
    static func values(_ set: PerformedSet, metric: TrackingMetric, unit: MassUnit) -> (text: String, spoken: String) {
        typealias Part = (text: String, spoken: String)
        let effort = set.primary
        let load: Part? = effort.load.map {
            (TrainingFormat.mass($0, unit: unit), "\(TrainingFormat.load($0.value(in: unit))) \(unit == .kilograms ? "kilograms" : "pounds")")
        }
        let reps: Part = effort.reps.map { ("\($0)", "\($0) \($0 == 1 ? "rep" : "reps")") } ?? ("–", "reps not set")
        let duration: Part? = effort.duration.map { ("\(TrainingFormat.number($0)) s", "\(TrainingFormat.number($0)) seconds") }
        let distance: Part? = effort.distance.map { ("\(TrainingFormat.number($0)) m", "\(TrainingFormat.number($0)) metres") }
        let unset: Part = ("–", "not set")
        var parts: Part
        switch metric {
        case .weightReps:
            let weight = load ?? ("–", "weight not set")
            parts = ("\(weight.text) × \(reps.text)", "\(weight.spoken), \(reps.spoken)")
        case .bodyweightReps:
            parts = ("\(load.map { "+" + $0.text } ?? "BW") × \(reps.text)",
                     "bodyweight\(load.map { " plus " + $0.spoken } ?? ""), \(reps.spoken)")
        case .assistedReps:
            parts = ("\(load.map { "−" + $0.text } ?? "BW") × \(reps.text)",
                     "\(load.map { $0.spoken + " assistance" } ?? "bodyweight"), \(reps.spoken)")
        case .duration:
            parts = duration ?? unset
        case .weightDuration:
            let all = [load ?? unset, duration ?? unset]
            parts = (all.map(\.text).joined(separator: " · "), all.map(\.spoken).joined(separator: ", "))
        case .distanceDuration:
            let all = [distance, duration].compactMap { $0 }
            parts = all.isEmpty ? unset : (all.map(\.text).joined(separator: " · "), all.map(\.spoken).joined(separator: ", "))
        case .weightDistance:
            let all = [load ?? unset, distance ?? unset]
            parts = (all.map(\.text).joined(separator: " · "), all.map(\.spoken).joined(separator: ", "))
        }
        if set.efforts.count > 1 {
            parts.text += " +\(set.efforts.count - 1)"
            parts.spoken += ", then \(set.efforts.count - 1) more"
        }
        return parts
    }
}
