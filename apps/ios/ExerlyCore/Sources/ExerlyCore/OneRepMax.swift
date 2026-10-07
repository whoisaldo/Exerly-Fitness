import Foundation

/// Estimated one-rep max from a submaximal set.
///
/// Reps to failure is reps plus reps in reserve. Brzycki is used up to ten
/// reps to failure and Epley above; they meet exactly at ten (4/3 of the load),
/// so the curve is continuous, exact at one rep and invertible. Estimates past
/// 20 reps to failure are not made. See docs/design/002-exerlycore-training.md
/// for the measured error.
public enum OneRepMax {
    public enum Confidence: String, Sendable, Codable, Hashable {
        case high, moderate, low
    }

    public static let maximumRepsToFailure = 20.0

    public static func repsToFailure(reps: Int, rir: Double?) -> Double {
        Double(reps) + max(0, rir ?? 0)
    }

    /// The estimate in the load's unit, or nil when it would be meaningless.
    public static func estimate(load: Double, reps: Int, rir: Double? = nil) -> Double? {
        guard reps > 0 else { return nil }
        return estimate(load: load, repsToFailure: repsToFailure(reps: reps, rir: rir))
    }

    public static func estimate(load: Double, repsToFailure r: Double) -> Double? {
        guard load.isFinite, load > 0, r >= 1, r <= maximumRepsToFailure else { return nil }
        return r <= 10 ? load * 36 / (37 - r) : load * (1 + r / 30)
    }

    public static func estimate(_ load: Mass, reps: Int, rir: Double? = nil) -> Mass? {
        estimate(load: load.value, reps: reps, rir: rir).map { Mass($0, load.unit) }
    }

    /// The load expected to allow exactly `reps` reps to failure.
    public static func load(forReps r: Double, oneRepMax: Double) -> Double {
        r <= 10 ? oneRepMax * (37 - r) / 36 : oneRepMax / (1 + r / 30)
    }

    /// Reps to failure a load allows at an e1RM: the inverse of `estimate`.
    /// At least 1; loads under about 40 % of the e1RM give 30 or more.
    public static func repsToFailure(load: Double, oneRepMax: Double) -> Double {
        guard load > 0, oneRepMax > 0 else { return 30 }
        let brzycki = 37 - 36 * load / oneRepMax
        return brzycki <= 10 ? max(1, brzycki) : (oneRepMax / load - 1) * 30
    }

    public static func confidence(repsToFailure r: Double) -> Confidence {
        r <= 5 ? .high : r <= 10 ? .moderate : .low
    }
}
