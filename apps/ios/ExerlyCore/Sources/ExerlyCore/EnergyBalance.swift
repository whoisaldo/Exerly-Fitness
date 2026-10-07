import Foundation

/// Trend weight and expenditure from weigh-ins and logged intake. See
/// docs/design/007-nutrition.md, which records the error measured against
/// simulated people.
///
/// A Kalman filter and Rauch–Tung–Striebel smoother over three hidden states:
/// - `W`: weight without the day's water and gut contents, in kilograms;
/// - `E`: expenditure in logged kilocalories a day;
/// - `A`: the water and gut deviation, which the scale adds to `W`.
///
/// Each day `W` changes by intake minus `E`, divided by the energy density;
/// `E` drifts slowly; `A` decays toward zero. Days without complete logging
/// add uncertainty instead of intake. Expenditure is in the units the person
/// logs, so a steady under-logger still gets targets that work.
public enum EnergyBalance {
    public struct Parameters: Sendable, Hashable {
        /// Kilocalories per kilogram of tissue change.
        public var energyDensity = 7700.0
        /// Daily drift of expenditure, in kcal.
        public var expenditureDrift = 15.0
        /// How much expenditure changes per kilogram of tissue gained or lost,
        /// in kcal a day (Hall et al., 2011).
        public var expenditurePerKilogram = 22.0
        /// Daily unexplained change in weight, in kg.
        public var weightDrift = 0.01
        /// Water and gut swings, in kg, and how much of today's carries to tomorrow.
        public var water = 0.5
        public var waterPersistence = 0.8
        /// Scale error of one reading, in kg.
        public var scale = 0.15
        /// How far an unlogged day's intake may be from the recent average, in kcal.
        public var unloggedIntake = 600.0

        public init() {}
    }

    public struct Day: Sendable, Hashable {
        public var date: LocalDate
        /// Logged energy for a complete or fasting day; nil when the day isn't complete.
        public var intake: Double?
        /// Readings that day, in kilograms.
        public var weights: [Double]

        public init(date: LocalDate, intake: Double?, weights: [Double]) {
            self.date = date
            self.intake = intake
            self.weights = weights
        }
    }

    public struct Estimate: Sendable, Hashable {
        public var date: LocalDate
        /// Trend weight, in kilograms, with one standard deviation.
        public var trend: Double
        public var trendError: Double
        /// Expenditure, in logged kcal a day, with one standard deviation.
        public var expenditure: Double
        public var expenditureError: Double
        /// The day's mean reading, if any.
        public var weight: Double?
        public var intake: Double?
    }

    /// Smoothed estimates for every day from the first weigh-in on.
    /// `prior` is an expenditure guess (a formula's) and its standard deviation;
    /// without one it starts at 31 kcal per kilogram, ±600.
    public static func estimate(_ days: [Day], prior: (mean: Double, error: Double)? = nil,
                                parameters p: Parameters = Parameters()) -> [Estimate] {
        let sorted = days.sorted { $0.date < $1.date }
        guard let firstIndex = sorted.firstIndex(where: { !$0.weights.isEmpty }) else { return [] }
        // Fill gaps so every calendar day is a step.
        var series: [Day] = []
        for day in sorted[firstIndex...] {
            while let last = series.last, last.date.adding(days: 1) < day.date {
                series.append(Day(date: last.date.adding(days: 1), intake: nil, weights: []))
            }
            if series.last?.date == day.date {
                series[series.count - 1].weights += day.weights
                if let intake = day.intake { series[series.count - 1].intake = intake }
            } else {
                series.append(day)
            }
        }
        let firstWeight = mean(series[0].weights)!
        let start = prior ?? (31 * firstWeight, 600)
        var x = Vector(firstWeight, start.mean, 0)
        var P = Matrix.diagonal(p.water * p.water, start.error * start.error, p.water * p.water)
        // Expenditure follows weight: each day it moves by `expenditurePerKilogram`
        // times the day's tissue change, (intake − E) / density.
        let coupling = p.expenditurePerKilogram / p.energyDensity
        let F = Matrix([[1, -1 / p.energyDensity, 0], [0, 1 - coupling, 0], [0, 0, p.waterPersistence]])
        let intakeEffect = Vector(1 / p.energyDensity, coupling, 0)
        let waterNoise = p.water * p.water * (1 - p.waterPersistence * p.waterPersistence)

        var filtered: [(x: Vector, P: Matrix)] = []
        var predicted: [(x: Vector, P: Matrix)] = []
        var recentIntake: [Double] = []
        for (index, day) in series.enumerated() {
            if index > 0 {
                // Predict across the previous day's intake.
                let previous = series[index - 1]
                let intake: Double
                var intakeVariance = 0.0
                if let logged = previous.intake {
                    intake = logged
                    recentIntake = Array((recentIntake + [logged]).suffix(7))
                } else {
                    intake = mean(recentIntake) ?? x.e
                    intakeVariance = p.unloggedIntake * p.unloggedIntake
                }
                x = F * x + intakeEffect * intake
                P = F * P * F.transposed
                    + Matrix.diagonal(p.weightDrift * p.weightDrift, p.expenditureDrift * p.expenditureDrift, waterNoise)
                    + intakeEffect.outer(intakeEffect) * intakeVariance
            }
            predicted.append((x, P))
            if let reading = mean(day.weights) {
                // y = W + A, with the scale's error shrinking over several readings.
                let r = p.scale * p.scale / Double(day.weights.count)
                let innovation = reading - (x.w + x.a)
                let s = P[0, 0] + 2 * P[0, 2] + P[2, 2] + r
                let gain = Vector(P[0, 0] + P[0, 2], P[1, 0] + P[1, 2], P[2, 0] + P[2, 2]) / s
                x += gain * innovation
                let h = Vector(1, 0, 1)
                P = (Matrix.identity - gain.outer(h)) * P
                P = (P + P.transposed) * 0.5
            }
            filtered.append((x, P))
        }

        // Rauch–Tung–Striebel smoothing, backwards.
        var smoothed = filtered
        if series.count > 1 {
            for index in stride(from: series.count - 2, through: 0, by: -1) {
                let (xf, Pf) = filtered[index]
                let (xp, Pp) = predicted[index + 1]
                let gain = Pf * F.transposed * Pp.inverse
                let x = xf + gain * (smoothed[index + 1].x - xp)
                let P = Pf + gain * (smoothed[index + 1].P - Pp) * gain.transposed
                smoothed[index] = (x, (P + P.transposed) * 0.5)
            }
        }
        return series.indices.map { index in
            let (x, P) = smoothed[index]
            return Estimate(date: series[index].date, trend: x.w, trendError: max(0, P[0, 0]).squareRoot(),
                            expenditure: x.e, expenditureError: max(0, P[1, 1]).squareRoot(),
                            weight: mean(series[index].weights), intake: series[index].intake)
        }
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}

extension NutritionStore {
    /// The days `EnergyBalance` needs, from this store's weigh-ins and log.
    /// Only complete and fasting days count as known intake.
    public func energyBalanceDays(from start: LocalDate, through end: LocalDate) -> [EnergyBalance.Day] {
        guard start <= end else { return [] }
        var readings: [LocalDate: [Double]] = [:]
        for weight in weights where (start...end).contains(weight.date) {
            readings[weight.date, default: []].append(weight.weight.kilograms)
        }
        var energy: [LocalDate: Double] = [:]
        for entry in entries where (start...end).contains(entry.date) {
            energy[entry.date, default: 0] += entry.nutrients.energy
        }
        return (0...start.days(until: end)).map { offset in
            let date = start.adding(days: offset)
            let status = day(date).status
            let intake: Double? = switch status {
            case .complete: energy[date] ?? 0
            case .fasting: energy[date] ?? 0
            default: nil
            }
            return EnergyBalance.Day(date: date, intake: intake, weights: readings[date] ?? [])
        }
    }
}

// MARK: Small fixed-size linear algebra

struct Vector: Sendable {
    var values: [Double]
    init(_ w: Double, _ e: Double, _ a: Double) { values = [w, e, a] }
    init(values: [Double]) { self.values = values }
    var w: Double { values[0] }
    var e: Double { values[1] }
    var a: Double { values[2] }
    static func + (l: Vector, r: Vector) -> Vector { Vector(values: zip(l.values, r.values).map(+)) }
    static func += (l: inout Vector, r: Vector) { l = l + r }
    static func - (l: Vector, r: Vector) -> Vector { Vector(values: zip(l.values, r.values).map(-)) }
    static func * (l: Vector, s: Double) -> Vector { Vector(values: l.values.map { $0 * s }) }
    static func / (l: Vector, s: Double) -> Vector { Vector(values: l.values.map { $0 / s }) }
    func outer(_ other: Vector) -> Matrix { Matrix(values.map { a in other.values.map { a * $0 } }) }
}

struct Matrix: Sendable {
    var rows: [[Double]]
    init(_ rows: [[Double]]) { self.rows = rows }
    static let identity = Matrix([[1, 0, 0], [0, 1, 0], [0, 0, 1]])
    static func diagonal(_ a: Double, _ b: Double, _ c: Double) -> Matrix { Matrix([[a, 0, 0], [0, b, 0], [0, 0, c]]) }
    subscript(_ i: Int, _ j: Int) -> Double { rows[i][j] }
    var transposed: Matrix { Matrix((0..<3).map { j in (0..<3).map { rows[$0][j] } }) }
    static func + (l: Matrix, r: Matrix) -> Matrix { Matrix(zip(l.rows, r.rows).map { zip($0, $1).map(+) }) }
    static func - (l: Matrix, r: Matrix) -> Matrix { Matrix(zip(l.rows, r.rows).map { zip($0, $1).map(-) }) }
    static func * (l: Matrix, s: Double) -> Matrix { Matrix(l.rows.map { $0.map { $0 * s } }) }
    static func * (l: Matrix, r: Matrix) -> Matrix {
        Matrix((0..<3).map { i in (0..<3).map { j in (0..<3).reduce(0) { $0 + l.rows[i][$1] * r.rows[$1][j] } } })
    }
    static func * (l: Matrix, v: Vector) -> Vector {
        Vector(values: (0..<3).map { i in (0..<3).reduce(0) { $0 + l.rows[i][$1] * v.values[$1] } })
    }
    var inverse: Matrix {
        let m = rows
        let det = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
            + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
        let c: [[Double]] = [
            [m[1][1] * m[2][2] - m[1][2] * m[2][1], m[0][2] * m[2][1] - m[0][1] * m[2][2], m[0][1] * m[1][2] - m[0][2] * m[1][1]],
            [m[1][2] * m[2][0] - m[1][0] * m[2][2], m[0][0] * m[2][2] - m[0][2] * m[2][0], m[0][2] * m[1][0] - m[0][0] * m[1][2]],
            [m[1][0] * m[2][1] - m[1][1] * m[2][0], m[0][1] * m[2][0] - m[0][0] * m[2][1], m[0][0] * m[1][1] - m[0][1] * m[1][0]],
        ]
        return Matrix(c) * (1 / det)
    }
}
