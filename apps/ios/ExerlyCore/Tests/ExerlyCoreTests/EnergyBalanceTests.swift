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
        /// The first day food is logged; days before it are weighed but not logged.
        var loggingStarts = 0
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
            days.append(EnergyBalance.Day(date: start.adding(days: day), intake: day < person.loggingStarts ? nil : logged,
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

    // MARK: Logging that starts late

    /// One estimate's error against the truth on a simulated day.
    struct Sample {
        var day: Int
        var trend: Double
        var expenditure: Double
        /// The ±2 SD expenditure band holds the truth.
        var covered: Bool
    }

    /// Errors for every day: real-time, as the trend card sees each day, and in
    /// the smoothed history the chart draws once the whole series is known.
    static func run(_ people: [Person], parameters: EnergyBalance.Parameters = .init()) -> (realTime: [Sample], history: [Sample]) {
        var realTime: [Sample] = [], history: [Sample] = []
        for person in people {
            let truth = simulate(person)
            func sample(_ day: Int, _ estimate: EnergyBalance.Estimate) -> Sample {
                let error = estimate.expenditure - truth.expenditure[day]
                return Sample(day: day, trend: estimate.trend - truth.weight[day], expenditure: error,
                              covered: abs(error) <= 2 * estimate.expenditureError)
            }
            for day in 0..<person.days {
                if let latest = EnergyBalance.estimate(Array(truth.days[...day]), parameters: parameters).last {
                    realTime.append(sample(day, latest))
                }
            }
            let all = EnergyBalance.estimate(truth.days, parameters: parameters)
            for (index, estimate) in all.enumerated() { history.append(sample(person.days - all.count + index, estimate)) }
        }
        return (realTime, history)
    }

    struct Window: CustomStringConvertible {
        /// Mean absolute errors, the worst day's mean trend error, and band coverage.
        var trend: Double, worstDayTrend: Double, expenditure: Double, covered: Double

        init(_ samples: [Sample], days: ClosedRange<Int>) {
            let inside = samples.filter { days.contains($0.day) }
            trend = Score.mean(inside.map(\.trend))
            expenditure = Score.mean(inside.map(\.expenditure))
            covered = Double(inside.filter(\.covered).count) / Double(max(1, inside.count))
            worstDayTrend = days.map { day in Score.mean(inside.filter { $0.day == day }.map(\.trend)) }.max() ?? 0
        }

        var description: String {
            String(format: "trend |%.2f| kg (worst day %.2f), expenditure |%.0f| kcal, band covers %.0f%%",
                   trend, worstDayTrend, expenditure, covered * 100)
        }
    }

    /// The M5b people through nine weeks of a steady 500 kcal deficit, weighed
    /// most days, with food logged from `loggingStarts` on.
    static func lateLoggers(from loggingStarts: Int, phases: [(Int, Double)] = [(63, -500)]) -> [Person] {
        people(weighIns: 0.9).map { person in
            var person = person
            person.days = 63
            person.phases = phases
            person.loggingStarts = loggingStarts
            return person
        }
    }

    /// Weeks of weigh-ins before any food is logged, a common history. The
    /// weight change before logging must move the trend, not expenditure, and
    /// expenditure must stay uncertain until logged days pin it down. Bounds
    /// are the rates recorded in docs/design/007-nutrition.md, with room.
    @Test func logsThatStartWeeksAfterTheWeighInsKeepTheTrendAndAnHonestExpenditure() {
        // Real-time trend error over all days, smoothed trend error on days 14 to
        // 34 and its worst day, and real-time expenditure error in the last week.
        let scenarios: [(name: String, people: [Person], realTime: Double, history: Double, worstDay: Double, lastWeek: Double?)] = [
            ("always logged", Self.lateLoggers(from: 0), 0.29, 0.17, 0.20, 110),
            ("logged from day 21", Self.lateLoggers(from: 21), 0.31, 0.23, 0.27, 130),
            ("never logged", Self.lateLoggers(from: 63), 0.29, 0.18, 0.22, nil),
            ("diet and logging start on day 21", Self.lateLoggers(from: 21, phases: [(21, 0), (42, -500)]), 0.31, 0.23, 0.27, 140),
        ]
        for scenario in scenarios {
            let (realTime, history) = Self.run(scenario.people)
            let all = Window(realTime, days: 0...62), around = Window(history, days: 14...34)
            let lastWeek = Window(realTime, days: 56...62)
            print("Late logging, \(scenario.name): real-time \(all); last week \(lastWeek); smoothed days 14-34 \(around)")
            #expect(all.trend <= scenario.realTime, "\(scenario.name)")
            #expect(around.trend <= scenario.history && around.worstDayTrend <= scenario.worstDay, "\(scenario.name)")
            #expect(all.covered >= 0.9 && Window(history, days: 0...62).covered >= 0.9, "\(scenario.name): the band is honest")
            if let bound = scenario.lastWeek { #expect(lastWeek.expenditure <= bound, "\(scenario.name)") }
        }
    }

    /// From a usability test: four weeks of daily weigh-ins through a steady
    /// cut with partial logs only, where expenditure read 3,540 kcal. Intake is
    /// unknown, so expenditure stays at the starting guess, wide and unmeasured.
    @Test func weighInsWithoutACompleteDayLeaveExpenditureAtTheGuess() throws {
        for (index, expenditure) in [2300.0, 2700, 3100].enumerated() {
            var person = Person(seed: UInt64(40 + index))
            person.days = 28
            person.weight = 84
            person.expenditure = expenditure
            person.weighInChance = 1
            person.loggingStarts = 28
            person.phases = [(28, -500)]
            let truth = Self.simulate(person)
            let guess = 31 * truth.days[0].weights[0]
            let estimates = EnergyBalance.estimate(truth.days)
            let last = try #require(estimates.last)
            print(String(format: "No complete days, true expenditure %.0f: estimate %.0f ±%.0f from a guess of %.0f; trend %.2f kg against %.2f",
                         truth.expenditure[27], last.expenditure, last.expenditureError, guess, last.trend, truth.weight[27]))
            // Expenditure falls 22 kcal per kilogram lost and otherwise stays at the guess.
            #expect(abs(last.expenditure - guess) < 150)
            #expect(last.expenditureError > 550)
            #expect(abs(last.trend - truth.weight[27]) < 0.4)
            let summary = try #require(WeightTrend.summary(estimates, through: last.date))
            #expect(!summary.expenditure.isMeasured && summary.expenditure.loggedDays == 0)
            // A plan's narrower guess holds the same way.
            let planned = try #require(EnergyBalance.estimate(truth.days, prior: (2500, 375)).last)
            #expect(abs(planned.expenditure - 2500) < 150 && planned.expenditureError > 330)
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
