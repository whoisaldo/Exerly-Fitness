import Foundation
import Testing
@testable import ExerlyCore

@Suite struct AnalyticsTests {
    @Test func thePiecesMatchKnownValues() {
        #expect(Analytics.ranks([10, 20, 20, 30]) == [1, 2.5, 2.5, 4])
        #expect(Analytics.spearman([1, 2, 3, 4, 5], [2, 4, 9, 16, 99]) == 1)
        // Student's t: P(T <= 2.0) with 10 degrees of freedom is 0.963306.
        #expect(abs(Analytics.studentT(2.0, degrees: 10) - 0.963_306) < 1e-6)
        #expect(abs(Analytics.studentT(-1.0, degrees: 4) - 0.186_950) < 1e-6)
        #expect(Analytics.benjaminiHochberg([0.01, 0.04, 0.03, 0.005]) == [0.02, 0.04, 0.04, 0.02])
        #expect(abs(Analytics.studentTQuantile(0.975, degrees: 10) - 2.228_139) < 1e-5)
    }

    /// Autocorrelated daily noise, like most body and behaviour data: AR(1) with
    /// persistence `phi` and unit variance.
    static func series(_ count: Int, phi: Double, random: inout TrainingSimulator.Random) -> [Double] {
        func gauss() -> Double { random.normal() / 0.5.squareRoot() }
        var value = gauss(), values: [Double] = []
        for _ in 0..<count {
            values.append(value)
            value = phi * value + (1 - phi * phi).squareRoot() * gauss()
        }
        return values
    }

    static func dated(_ values: [Double]) -> [LocalDate: Double] {
        let start = LocalDate("2026-01-01")!
        return Dictionary(uniqueKeysWithValues: values.enumerated().map { (start.adding(days: $0.offset), $0.element) })
    }

    /// The rates recorded in docs/design/014-analytics.md, on seeded simulations.
    @Test func errorRatesStayHonest() {
        var random = TrainingSimulator.Random(state: 42)
        let runs = 200
        var falseCorrelations = 0, foundCorrelations = 0, falseEffects = 0, foundEffects = 0
        for _ in 0..<runs {
            let x = Self.series(60, phi: 0.6, random: &random), noise = Self.series(60, phi: 0.6, random: &random)
            let unrelated = Analytics.correlations(Self.dated(x), Self.dated(noise))
            if unrelated.contains(where: { $0.verdict == .clearPositive || $0.verdict == .clearNegative }) { falseCorrelations += 1 }
            let related = zip(x, noise).map { 0.6 * $0 + 0.8 * $1 }
            if Analytics.correlations(Self.dated(x), Self.dated(related)).first?.verdict == .clearPositive { foundCorrelations += 1 }
            let baseline = Self.series(42, phi: 0.5, random: &random), intervention = Self.series(42, phi: 0.5, random: &random)
            if Analytics.compare(baseline: baseline, intervention: intervention).verdict != .noClearDifference { falseEffects += 1 }
            if Analytics.compare(baseline: baseline, intervention: intervention.map { $0 + 1 }).verdict == .clearIncrease {
                foundEffects += 1
            }
        }
        #expect(falseCorrelations <= runs * 6 / 100, "\(falseCorrelations) false correlations")
        #expect(foundCorrelations >= runs * 80 / 100, "\(foundCorrelations) correlations found")
        #expect(falseEffects <= runs * 8 / 100, "\(falseEffects) false effects")
        #expect(foundEffects >= runs * 55 / 100, "\(foundEffects) effects found")

        // Two-week phases underestimate their own persistence most; the bias correction keeps them honest.
        var shortFalse = 0
        for _ in 0..<runs {
            let baseline = Self.series(14, phi: 0.5, random: &random), intervention = Self.series(14, phi: 0.5, random: &random)
            if Analytics.compare(baseline: baseline, intervention: intervention).verdict != .noClearDifference { shortFalse += 1 }
        }
        #expect(shortFalse <= runs * 7 / 100, "\(shortFalse) false effects with two-week phases")
    }

    @Test func tooLittleDataSaysSo() {
        let short = Self.dated((0..<10).map(Double.init))
        #expect(Analytics.correlations(short, short).allSatisfy { $0.verdict == .notEnoughData })
        #expect(Analytics.compare(baseline: [1, 2, 3], intervention: [4, 5, 6, 7, 8, 9, 10]).verdict == .notEnoughData)
    }
}
