import Foundation
import Testing
@testable import ExerlyCore

/// Simulated dieters who eat to their targets and accept every weekly
/// check-in, scored on how closely their weight follows the goal rate. See
/// docs/design/011-nutrition-targets.md.
@Suite struct NutritionCoachingTests {
    struct Dieter {
        var seed: UInt64
        var weight = 80.0
        /// True expenditure at the start, in kcal a day.
        var expenditure = 2500.0
        /// Logged intake as a share of true intake.
        var logBias = 1.0
        /// The goal, as a signed share of bodyweight a week.
        var rate = -0.005
        /// How far the starting guess of expenditure is off, as a share.
        var guessError = 0.0
        var completeChance = 0.85
        var weighInChance = 0.9
        var weeks = 16
    }

    /// The achieved rate over weeks 4 to the end, as a share of bodyweight a week.
    static func achievedRate(_ dieter: Dieter, checkIns: Bool) throws -> Double {
        var random = TrainingSimulator.Random(state: dieter.seed &* 0x2545_F491_4F6C_DD1D &+ 13)
        func gauss() -> Double { random.normal() / 0.5.squareRoot() }
        let start = LocalDate("2026-03-02")! // A Monday.
        let direction: NutritionGoal.Direction = dieter.rate < 0 ? .lose : dieter.rate > 0 ? .gain : .maintain
        let guess = PlanBasis(expenditure: (dieter.expenditure * (1 + dieter.guessError)).rounded(), expenditureError: 400,
                              trendWeight: dieter.weight)
        var plan = try NutritionPlan(startDate: start, createdAt: Fixture.instant(),
                                     goal: NutritionGoal(direction, weeklyRate: abs(dieter.rate)), allowBelowFloor: true)
            .computed(from: guess)
        var weight = dieter.weight, water = 0.0, drift = 0.0, deficitDays = 0.0
        var days: [EnergyBalance.Day] = []
        var truth: [Double] = []
        for day in 0..<(dieter.weeks * 7) {
            let date = start.adding(days: day)
            if checkIns, day > 0, date.weekday == plan.checkInDay {
                let review = try NutritionCheckIn.review(plan: plan, days: days, prior: (guess.expenditure, guess.expenditureError),
                                                         today: date, existing: [], now: Fixture.instant(days: Double(day)))
                if let after = review.proposal?.changes.first?.after {
                    plan = try ExerlyJSON.decoder.decode(NutritionPlan.self, from: after.canonicalData)
                }
            }
            drift += 10 * gauss()
            let expenditure = dieter.expenditure + 22 * (weight - dieter.weight)
                - 0.05 * dieter.expenditure * min(1, deficitDays / 42) + drift
            let intake = max(0, plan.targets(on: date)!.energy / dieter.logBias + 200 * gauss())
            deficitDays = intake < expenditure - 200 ? deficitDays + 1 : max(0, deficitDays - 2)
            water = 0.8 * water + 0.6 * 0.6 * gauss()
            let logged: Double? = random.unit() < dieter.completeChance ? max(0, intake * dieter.logBias + 120 * gauss()) : nil
            days.append(EnergyBalance.Day(date: date, intake: logged,
                                          weights: random.unit() < dieter.weighInChance ? [weight + water + 0.1 * gauss()] : []))
            truth.append(weight)
            weight += (intake - expenditure) / 7700
        }
        let from = truth[28]
        return (truth[truth.count - 1] - from) / from / (Double(truth.count - 1 - 28) / 7)
    }

    static func dieters(weighIns: Double = 0.9) -> [Dieter] {
        let rates = [-0.005, -0.01, -0.0075, 0.0025, 0]
        let errors = [-0.15, -0.075, 0, 0.075, 0.15]
        return (0..<30).map { index in
            var dieter = Dieter(seed: UInt64(index + 1))
            dieter.weight = 60 + Double(index % 6) * 9
            dieter.expenditure = dieter.weight * (28 + Double(index % 5) * 2.5)
            dieter.logBias = 0.85 + 0.15 * Double(index % 4) / 3
            dieter.rate = rates[index % 5]
            dieter.guessError = errors[(index / 5) % 5]
            dieter.weighInChance = weighIns
            return dieter
        }
    }

    struct Score: CustomStringConvertible {
        var errors: [Double] = []
        var mean: Double { errors.map(abs).reduce(0, +) / Double(max(1, errors.count)) }
        var p90: Double {
            let sorted = errors.map(abs).sorted()
            return sorted.isEmpty ? 0 : sorted[Int(Double(sorted.count - 1) * 0.9)]
        }
        var description: String { String(format: "mean |error| %.3f %%/week, 90th %.3f", mean * 100, p90 * 100) }
    }

    static func score(_ dieters: [Dieter], checkIns: Bool) throws -> Score {
        var score = Score()
        for dieter in dieters { score.errors.append(try achievedRate(dieter, checkIns: checkIns) - dieter.rate) }
        return score
    }

    /// The rates recorded in docs/design/011-nutrition-targets.md, with room for
    /// the simulator's randomness. A drop means a regression.
    @Test func checkInsBringTheRateCloseToTheGoal() throws {
        let bounds: [(weighIns: Double, mean: Double, p90: Double)] = [(0.9, 0.0009, 0.0016), (0.5, 0.0011, 0.0022), (0.2, 0.0012, 0.0024)]
        for bound in bounds {
            let coached = try Self.score(Self.dieters(weighIns: bound.weighIns), checkIns: true)
            let fixed = try Self.score(Self.dieters(weighIns: bound.weighIns), checkIns: false)
            print("Coaching, weigh-in chance \(bound.weighIns): coached \(coached); fixed \(fixed)")
            #expect(coached.mean <= bound.mean)
            #expect(coached.p90 <= bound.p90)
            #expect(coached.mean * 2 < fixed.mean, "Check-ins at least halve the error of fixed targets")
        }
    }
}
