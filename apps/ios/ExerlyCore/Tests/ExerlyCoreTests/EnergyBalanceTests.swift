import Foundation
import Testing
@testable import ExerlyCore

/// Simulated people whose truth is known: expenditure that falls with weight
/// lost and adapts to dieting, water swings that persist for days, logging that
/// is biased and noisy, missed logs and irregular weigh-ins. Scored in
/// docs/design/007-nutrition.md.
@Suite struct EnergyBalanceTests {
    struct Person {
        var seed: UInt64
        var days = 140
        var weight = 85.0
        var expenditure = 2600.0
        /// Logged intake as a share of true intake.
        var logBias = 1.0
        var weighInChance = 0.9
        var completeChance = 0.85
        /// (days, change from starting expenditure).
        var phases: [(Int, Double)] = [(14, 0), (70, -500), (56, 0)]
    }

    struct Truth {
        var days: [EnergyBalance.Day]
        /// Expenditure in logged units: what logged intake would hold weight.
        var expenditure: [Double]
        var weight: [Double]
    }

    static func simulate(_ person: Person) -> Truth {
        var random = TrainingSimulator.Random(state: person.seed &* 2_654_435_761 &+ 97)
        var weight = person.weight
        var water = 0.0
        var drift = 0.0
        var deficitDays = 0.0
        var days: [EnergyBalance.Day] = []
        var truthE: [Double] = [], truthW: [Double] = []
        let start = LocalDate("2026-03-02")!
        var phaseDay = 0, phase = 0
        for day in 0..<person.days {
            if phaseDay == person.phases[phase].0, phase + 1 < person.phases.count {
                phase += 1
                phaseDay = 0
            }
            phaseDay += 1
            let planned = person.phases[phase].1
            deficitDays = planned < 0 ? deficitDays + 1 : max(0, deficitDays - 2)
            drift += 10 * random.normal()
            let expenditure = person.expenditure + 22 * (weight - person.weight) - 0.05 * person.expenditure * min(1, deficitDays / 42)
                + drift
            let intake = max(0, person.expenditure + planned + 300 * random.normal())
            water = 0.75 * water + 0.6 * (1 - 0.75 * 0.75).squareRoot() * random.normal()
            let scale = weight + water + 0.1 * random.normal()
            let roll = random.unit()
            let logged: Double? = roll < person.completeChance ? max(0, intake * person.logBias + 120 * random.normal()) : nil
            days.append(EnergyBalance.Day(date: start.adding(days: day), intake: logged,
                                          weights: random.unit() < person.weighInChance ? [scale] : []))
            truthE.append(expenditure * person.logBias)
            truthW.append(weight)
            weight += (intake - expenditure) / 7700
        }
        return Truth(days: days, expenditure: truthE, weight: truthW)
    }

    /// The legacy server method: an exponential trend (α 0.1) and 28-day energy balance.
    static func legacy(_ days: [EnergyBalance.Day]) -> (trend: Double, expenditure: Double)? {
        var trend: Double?
        var trends: [Double] = []
        for day in days {
            if let reading = day.weights.first { trend = trend.map { $0 + 0.1 * (reading - $0) } ?? reading }
            trends.append(trend ?? .nan)
        }
        guard days.count >= 28, let end = trends.last, let start = trends.dropLast(27).last, start.isFinite else { return nil }
        let logged = days.suffix(28).compactMap(\.intake)
        guard !logged.isEmpty else { return nil }
        return (end, logged.reduce(0, +) / Double(logged.count) - (end - start) * 7700 / 27)
    }

    struct Score: CustomStringConvertible {
        var expenditure: [Double] = []
        var trend: [Double] = []
        var legacyExpenditure: [Double] = []
        var legacyTrend: [Double] = []
        var covered = 0
        static func mean(_ values: [Double]) -> Double { values.map(abs).reduce(0, +) / Double(max(1, values.count)) }
        static func p90(_ values: [Double]) -> Double {
            let sorted = values.map(abs).sorted()
            return sorted.isEmpty ? 0 : sorted[Int(Double(sorted.count - 1) * 0.9)]
        }
        var description: String {
            String(format: "expenditure |%.0f| kcal (90th %.0f), trend |%.2f| kg (90th %.2f), band covers %.0f%%; legacy expenditure |%.0f| (90th %.0f), trend |%.2f|",
                   Self.mean(expenditure), Self.p90(expenditure), Self.mean(trend), Self.p90(trend),
                   Double(covered) * 100 / Double(max(1, expenditure.count)),
                   Self.mean(legacyExpenditure), Self.p90(legacyExpenditure), Self.mean(legacyTrend))
        }
    }

    /// Real-time estimates: each day sees only the data up to it.
    static func score(_ people: [Person], from firstDay: Int = 28, parameters: EnergyBalance.Parameters = .init()) -> Score {
        var score = Score()
        for person in people {
            let truth = simulate(person)
            for day in stride(from: firstDay, to: person.days, by: 7) {
                let seen = Array(truth.days[...day])
                guard let latest = EnergyBalance.estimate(seen, parameters: parameters).last else { continue }
                score.expenditure.append(latest.expenditure - truth.expenditure[day])
                score.trend.append(latest.trend - truth.weight[day])
                if abs(latest.expenditure - truth.expenditure[day]) <= 2 * latest.expenditureError { score.covered += 1 }
                if let old = legacy(seen) {
                    score.legacyExpenditure.append(old.expenditure - truth.expenditure[day])
                    score.legacyTrend.append(old.trend - truth.weight[day])
                }
            }
        }
        return score
    }

    static func people(weighIns: Double, bias: ClosedRange<Double> = 0.85...1.0) -> [Person] {
        (0..<30).map { index in
            var person = Person(seed: UInt64(index + 1))
            person.weighInChance = weighIns
            person.logBias = bias.lowerBound + (bias.upperBound - bias.lowerBound) * Double(index % 5) / 4
            person.weight = 60 + Double(index % 6) * 9
            person.expenditure = 2000 + Double(index % 7) * 180
            if index % 3 == 1 { person.phases = [(14, 0), (56, 400), (70, 0)] }
            return person
        }
    }

    /// The rates recorded in docs/design/007-nutrition.md, with room for the
    /// simulator's randomness. A drop means a regression.
    @Test func meetsTheRecordedRatesOnSimulatedPeople() {
        let bounds: [(weighIns: Double, mean: Double, p90: Double, trend: Double)] = [
            (0.9, 90, 185, 0.26), (0.5, 95, 195, 0.28), (0.2, 115, 240, 0.36),
        ]
        for bound in bounds {
            let score = Self.score(Self.people(weighIns: bound.weighIns))
            print("Energy balance, weigh-in chance \(bound.weighIns): \(score)")
            #expect(Score.mean(score.expenditure) <= bound.mean)
            #expect(Score.p90(score.expenditure) <= bound.p90)
            #expect(Score.mean(score.trend) <= bound.trend)
            #expect(Double(score.covered) / Double(score.expenditure.count) >= 0.88, "The band is honest")
            #expect(Score.mean(score.trend) < Score.mean(score.legacyTrend))
            #expect(Score.mean(score.expenditure) <= Score.mean(score.legacyExpenditure))
        }
    }

    // MARK: Cases

    func days(_ count: Int, intake: Double?, weight: (Int) -> Double?) -> [EnergyBalance.Day] {
        (0..<count).map { day in
            EnergyBalance.Day(date: LocalDate("2026-01-05")!.adding(days: day), intake: intake,
                              weights: weight(day).map { [$0] } ?? [])
        }
    }

    @Test func steadyWeightAtSteadyIntakeMeansExpenditureEqualsIntake() throws {
        let estimates = EnergyBalance.estimate(days(60, intake: 2400, weight: { _ in 80 }), prior: (3000, 600))
        let last = try #require(estimates.last)
        #expect(abs(last.expenditure - 2400) < 25)
        #expect(abs(last.trend - 80) < 0.05)
        #expect(estimates.count == 60)
    }

    @Test func aSteadyLossAtAKnownIntakeRevealsTheDeficit() throws {
        // 2000 kcal a day against 2550 at the start, with expenditure falling
        // 22 kcal a day for each kilogram lost, as people's does.
        var weights = [90.0], expenditure = [2550.0]
        for _ in 1..<84 {
            weights.append(weights.last! + (2000 - expenditure.last!) / 7700)
            expenditure.append(2550 + 22 * (weights.last! - 90))
        }
        let estimates = EnergyBalance.estimate(days(84, intake: 2000, weight: { weights[$0] }))
        let last = try #require(estimates.last)
        #expect(abs(last.expenditure - expenditure[83]) < 40)
        #expect(abs(last.trend - weights[83]) < 0.1)
    }

    @Test func sparseWeighInsStillGiveADailyTrendAndUnloggedDaysWidenTheBand() throws {
        let sparse = EnergyBalance.estimate(days(42, intake: 2400, weight: { $0 % 7 == 3 ? 80 : nil }))
        #expect(sparse.count == 39, "Every day from the first weigh-in")
        #expect(sparse.allSatisfy { abs($0.trend - 80) < 0.3 })
        let logged = EnergyBalance.estimate(days(42, intake: 2400, weight: { _ in 80 }))
        let unlogged = EnergyBalance.estimate(days(42, intake: nil, weight: { _ in 80 }))
        #expect(unlogged.last!.expenditureError > logged.last!.expenditureError)
        #expect(EnergyBalance.estimate(days(5, intake: 2000, weight: { _ in nil })).isEmpty)
    }

    @MainActor
    @Test func onlyCompleteAndFastingDaysCountAsKnownIntake() throws {
        let persistence = InMemoryTrainingPersistence()
        let nutrition = try NutritionStore(persistence: persistence, now: { Fixture.instant() })
        let monday = LocalDate("2026-10-05")!
        try nutrition.log(Foods.oats, grams: 100, on: monday, meal: "Breakfast")
        try nutrition.setStatus(.complete, on: monday)
        try nutrition.log(Foods.oats, grams: 100, on: monday.adding(days: 1), meal: "Breakfast")
        try nutrition.setStatus(.partial, on: monday.adding(days: 1))
        try nutrition.setStatus(.fasting, on: monday.adding(days: 2))
        try nutrition.logWeight(.kg(80), at: Fixture.instant(), timeZone: Fixture.utc)
        let input = nutrition.energyBalanceDays(from: monday, through: monday.adding(days: 3))
        #expect(input.map(\.intake) == [380, nil, 0, nil])
        #expect(input[0].weights == [80])
    }
}
