import Foundation
@testable import ExerlyCore

/// Synthetic training data for tests. No real person's data.
enum Fixture {
    static let library = ExerciseLibrary.bundled
    static let utc = TimeZone(identifier: "UTC")!
    static let newYork = TimeZone(identifier: "America/New_York")!

    /// 2026-10-05 (a Monday) 18:00 UTC, plus `days` days.
    static func instant(days: Double = 0, minutes: Double = 0) -> Date {
        Date(timeIntervalSince1970: 1_791_223_200 + days * 86_400 + minutes * 60)
    }

    static func set(
        _ reps: Int, _ kg: Double? = nil, kind: SetKind = .standard, rir: Double? = nil,
        side: Side? = nil, done: Bool = true, at date: Date = instant()
    ) -> PerformedSet {
        PerformedSet(
            kind: kind, side: side, efforts: [Effort(reps: reps, load: kg.map { .kg($0) })],
            rir: rir, completedAt: done ? date : nil
        )
    }

    static func session(
        days: Double = 0, bodyweight: Double? = 80, zone: TimeZone = utc,
        _ exercises: [(ExerciseID, [PerformedSet])]
    ) -> WorkoutSession {
        WorkoutSession(
            name: "Session", startedAt: instant(days: days), endedAt: instant(days: days, minutes: 60),
            timeZone: zone, bodyweight: bodyweight.map { .kg($0) },
            exercises: exercises.map { PerformedExercise(exerciseID: $0.0, sets: $0.1) }
        )
    }
}

/// Floating-point comparison for derived quantities.
func close(_ value: Double?, _ expected: Double, tolerance: Double = 1e-9) -> Bool {
    guard let value else { return false }
    return abs(value - expected) <= tolerance * max(1, abs(expected))
}
