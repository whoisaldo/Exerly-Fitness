import Foundation
import Testing
@testable import ExerlyCore

@Suite struct OneRepMaxTests {
    @Test func isExactAtOneRepToFailure() {
        #expect(OneRepMax.estimate(load: 140, reps: 1) == 140)
        #expect(OneRepMax.estimate(load: 140, reps: 1, rir: 0) == 140)
    }

    @Test func usesBrzyckiUpToTenAndEpleyAbove() throws {
        // Brzycki: w * 36 / (37 - r)
        #expect(try #require(OneRepMax.estimate(load: 100, reps: 5)) == 100 * 36 / 32)
        // Epley: w * (1 + r / 30)
        #expect(try #require(OneRepMax.estimate(load: 100, reps: 15)) == 100 * 1.5)
        // Both give 4/3 at ten reps.
        let atTen = try #require(OneRepMax.estimate(load: 75, reps: 10))
        #expect(abs(atTen - 100) < 1e-9)
    }

    @Test func addsRepsInReserveToRepsToFailure() throws {
        let threeAtTwoRIR = try #require(OneRepMax.estimate(load: 100, reps: 3, rir: 2))
        let five = try #require(OneRepMax.estimate(load: 100, reps: 5))
        #expect(threeAtTwoRIR == five)
        #expect(OneRepMax.repsToFailure(reps: 8, rir: 1.5) == 9.5)
    }

    @Test func isContinuousAndIncreasing() throws {
        var previous = 0.0
        for tenths in 10...200 {
            let r = Double(tenths) / 10
            let value = try #require(OneRepMax.estimate(load: 100, repsToFailure: r))
            #expect(value > previous, "not increasing at \(r)")
            #expect(value - previous < 2.0 || tenths == 10, "jump at \(r)")
            previous = value
        }
    }

    @Test func inverseRoundTrips() throws {
        for r in [1.0, 2, 3, 5, 8, 10, 12, 15, 20] {
            let e1rm = try #require(OneRepMax.estimate(load: 87.5, repsToFailure: r))
            #expect(abs(OneRepMax.load(forReps: r, oneRepMax: e1rm) - 87.5) < 1e-9, "r = \(r)")
        }
        #expect(OneRepMax.load(forReps: 1, oneRepMax: 200) == 200)
    }

    @Test func refusesUnreliableOrMeaninglessInputs() {
        #expect(OneRepMax.estimate(load: 100, reps: 0) == nil)
        #expect(OneRepMax.estimate(load: 0, reps: 5) == nil)
        #expect(OneRepMax.estimate(load: -5, reps: 5) == nil)
        #expect(OneRepMax.estimate(load: 50, reps: 21) == nil)
        #expect(OneRepMax.estimate(load: 50, reps: 15, rir: 6) == nil)
        #expect(OneRepMax.estimate(load: .nan, reps: 5) == nil)
    }

    @Test func gradesConfidenceByRepsToFailure() {
        #expect(OneRepMax.confidence(repsToFailure: 1) == .high)
        #expect(OneRepMax.confidence(repsToFailure: 5) == .high)
        #expect(OneRepMax.confidence(repsToFailure: 5.5) == .moderate)
        #expect(OneRepMax.confidence(repsToFailure: 10) == .moderate)
        #expect(OneRepMax.confidence(repsToFailure: 12) == .low)
    }

    /// The NSCA %1RM table is a population average, not ground truth. This
    /// records how far the estimate sits from it; the design note reports it.
    @Test func staysCloseToTheNSCAReferenceTable() throws {
        let table: [(reps: Double, percent: Double)] = [
            (1, 100), (2, 95), (3, 93), (4, 90), (5, 87), (6, 85),
            (7, 83), (8, 80), (9, 77), (10, 75), (12, 67), (15, 65),
        ]
        var worstUpToTen = 0.0
        var worst = 0.0
        for row in table {
            let predicted = OneRepMax.load(forReps: row.reps, oneRepMax: 100)
            let error = abs(predicted - row.percent)
            worst = max(worst, error)
            if row.reps <= 10 { worstUpToTen = max(worstUpToTen, error) }
        }
        #expect(worstUpToTen < 2.3)
        #expect(worst < 4.5)
    }

    @Test func keepsTheEnteredUnit() throws {
        let estimate = try #require(OneRepMax.estimate(Mass(225, .pounds), reps: 5))
        #expect(estimate.unit == .pounds)
        #expect(abs(estimate.value - 253.125) < 1e-9)
    }
}
