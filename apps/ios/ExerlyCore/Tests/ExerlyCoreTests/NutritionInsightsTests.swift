import Foundation
import Testing
@testable import ExerlyCore

@MainActor
@Suite struct NutritionInsightsTests {
    let monday = LocalDate("2026-10-05")!

    func store() throws -> NutritionStore {
        try NutritionStore(persistence: InMemoryTrainingPersistence(), now: { Fixture.instant() })
    }

    func plan(starting date: LocalDate, energy: Double, goals: [Nutrient: NutrientGoal]? = nil) -> NutritionPlan {
        NutritionPlan(startDate: date, createdAt: Fixture.instant(), goal: NutritionGoal(.maintain),
                      targets: Array(repeating: DailyTargets(energy: energy, protein: 150, fat: 70, carbohydrate: 250), count: 7),
                      nutrientGoals: goals)
    }

    let oats = Food(name: "Oats", per100g: NutrientAmounts([.energy: 380, .protein: 13, .iron: 4.3]))
    let milk = Food(name: "Milk", per100g: NutrientAmounts([.energy: 60, .protein: 3.3]))

    @Test func goalsComeFromTargetsOverridesOrReferenceIntakes() {
        let base = plan(starting: monday, energy: 2000, goals: [.sodium: NutrientGoal(ceiling: 1500)])
        #expect(base.goal(for: .energy, on: monday) == NutrientGoal(target: 2000))
        #expect(base.goal(for: .sodium, on: monday) == NutrientGoal(ceiling: 1500))
        #expect(base.goal(for: .fiber, on: monday) == NutrientGoal(floor: 28))
        #expect(base.goal(for: .water, on: monday) == nil)
        var invalid = base
        invalid.nutrientGoals = [.calcium: NutrientGoal(floor: 1000, ceiling: 800), .protein: NutrientGoal(target: 200)]
        #expect(invalid.validationErrors == ["Calcium: the floor, target and ceiling must be in that order",
                                             "Protein comes from the daily targets"])
    }

    @Test func theOverviewCountsRealDaysAndJudgesEachAgainstItsOwnGoal() throws {
        let nutrition = try store()
        try nutrition.prepareWrite(kind: "nutrition_plan", id: UUID().uuidString,
                                   payload: ExerlyJSON.canonical(plan(starting: monday, energy: 2000)))()
        try nutrition.prepareWrite(kind: "nutrition_plan", id: UUID().uuidString,
                                   payload: ExerlyJSON.canonical(plan(starting: monday.adding(days: 2), energy: 1000)))()
        // Monday complete, Tuesday partial (left out), Wednesday unmarked with entries, Thursday fasting.
        try nutrition.log(oats, grams: 500, on: monday, meal: "Breakfast")
        try nutrition.setStatus(.complete, on: monday)
        try nutrition.log(oats, grams: 900, on: monday.adding(days: 1), meal: "Breakfast")
        try nutrition.setStatus(.partial, on: monday.adding(days: 1))
        try nutrition.log(milk, grams: 1000, on: monday.adding(days: 2), meal: "Snacks")
        try nutrition.setStatus(.fasting, on: monday.adding(days: 3))

        let overview = nutrition.overview(from: monday, through: monday.adding(days: 4))
        #expect(overview.days == 3 && overview.entries == 2)
        let energy = try #require(overview.rows.first { $0.nutrient == .energy })
        #expect(energy.average == 2500.0 / 3, "1900, 600 and a fasting zero")
        #expect(energy.observedDays == 2)
        #expect(energy.goal == NutrientGoal(target: 1000), "The goal in force on the last counted day")
        // 1900 against 2000, then 600 and 0 against 1000.
        #expect(energy.shareOfGoal == 2500 / 4000.0)
        let iron = try #require(overview.rows.first { $0.nutrient == .iron })
        #expect(iron.completeness == 0.5 && iron.observedDays == 1)
        #expect(iron.goal == NutrientGoal(floor: 18))
        #expect(!overview.rows.contains { $0.nutrient == .water }, "No amount and no goal")
    }

    @Test func timingUsesTheHourEatenAndCountsEntriesWithoutOne() throws {
        let nutrition = try store()
        let eight = Fixture.instant(minutes: 8 * 60)
        try nutrition.log(oats, grams: 100, on: LocalDate(eight, in: .gmt), meal: "Breakfast", at: eight)
        try nutrition.log(milk, grams: 200, on: LocalDate(eight, in: .gmt), meal: "Lunch", at: eight.addingTimeInterval(5 * 3600))
        // Logged the next morning for the day before: when it was eaten isn't known.
        try nutrition.log(milk, grams: 100, on: LocalDate(eight, in: .gmt).adding(days: -1), meal: "Dinner", at: eight)
        let day = LocalDate(eight, in: .gmt)
        let timing = nutrition.timing(from: day.adding(days: -1), through: day, timeZone: .gmt)
        let hour = Calendar(identifier: .gregorian).dateComponents(in: .gmt, from: eight).hour!
        #expect(timing.hours[hour].energy == 380 && timing.hours[hour + 5].energy == 120)
        #expect(timing.hours.reduce(0) { $0 + $1.entries } == 2 && timing.untimedEntries == 1)
    }

    @Test func aGoalWeightHasAnETAAndWeeklyCheckpoints() {
        let lose = NutritionGoal(.lose, weeklyRate: 0.005, goalWeight: .kg(76))
        // ln(76 / 80) / ln(0.995) = 10.23 weeks, 72 days.
        #expect(lose.eta(from: 80, on: monday) == monday.adding(days: 72))
        #expect(lose.eta(from: 75, on: monday) == monday, "Already there")
        #expect(NutritionGoal(.gain, weeklyRate: 0.0025, goalWeight: .kg(76)).eta(from: 80, on: monday) == monday)
        #expect(NutritionGoal(.maintain, goalWeight: .kg(76)).eta(from: 80, on: monday) == nil)
        let points = lose.checkpoints(from: 80, on: monday, weeks: 20)
        #expect(points.count == 11 && points.last?.weight == 76)
        #expect(abs(points[0].weight - 79.6) < 1e-9 && points[0].date == monday.adding(days: 7))
    }
}
