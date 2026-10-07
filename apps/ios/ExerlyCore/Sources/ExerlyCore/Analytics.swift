import Foundation

/// Correlations between daily series and two-phase n=1 experiments, with
/// honest uncertainty. Days in a row aren't independent, so every interval and
/// p-value uses an effective sample size adjusted for autocorrelation. See
/// docs/design/014-analytics.md for the measured error rates.
public enum Analytics {
    public enum Verdict: String, Sendable, Hashable {
        case notEnoughData, noClearDifference, clearIncrease, clearDecrease
        case noClearAssociation, clearPositive, clearNegative
    }

    public static let minimumPairs = 14
    public static let minimumPhaseDays = 7

    public struct Correlation: Sendable, Hashable {
        /// Days `y` is shifted after `x`: 1 compares today's `x` with tomorrow's `y`.
        public var lag: Int
        public var pairs: Int
        /// Spearman's rank correlation, -1 to 1.
        public var rho: Double
        /// A 95 % interval for `rho`.
        public var low: Double
        public var high: Double
        public var p: Double
        /// After Benjamini–Hochberg across everything tested together.
        public var adjustedP: Double
        public var verdict: Verdict
    }

    public struct Comparison: Sendable, Hashable {
        public var baselineMean: Double
        public var baselineDays: Int
        public var interventionMean: Double
        public var interventionDays: Int
        /// Intervention minus baseline, with a 95 % interval.
        public var difference: Double
        public var low: Double
        public var high: Double
        /// The difference over the pooled standard deviation.
        public var standardized: Double
        public var verdict: Verdict
    }

    // MARK: Correlation

    /// Correlations of `x` with `y` at each lag, adjusted together. Fewer than
    /// `minimumPairs` paired days is "not enough data".
    public static func correlations(_ x: [LocalDate: Double], _ y: [LocalDate: Double],
                                    lags: ClosedRange<Int> = 0...3) -> [Correlation] {
        adjusted(lags.map { lag in correlation(x, y, lag: lag) })
    }

    /// Benjamini–Hochberg over a set of correlations tested together; verdicts follow.
    public static func adjusted(_ tested: [Correlation]) -> [Correlation] {
        let adjustedP = benjaminiHochberg(tested.map(\.p))
        return zip(tested, adjustedP).map { correlation, p in
            var result = correlation
            guard result.verdict != .notEnoughData else { return result }
            result.adjustedP = p
            let excludesZero = result.low > 0 || result.high < 0
            result.verdict = p < 0.05 && excludesZero ? (result.rho > 0 ? .clearPositive : .clearNegative) : .noClearAssociation
            return result
        }
    }

    static func correlation(_ x: [LocalDate: Double], _ y: [LocalDate: Double], lag: Int) -> Correlation {
        let dates = x.keys.sorted().filter { y[$0.adding(days: lag)] != nil }
        let xs = dates.map { x[$0]! }, ys = dates.map { y[$0.adding(days: lag)]! }
        let rho = xs.count >= minimumPairs ? spearman(xs, ys) : .nan
        guard rho.isFinite else {
            return Correlation(lag: lag, pairs: dates.count, rho: .nan, low: .nan, high: .nan, p: 1, adjustedP: 1, verdict: .notEnoughData)
        }
        // Two autocorrelated series carry fewer independent pairs (Bartlett).
        let r = lagOneAutocorrelation(xs) * lagOneAutocorrelation(ys)
        let effective = max(4, Double(xs.count) * (1 - r) / (1 + r))
        let t = rho * ((effective - 2) / max(1e-12, 1 - rho * rho)).squareRoot()
        let p = min(1, max(0, 2 * (1 - studentT(abs(t), degrees: effective - 2))))
        // Fisher's z interval on the effective size.
        let z = atanh(min(0.999_999, max(-0.999_999, rho))), spread = 1.96 / (effective - 3).squareRoot()
        return Correlation(lag: lag, pairs: xs.count, rho: rho, low: tanh(z - spread), high: tanh(z + spread),
                           p: p, adjustedP: p, verdict: .noClearAssociation)
    }

    // MARK: Experiments

    /// The intervention phase against the baseline, by Welch's interval with
    /// each phase's variance inflated for its autocorrelation. Each phase needs
    /// `minimumPhaseDays` values, in date order.
    public static func compare(baseline: [Double], intervention: [Double]) -> Comparison {
        let a = mean(baseline), b = mean(intervention)
        let pooled = ((variance(baseline) * Double(max(0, baseline.count - 1)) + variance(intervention) * Double(max(0, intervention.count - 1)))
            / Double(max(1, baseline.count + intervention.count - 2))).squareRoot()
        var comparison = Comparison(baselineMean: a, baselineDays: baseline.count, interventionMean: b,
                                    interventionDays: intervention.count, difference: b - a, low: .nan, high: .nan,
                                    standardized: pooled > 0 ? (b - a) / pooled : 0, verdict: .notEnoughData)
        guard baseline.count >= minimumPhaseDays, intervention.count >= minimumPhaseDays else { return comparison }
        let first = meanVariance(baseline), second = meanVariance(intervention)
        let error = (first.variance + second.variance).squareRoot()
        let denominator = first.variance * first.variance / (first.effective - 1) + second.variance * second.variance / (second.effective - 1)
        let degrees = denominator > 0 ? pow(first.variance + second.variance, 2) / denominator : first.effective + second.effective - 2
        let spread = studentTQuantile(0.975, degrees: max(1, degrees)) * error
        comparison.low = b - a - spread
        comparison.high = b - a + spread
        comparison.verdict = comparison.low > 0 ? .clearIncrease : comparison.high < 0 ? .clearDecrease : .noClearDifference
        return comparison
    }

    /// The variance of a phase's mean and its effective size, for AR(1) persistence.
    /// A short series underestimates its autocorrelation by about (1 + 3r)/n,
    /// so the estimate is corrected before it inflates the variance.
    static func meanVariance(_ values: [Double]) -> (variance: Double, effective: Double) {
        let estimate = lagOneAutocorrelation(values)
        let r = min(0.9, estimate + (1 + 3 * estimate) / Double(values.count))
        let effective = max(2, Double(values.count) * (1 - r) / (1 + r))
        return (variance(values) / effective, effective)
    }

    // MARK: Pieces

    /// Spearman's rho: Pearson's correlation of the ranks, ties averaged.
    static func spearman(_ x: [Double], _ y: [Double]) -> Double { pearson(ranks(x), ranks(y)) }

    static func ranks(_ values: [Double]) -> [Double] {
        let order = values.indices.sorted { values[$0] < values[$1] }
        var result = [Double](repeating: 0, count: values.count)
        var start = 0
        while start < order.count {
            var end = start
            while end + 1 < order.count, values[order[end + 1]] == values[order[start]] { end += 1 }
            let rank = Double(start + end) / 2 + 1
            for index in start...end { result[order[index]] = rank }
            start = end + 1
        }
        return result
    }

    static func pearson(_ x: [Double], _ y: [Double]) -> Double {
        let mx = mean(x), my = mean(y)
        var sxy = 0.0, sxx = 0.0, syy = 0.0
        for (a, b) in zip(x, y) {
            sxy += (a - mx) * (b - my)
            sxx += (a - mx) * (a - mx)
            syy += (b - my) * (b - my)
        }
        return sxx > 0 && syy > 0 ? sxy / (sxx * syy).squareRoot() : .nan
    }

    static func lagOneAutocorrelation(_ values: [Double]) -> Double {
        guard values.count > 2 else { return 0 }
        let r = pearson(Array(values.dropLast()), Array(values.dropFirst()))
        return r.isFinite ? max(0, r) : 0
    }

    static func benjaminiHochberg(_ p: [Double]) -> [Double] {
        let order = p.indices.sorted { p[$0] < p[$1] }
        var adjusted = [Double](repeating: 1, count: p.count)
        var running = 1.0
        for (rank, index) in order.enumerated().reversed() {
            running = min(running, p[index] * Double(p.count) / Double(rank + 1))
            adjusted[index] = min(1, running)
        }
        return adjusted
    }

    static func mean(_ values: [Double]) -> Double { values.isEmpty ? .nan : values.reduce(0, +) / Double(values.count) }

    static func variance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let m = mean(values)
        return values.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(values.count - 1)
    }

    /// The Student t distribution's CDF, through the regularized incomplete beta function.
    static func studentT(_ t: Double, degrees: Double) -> Double {
        let x = degrees / (degrees + t * t)
        let tail = 0.5 * incompleteBeta(x, a: degrees / 2, b: 0.5)
        return t >= 0 ? 1 - tail : tail
    }

    /// The t value with the given cumulative probability, by bisection.
    static func studentTQuantile(_ probability: Double, degrees: Double) -> Double {
        var low = 0.0, high = 1000.0
        for _ in 0..<100 {
            let middle = (low + high) / 2
            if studentT(middle, degrees: degrees) < probability { low = middle } else { high = middle }
        }
        return (low + high) / 2
    }

    /// The regularized incomplete beta function I_x(a, b), by Lentz's continued fraction.
    static func incompleteBeta(_ x: Double, a: Double, b: Double) -> Double {
        guard x > 0 else { return 0 }
        guard x < 1 else { return 1 }
        let front = exp(lgamma(a + b) - lgamma(a) - lgamma(b) + a * log(x) + b * log(1 - x))
        if x > (a + 1) / (a + b + 2) { return 1 - incompleteBeta(1 - x, a: b, b: a) }
        var f = 1.0, c = 1.0, d = 0.0
        for i in 0...300 {
            let m = Double(i / 2)
            let numerator: Double
            if i == 0 {
                numerator = 1
            } else if i % 2 == 0 {
                numerator = m * (b - m) * x / ((a + 2 * m - 1) * (a + 2 * m))
            } else {
                numerator = -((a + m) * (a + b + m) * x) / ((a + 2 * m) * (a + 2 * m + 1))
            }
            d = 1 + numerator * d
            d = abs(d) < 1e-30 ? 1e-30 : d
            d = 1 / d
            c = 1 + numerator / c
            c = abs(c) < 1e-30 ? 1e-30 : c
            let delta = c * d
            f *= delta
            if abs(1 - delta) < 1e-12 { break }
        }
        return front * (f - 1) / a
    }
}
