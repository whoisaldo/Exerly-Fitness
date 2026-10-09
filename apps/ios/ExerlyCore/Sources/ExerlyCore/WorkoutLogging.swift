import Foundation

extension LoadIncrements {
    /// The next load up or down from `value` for this equipment, in `unit`.
    ///
    /// With `available` weights, the next one listed. Otherwise the next load
    /// on the step grid, which starts at the minimum (an empty bar) or zero,
    /// so an off-grid load snaps onto it: 61 kg goes up to 62.5 and down to
    /// 60, and 135 lb with 5 lb plates goes up to 145 on a 45 lb bar. Stepping
    /// down stops at the minimum. A minimum in the other unit is rounded to the
    /// nearest step, so a 20 kg bar reads 45 lb. Never below zero.
    public func stepped(_ value: Double, up: Bool, in unit: MassUnit) -> Double {
        let current = value.isFinite ? max(0, value) : 0
        let tolerance = 1e-6
        if let available, !available.isEmpty {
            let weights = Array(Set(available.map { Self.clean($0.value(in: unit)) })).sorted()
            if up { return weights.first { $0 > current + tolerance } ?? max(current, weights.last ?? current) }
            return weights.last { $0 < current - tolerance } ?? min(current, weights.first ?? current)
        }
        let step = self.step(in: unit)
        guard step > 0 else { return current }
        let anchor = minimum.map { $0.unit == unit ? $0.value : ($0.value(in: unit) / step).rounded() * step } ?? 0
        if current < anchor - tolerance {
            // Below the minimum: up goes to it, down steps toward zero.
            return Self.clean(up ? anchor : max(0, ((current / step - tolerance).rounded(.up) - 1) * step))
        }
        let position = (current - anchor) / step
        let index = up ? (position + tolerance).rounded(.down) + 1 : max(0, (position - tolerance).rounded(.up) - 1)
        return Self.clean(anchor + index * step)
    }

    private static func clean(_ value: Double) -> Double { (value * 1_000_000).rounded() / 1_000_000 }
}

extension WorkoutPlan {
    /// Seconds the workout should take: each set's work plus the rest the
    /// policy gives after it, in the order the sets are done, with no rest
    /// after the last. A set's work is its planned duration when it has one,
    /// otherwise `secondsPerSet`.
    public func estimatedDuration(library: ExerciseLibrary, policy: RestPolicy = RestPolicy(),
                                  secondsPerSet: Double = 45) -> Double {
        let session = WorkoutSession(exercises: exercises.map { planned in
            PerformedExercise(exerciseID: planned.exerciseID,
                              sets: planned.recommendation.sets.map { PerformedSet(kind: $0.kind, efforts: [$0.effort], rir: $0.rir) },
                              supersetID: planned.supersetID, restOverride: planned.target.rest)
        })
        let order = session.performanceOrder
        return order.enumerated().reduce(0) { total, item in
            let (index, position) = item
            let effort = session.set(position.setID)?.set.primary
            let work = (effort?.duration ?? 0) > 0 ? effort!.duration! : secondsPerSet
            let rest = index < order.count - 1 ? policy.rest(after: position.setID, in: session, library: library) : 0
            return total + work + rest
        }
    }
}
